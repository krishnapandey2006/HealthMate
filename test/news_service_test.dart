import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/models/article.dart';
import 'package:healthmate_mb/services/api_client.dart';
import 'package:healthmate_mb/services/news_direct_source.dart';
import 'package:healthmate_mb/services/news_service.dart';
import 'package:hive/hive.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.test');

  Map<String, dynamic> response = {};
  ApiException? failure;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 15),
    int retries = 1,
  }) async {
    calls++;
    final error = failure;
    if (error != null) throw error;
    return response;
  }
}

class _FakeDirectSource extends NewsDirectSource {
  _FakeDirectSource(this.articles, {this.warning});

  final List<Article> articles;
  final String? warning;
  int calls = 0;

  @override
  Future<DirectNewsResult> fetch({
    String category = 'all',
    String lang = 'en',
    int limit = 12,
  }) async {
    calls++;
    return DirectNewsResult(
      articles: articles.take(limit).toList(growable: false),
      source: 'Test publisher feeds',
      warning: warning,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('healthmate_news_test');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    final box = await Hive.openBox('news_cache_v4');
    await box.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Map<String, dynamic> article(
    String title,
    DateTime publishedAt, {
    String link = 'https://example.test/article',
  }) {
    return {
      'id': title,
      'title': title,
      'source': 'Test Health Service',
      'publishedAt': publishedAt.toIso8601String(),
      'summary': 'Summary for $title',
      'link': link,
    };
  }

  Article directArticle(String title, DateTime publishedAt) => Article(
        id: title,
        title: title,
        source: 'Test publisher',
        publishedAt: publishedAt.toIso8601String(),
        summary: 'Summary for $title',
        link: 'https://publisher.test/${title.hashCode}',
        category: 'healthcare',
      );

  test('fresh news filters undated and future articles and sorts newest first',
      () async {
    final api = _FakeApiClient()
      ..response = {
        'articles': [
          article(
              'Older item', DateTime.now().subtract(const Duration(days: 5))),
          article(
              'Recent item', DateTime.now().subtract(const Duration(hours: 2))),
          article('Future item', DateTime.now().add(const Duration(days: 3))),
          {
            'title': 'Undated item',
            'source': 'Test Health Service',
            'publishedAt': 'not-a-date',
            'summary': 'No date',
          },
        ],
        'page': 1,
        'total': 4,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    final service = NewsService(api: api);

    final result = await service.fetchPage();

    expect(result.isError, isFalse);
    expect(result.articles.map((item) => item.title),
        ['Recent item', 'Older item']);
    expect(result.fromCache, isFalse);

    final cached = await service.loadCachedPage();
    expect(cached, isNotNull);
    expect(cached!.articles, hasLength(2));
    expect(cached.fromCache, isTrue);
    expect(cached.lastUpdated, isNotNull);
  });

  test('offline refresh keeps cached news with a saved-date warning', () async {
    final api = _FakeApiClient()
      ..response = {
        'articles': [
          article(
              'Cached item', DateTime.now().subtract(const Duration(days: 1))),
        ],
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    final service = NewsService(api: api);
    await service.fetchPage();

    api.failure = const ApiException(
      ApiErrorType.network,
      'Could not reach the service.',
    );
    final fallback = await service.fetchPage(forceRefresh: true);

    expect(fallback.fromCache, isTrue);
    expect(fallback.isError, isTrue);
    expect(fallback.articles.single.title, 'Cached item');
    expect(fallback.warning, contains('offline'));
    expect(fallback.warning, contains('saved on'));
  });

  test('no cache and a network error produce a truthful empty error result',
      () async {
    final api = _FakeApiClient()
      ..failure = const ApiException(
        ApiErrorType.notConfigured,
        'The service is not configured.',
      );
    final service = NewsService(api: api);

    final result = await service.fetchPage();

    expect(result.articles, isEmpty);
    expect(result.isEmpty, isFalse);
    expect(result.isError, isTrue);
    expect(result.error?.type, ApiErrorType.notConfigured);
    expect(result.warning, isNull);
  });

  test('a failed proxy falls back to the keyless direct source', () async {
    final api = _FakeApiClient()
      ..failure = const ApiException(
        ApiErrorType.network,
        'Could not reach the proxy.',
      );
    final direct = _FakeDirectSource([
      directArticle(
          'Direct article', DateTime.now().subtract(const Duration(hours: 1))),
    ]);
    final service = NewsService(api: api, directSource: direct);

    final result = await service.fetchPage(limit: 12);

    expect(result.isError, isFalse);
    expect(result.articles.single.title, 'Direct article');
    expect(result.fromCache, isFalse);
    expect(api.calls, 1);
    expect(direct.calls, 1);
  });

  test('a successful proxy does not call the direct source', () async {
    final api = _FakeApiClient()
      ..response = {
        'articles': [
          article('Proxy article',
              DateTime.now().subtract(const Duration(hours: 1))),
        ],
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    final direct = _FakeDirectSource([
      directArticle('Direct article', DateTime.now()),
    ]);
    final service = NewsService(api: api, directSource: direct);

    final result = await service.fetchPage(limit: 12);

    expect(result.articles.single.title, 'Proxy article');
    expect(direct.calls, 0);
  });

  test('simultaneous identical loads share one upstream request', () async {
    final api = _FakeApiClient()
      ..response = {
        'articles': [
          article('Shared article',
              DateTime.now().subtract(const Duration(hours: 1))),
        ],
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    final service = NewsService(api: api);

    final results = await Future.wait([
      service.fetchPage(limit: 12),
      service.fetchPage(limit: 12),
    ]);

    expect(results.map((result) => result.articles.single.title),
        ['Shared article', 'Shared article']);
    expect(api.calls, 1);
  });

  test('a direct-source language fallback warning reaches the UI result',
      () async {
    final api = _FakeApiClient()
      ..failure = const ApiException(
        ApiErrorType.network,
        'Could not reach the proxy.',
      );
    final direct = _FakeDirectSource(
      [
        directArticle('English fallback',
            DateTime.now().subtract(const Duration(hours: 1))),
      ],
      warning:
          'Live coverage in the selected language is unavailable right now, so English-language health articles are shown.',
    );
    final service = NewsService(api: api, directSource: direct);

    final result = await service.fetchPage(lang: 'hi', limit: 12);

    expect(result.articles.single.title, 'English fallback');
    expect(result.warning, contains('selected language'));
    expect(result.isError, isFalse);
  });

  test('clearCache removes saved pages', () async {
    final api = _FakeApiClient()
      ..response = {
        'articles': [
          article(
              'Saved item', DateTime.now().subtract(const Duration(hours: 1))),
        ],
      };
    final service = NewsService(api: api);
    await service.fetchPage();
    expect(await service.loadCachedPage(), isNotNull);

    expect(await service.clearCache(), isTrue);
    expect(await service.loadCachedPage(), isNull);
  });
}
