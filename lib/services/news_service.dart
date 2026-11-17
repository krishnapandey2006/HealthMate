import 'dart:convert';
import 'dart:math' as math;

import 'package:hive/hive.dart';

import '../app/app_config.dart';
import '../models/article.dart';
import 'api_client.dart';
import 'news_direct_source.dart';

const bool _isWebBuild = bool.fromEnvironment('dart.library.js_util');

class NewsResult {
  final List<Article> articles;
  final int page;
  final bool hasMore;
  final int total;
  final int requestedLimit;
  final DateTime? lastUpdated;
  final bool fromCache;
  final String? warning;
  final ApiException? error;

  const NewsResult({
    required this.articles,
    this.page = 1,
    this.hasMore = false,
    this.total = 0,
    this.requestedLimit = 0,
    this.lastUpdated,
    this.fromCache = false,
    this.warning,
    this.error,
  });

  bool get isError => error != null;
  bool get isEmpty => articles.isEmpty && error == null;
}

class NewsService {
  static const _boxName = 'news_cache_v4';
  static const cacheTtl = Duration(minutes: 30);

  /// Shared between the Home and News screens so simultaneous loads never
  /// trigger duplicate upstream requests.
  static final Map<String, Future<NewsResult>> _inFlight = {};

  final ApiClient _api;
  final NewsDirectSource? _providedDirect;
  final bool _preferProxy;
  final bool _allowDirect;

  NewsDirectSource? _direct;
  NewsDirectSource get _directSource =>
      _direct ??= _providedDirect ?? NewsDirectSource();

  NewsService({
    ApiClient? api,
    NewsDirectSource? directSource,
    bool? preferProxy,
  })  : _api = api ?? ApiClient(),
        _providedDirect = directSource,
        _preferProxy = preferProxy ??
            (api != null || _isWebBuild || AppConfig.hasExplicitProxy),
        // Injected API clients are used by tests; never hit real feeds there.
        // Web builds also stay proxy-only: publisher feeds do not send CORS
        // headers, so a direct browser fetch would fail after a long timeout.
        _allowDirect = directSource != null || (!_isWebBuild && api == null);

  String _cacheKey(String category, String lang, int page, int limit) =>
      '${lang}_${category}_${page}_$limit';

  Future<NewsResult> fetchPage({
    String category = 'all',
    String lang = 'en',
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cached = await loadCachedPage(
      category: category,
      lang: lang,
      page: page,
      limit: limit,
    );

    // A cache entry is a short-lived convenience, not a substitute for live
    // news. It is only returned directly when it was fetched for at least the
    // requested page size; otherwise the caller asked for more than it holds.
    if (!forceRefresh &&
        cached != null &&
        _isFresh(cached) &&
        cached.requestedLimit >= limit) {
      return cached;
    }

    final key = '${_cacheKey(category, lang, page, limit)}'
        '|${forceRefresh ? 'force' : 'normal'}';
    final running = _inFlight[key];
    if (running != null) return running;

    final future = _fetchAndCache(
      category: category,
      lang: lang,
      page: page,
      limit: limit,
      cached: cached,
    );
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<NewsResult> _fetchAndCache({
    required String category,
    required String lang,
    required int page,
    required int limit,
    required NewsResult? cached,
  }) async {
    ApiException? failure;

    if (_preferProxy) {
      try {
        final result = await _fetchFromProxy(
          category: category,
          lang: lang,
          page: page,
          limit: limit,
        );
        if (result.articles.isNotEmpty) return result;
        // An honest empty answer can still fall back to another provider when
        // this build is allowed to call one directly.
        failure = result.error ??
            ApiException(
              ApiErrorType.invalidResponse,
              result.warning ?? 'No live articles were returned.',
            );
      } on ApiException catch (error) {
        failure = error;
      }
    }

    if (_allowDirect) {
      try {
        final result = await _fetchDirect(
          category: category,
          lang: lang,
          page: page,
          limit: limit,
        );
        if (result.articles.isNotEmpty) return result;
        if (result.warning != null) return result;
        // No usable direct articles: keep the saved copy if one exists.
      } on DirectNewsException catch (error) {
        failure ??= ApiException(
          error.message.toLowerCase().contains('rate-limit')
              ? ApiErrorType.rateLimit
              : error.message.toLowerCase().contains('no recent')
                  ? ApiErrorType.invalidResponse
                  : ApiErrorType.network,
          error.message,
        );
      } catch (_) {
        failure ??= const ApiException(
          ApiErrorType.network,
          'Live health news could not be reached. Check your connection.',
        );
      }
    }

    if (cached != null && cached.articles.isNotEmpty) {
      return NewsResult(
        articles: cached.articles,
        page: cached.page,
        hasMore: cached.hasMore,
        total: cached.total,
        requestedLimit: cached.requestedLimit,
        lastUpdated: cached.lastUpdated,
        fromCache: true,
        warning: _warningFor(failure, cached.lastUpdated),
        error: failure,
      );
    }

    final error = failure ??
        const ApiException(
          ApiErrorType.network,
          'Live health news could not be reached. Check your connection.',
        );
    return NewsResult(
      articles: const [],
      page: page,
      requestedLimit: limit,
      error: error,
    );
  }

  Future<NewsResult> _fetchFromProxy({
    required String category,
    required String lang,
    required int page,
    required int limit,
  }) async {
    final json = await _api.getJson(
      '/api/news',
      query: {
        'category': category,
        'lang': lang,
        'page': '$page',
        'limit': '$limit',
      },
      timeout: const Duration(seconds: 14),
      retries: 0,
    );

    final rawArticles = json['articles'];
    final articles = <Article>[];
    if (rawArticles is List) {
      for (final item in rawArticles) {
        if (item is Map) {
          final article = Article.fromMap(Map<String, dynamic>.from(item));
          if (article.isValid) articles.add(article);
        }
      }
    }

    final fromCache = json['stale'] == true;
    final result = NewsResult(
      articles: _prepareArticles(articles),
      page: _asInt(json['page'], page),
      hasMore: json['hasMore'] == true,
      total: _asInt(json['total'], articles.length),
      requestedLimit: limit,
      lastUpdated: DateTime.tryParse(json['lastUpdated']?.toString() ?? '') ??
          DateTime.now(),
      fromCache: fromCache,
      warning: json['warning']?.toString(),
    );

    if (result.articles.isNotEmpty) {
      await _cachePage(category, lang, page, limit, result);
    }
    return result;
  }

  Future<NewsResult> _fetchDirect({
    required String category,
    required String lang,
    required int page,
    required int limit,
  }) async {
    final direct = await _directSource.fetch(
      category: category,
      lang: lang,
      limit: limit * math.max(1, page),
    );
    final all = _prepareArticles(direct.articles);
    final start = (page - 1) * limit;
    final end = math.min(start + limit, all.length);
    final pageArticles =
        start >= all.length ? const <Article>[] : all.sublist(start, end);

    final result = NewsResult(
      articles: pageArticles,
      page: page,
      hasMore: end < all.length,
      total: all.length,
      requestedLimit: limit,
      lastUpdated: DateTime.now(),
      warning: direct.warning,
    );

    if (pageArticles.isNotEmpty) {
      await _cachePage(category, lang, page, limit, result);
    }
    return result;
  }

  bool _isFresh(NewsResult cached) {
    final savedAt = cached.lastUpdated;
    if (savedAt == null) return false;
    return DateTime.now().difference(savedAt) < cacheTtl;
  }

  String _warningFor(ApiException? error, DateTime? savedAt) {
    final saved = savedAt == null
        ? 'Showing saved articles instead.'
        : 'Showing articles saved on ${savedAt.day.toString().padLeft(2, '0')}/'
            '${savedAt.month.toString().padLeft(2, '0')}/${savedAt.year} '
            'at ${savedAt.hour.toString().padLeft(2, '0')}:'
            '${savedAt.minute.toString().padLeft(2, '0')}.';
    switch (error?.type) {
      case ApiErrorType.notConfigured:
        return 'Live news is not configured. $saved';
      case ApiErrorType.network:
      case ApiErrorType.timeout:
        return 'You appear to be offline. $saved';
      case ApiErrorType.rateLimit:
        return 'The news service is busy. $saved';
      default:
        return 'Live news could not be refreshed. $saved';
    }
  }

  Future<NewsResult?> loadCachedPage({
    String category = 'all',
    String lang = 'en',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final box = await Hive.openBox(_boxName);
      final raw = box.get(_cacheKey(category, lang, page, limit));
      if (raw is! String || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final articles = <Article>[];
      final rawArticles = json['articles'];
      if (rawArticles is List) {
        for (final item in rawArticles) {
          if (item is Map) {
            final article = Article.fromMap(Map<String, dynamic>.from(item));
            if (article.isValid) articles.add(article);
          }
        }
      }
      if (articles.isEmpty) return null;
      final savedAt = DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.tryParse(json['lastUpdated']?.toString() ?? '');
      return NewsResult(
        articles: _prepareArticles(articles),
        page: _asInt(json['page'], page),
        hasMore: json['hasMore'] == true,
        total: _asInt(json['total'], articles.length),
        requestedLimit: _asInt(json['limit'], 0),
        lastUpdated: savedAt,
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _cachePage(
    String category,
    String lang,
    int page,
    int limit,
    NewsResult result,
  ) async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(
        _cacheKey(category, lang, page, limit),
        jsonEncode({
          'articles':
              result.articles.map((article) => article.toMap()).toList(),
          'page': result.page,
          'limit': limit,
          'hasMore': result.hasMore,
          'total': result.total,
          'lastUpdated':
              (result.lastUpdated ?? DateTime.now()).toIso8601String(),
          'savedAt': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {
      // Caching is best-effort; a failure must not hide live results.
    }
  }

  Future<DateTime?> lastSuccessfulUpdate({
    String category = 'all',
    String lang = 'en',
    int limit = 20,
  }) async {
    final cached = await loadCachedPage(
      category: category,
      lang: lang,
      limit: limit,
    );
    return cached?.lastUpdated;
  }

  Future<bool> clearCache() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.clear();
      return true;
    } catch (_) {
      return false;
    }
  }

  List<Article> _prepareArticles(Iterable<Article> articles) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final oldest = DateTime.now().subtract(const Duration(days: 60));
    final seenTitles = <String>{};
    final list = <Article>[];

    for (final article in articles) {
      if (!article.isValid) continue;
      final date = article.publishedDate;
      if (date.isAfter(tomorrow) || date.isBefore(oldest)) continue;

      final title = _normalizeTitle(article.title);
      if (title.isEmpty || !seenTitles.add(title)) continue;
      list.add(article);
    }

    list.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
    return list;
  }

  String _normalizeTitle(String title) => title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u0900-\u0DFF]+'), '')
      .trim();

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void dispose() {
    _api.close();
    _providedDirect?.dispose();
    if (!identical(_direct, _providedDirect)) _direct?.dispose();
  }
}
