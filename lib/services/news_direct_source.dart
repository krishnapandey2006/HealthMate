import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/article.dart';

/// Raised when every direct news source fails. It deliberately contains no
/// internal URL or device detail.
class DirectNewsException implements Exception {
  final String message;

  const DirectNewsException(this.message);

  @override
  String toString() => message;
}

class DirectNewsResult {
  final List<Article> articles;
  final String source;
  final String? warning;

  const DirectNewsResult({
    required this.articles,
    required this.source,
    this.warning,
  });
}

class _Feed {
  final String source;
  final String url;
  final String category;
  final bool indian;

  const _Feed(this.source, this.url, this.category, {this.indian = false});
}

/// Keyless RSS/Atom feeds used when the app cannot, or should not, call the
/// development proxy. All URLs are public HTTPS endpoints; no API key or
/// secret is embedded in the app.
const _feeds = <_Feed>[
  _Feed(
    'The Hindu',
    'https://www.thehindu.com/sci-tech/health/feeder/default.rss',
    'healthcare',
    indian: true,
  ),
  _Feed(
    'Times of India',
    'https://timesofindia.indiatimes.com/rssfeeds/3908999.cms',
    'healthcare',
    indian: true,
  ),
  _Feed(
    'Medical Xpress',
    'https://medicalxpress.com/rss-feed/',
    'research',
  ),
  _Feed(
    'WHO',
    'https://www.who.int/rss-feeds/news-english.xml',
    'public_health',
  ),
  _Feed(
    'ScienceDaily',
    'https://www.sciencedaily.com/rss/health_medicine.xml',
    'research',
  ),
];

/// Locale parameters mirror the proxy so category searches keep working in
/// every language the app supports.
const _newsLocales = <String, Map<String, String>>{
  'en': {'hl': 'en-IN', 'gl': 'IN', 'ceid': 'IN:en'},
  'hi': {'hl': 'hi', 'gl': 'IN', 'ceid': 'IN:hi'},
  'mr': {'hl': 'mr', 'gl': 'IN', 'ceid': 'IN:mr'},
  'bn': {'hl': 'bn', 'gl': 'IN', 'ceid': 'IN:bn'},
  'gu': {'hl': 'gu', 'gl': 'IN', 'ceid': 'IN:gu'},
  'ta': {'hl': 'ta', 'gl': 'IN', 'ceid': 'IN:ta'},
};

const _localizedQueries = <String, Map<String, String>>{
  'hi': {
    'public_health': 'जन स्वास्थ्य भारत',
    'vaccination': 'टीकाकरण भारत',
    'prevention': 'बीमारी रोकथाम भारत',
    'healthcare': 'स्वास्थ्य सेवा भारत',
    'research': 'चिकित्सा शोध भारत',
  },
  'mr': {
    'public_health': 'सार्वजनिक आरोग्य भारत',
    'vaccination': 'लसीकरण भारत',
    'prevention': 'आजार प्रतिबंध भारत',
    'healthcare': 'आरोग्य सेवा भारत',
    'research': 'वैद्यकीय संशोधन भारत',
  },
  'bn': {
    'public_health': 'জনস্বাস্থ্য ভারত',
    'vaccination': 'টিকাকরণ ভারত',
    'prevention': 'রোগ প্রতিরোধ ভারত',
    'healthcare': 'স্বাস্থ্যসেবা ভারত',
    'research': 'চিকিৎসা গবেষণা ভারত',
  },
  'gu': {
    'public_health': 'જાહેર આરોગ્ય ભારત',
    'vaccination': 'રસીકરણ ભારત',
    'prevention': 'રોગ નિવારણ ભારત',
    'healthcare': 'આરોગ્ય સેવા ભારત',
    'research': 'તબીબી સંશોધન ભારત',
  },
  'ta': {
    'public_health': 'பொது சுகாதாரம் இந்தியா',
    'vaccination': 'தடுப்பூசி இந்தியா',
    'prevention': 'நோய் தடுப்பு இந்தியா',
    'healthcare': 'சுகாதார சேவை இந்தியா',
    'research': 'மருத்துவ ஆராய்ச்சி இந்தியா',
  },
};

class _CachedFeed {
  final List<Article> articles;
  final DateTime fetchedAt;

  const _CachedFeed(this.articles, this.fetchedAt);

  bool get isFresh =>
      DateTime.now().difference(fetchedAt) < const Duration(minutes: 10);
}

class _Selection {
  final List<Article> articles;
  final String? warning;

  const _Selection(this.articles, [this.warning]);
}

/// Fetches and parses real health RSS/Atom feeds without a backend.
class NewsDirectSource {
  final http.Client _client;
  final Map<String, _CachedFeed> _feedCache = {};
  final Map<String, Future<List<Article>>> _feedInFlight = {};
  final Map<String, _CachedFeed> _googleCache = {};
  DateTime? _googleBlockedUntil;

  NewsDirectSource({http.Client? client}) : _client = client ?? http.Client();

  static const _userAgent =
      'HealthMate/1.0 (health information app; +https://healthmate.local)';

  Future<DirectNewsResult> fetch({
    String category = 'all',
    String lang = 'en',
    int limit = 12,
  }) async {
    if (lang != 'en') {
      return _fetchLocalized(category: category, lang: lang, limit: limit);
    }

    final raw = await _fetchPublisherFeeds(category);
    var all = _prepare(raw);

    // Category feeds are small. When a strict filter leaves too few genuine
    // matches, ask Google News for that specific category as a supplement.
    final needsGoogle = category == 'all'
        ? all.isEmpty
        : _categoryMatchCount(all, category) < 6;
    if (needsGoogle) {
      try {
        final google = await _fetchGoogle(category: category, lang: 'en');
        all = _prepare([...raw, ...google]);
      } catch (_) {
        // Publisher results are still valid on their own.
      }
    }

    if (all.isEmpty) {
      throw DirectNewsException(
        raw.isEmpty
            ? 'Live health news could not be reached. Check your connection and try again.'
            : 'No recent health articles were available.',
      );
    }

    final selection = _selectForCategory(all, category);
    return DirectNewsResult(
      articles: selection.articles
          .take(_maximumReturn(limit))
          .toList(growable: false),
      source: 'The Hindu, Times of India, Medical Xpress, WHO and ScienceDaily',
      warning: selection.warning,
    );
  }

  Future<DirectNewsResult> _fetchLocalized({
    required String category,
    required String lang,
    required int limit,
  }) async {
    try {
      final localized = await _fetchGoogle(category: category, lang: lang);
      final prepared = _prepare(localized);
      if (prepared.isNotEmpty) {
        final selection = _selectForCategory(prepared, category);
        return DirectNewsResult(
          articles: selection.articles
              .take(_maximumReturn(limit))
              .toList(growable: false),
          source: 'Google News RSS',
          warning: selection.warning,
        );
      }
    } catch (_) {
      // Fall through to English coverage with an explicit warning.
    }

    final english = await _fetchPublisherFeeds('all');
    final prepared = _prepare(english);
    if (prepared.isEmpty) {
      throw const DirectNewsException(
        'Live health news could not be reached in this language right now.',
      );
    }
    final selection = _selectForCategory(prepared, category);
    const fallbackWarning =
        'Live coverage in the selected language is unavailable right now, so English-language health articles are shown.';
    return DirectNewsResult(
      articles: selection.articles
          .take(_maximumReturn(limit))
          .toList(growable: false),
      source: 'English-language health feeds',
      warning: selection.warning == null
          ? fallbackWarning
          : '$fallbackWarning ${selection.warning}',
    );
  }

  int _categoryMatchCount(List<Article> articles, String category) =>
      articles.where((article) => article.category == category).length;

  _Selection _selectForCategory(List<Article> prepared, String category) {
    if (category == 'all') return _Selection(prepared);
    final matching = prepared
        .where((article) => article.category == category)
        .toList(growable: false);
    // A single lonely item makes a category tab look broken. When fewer than
    // four genuine matches exist, show recent coverage with an explicit note;
    // every card keeps its own real category.
    if (matching.length >= 4) return _Selection(matching);
    return _Selection(
      prepared,
      matching.isEmpty
          ? 'No articles specifically matching this category were available right now. Showing recent health coverage instead.'
          : 'Only a few articles specifically matching this category were available. Showing recent health coverage as well.',
    );
  }

  int _maximumReturn(int limit) {
    final target = limit * 3;
    return target < 30 ? 30 : (target > 60 ? 60 : target);
  }

  Future<List<Article>> _fetchPublisherFeeds(String category) async {
    final selected = _feedsFor(category);
    final results = await Future.wait(
      selected.map((feed) async {
        try {
          return await _fetchFeed(feed);
        } catch (_) {
          return const <Article>[];
        }
      }),
    );
    final combined = <Article>[];
    for (final list in results) {
      combined.addAll(list);
    }
    return combined;
  }

  List<_Feed> _feedsFor(String category) {
    switch (category) {
      case 'public_health':
      case 'vaccination':
        return _feeds
            .where((feed) =>
                feed.indian ||
                feed.source == 'WHO' ||
                feed.source == 'Medical Xpress')
            .toList(growable: false);
      case 'research':
        return _feeds
            .where((feed) =>
                feed.source == 'Medical Xpress' ||
                feed.source == 'ScienceDaily')
            .toList(growable: false);
      case 'prevention':
        return _feeds
            .where((feed) =>
                feed.indian ||
                feed.source == 'ScienceDaily' ||
                feed.source == 'WHO')
            .toList(growable: false);
      case 'healthcare':
        return _feeds
            .where((feed) => feed.indian || feed.source == 'Medical Xpress')
            .toList(growable: false);
      default:
        return _feeds
            .where((feed) =>
                feed.indian ||
                feed.source == 'Medical Xpress' ||
                feed.source == 'WHO')
            .toList(growable: false);
    }
  }

  Future<List<Article>> _fetchFeed(_Feed feed) {
    final cached = _feedCache[feed.url];
    if (cached != null && cached.isFresh) return Future.value(cached.articles);
    final running = _feedInFlight[feed.url];
    if (running != null) return running;

    final future = () async {
      final response = await _client.get(
        Uri.parse(feed.url),
        headers: {
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
          'User-Agent': _userAgent,
        },
      ).timeout(const Duration(seconds: 9));

      if (response.statusCode == 429) {
        throw const DirectNewsException('The news source is busy.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DirectNewsException(
          'The news source returned HTTP ${response.statusCode}.',
        );
      }

      final articles = parseNewsFeed(
        response.body,
        fallbackSource: feed.source,
        fallbackCategory: feed.category,
        language: 'en',
        publisherFeed: true,
      );
      _feedCache[feed.url] = _CachedFeed(articles, DateTime.now());
      return articles;
    }();

    _feedInFlight[feed.url] = future;
    future.whenComplete(() => _feedInFlight.remove(feed.url));
    return future;
  }

  Future<List<Article>> _fetchGoogle({
    required String category,
    required String lang,
  }) async {
    final blockedUntil = _googleBlockedUntil;
    if (blockedUntil != null && DateTime.now().isBefore(blockedUntil)) {
      throw const DirectNewsException(
        'The news source is rate-limiting requests.',
      );
    }

    final locale = _newsLocales[lang] ?? _newsLocales['en']!;
    final cacheKey = '$lang|$category';
    final cached = _googleCache[cacheKey];
    if (cached != null && cached.isFresh) return cached.articles;

    final query = category == 'all'
        ? null
        : (_localizedQueries[lang]?[category] ?? _englishQuery(category));
    final uri = Uri.https(
      'news.google.com',
      query == null ? '/rss/headlines/section/topic/HEALTH' : '/rss/search',
      {
        if (query != null) 'q': query,
        'hl': locale['hl']!,
        'gl': locale['gl']!,
        'ceid': locale['ceid']!,
      },
    );

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
          'User-Agent': _userAgent,
        },
      ).timeout(const Duration(seconds: 9));

      if (response.statusCode == 429) {
        _googleBlockedUntil = DateTime.now().add(const Duration(minutes: 10));
        throw const DirectNewsException(
          'The news source is rate-limiting requests.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DirectNewsException(
          'The news source returned HTTP ${response.statusCode}.',
        );
      }

      final articles = parseNewsFeed(
        response.body,
        fallbackSource: 'Google News',
        fallbackCategory: category,
        language: lang,
      );
      final tagged = category == 'all'
          ? articles
          : articles
              .map((article) => article.copyWith(category: category))
              .toList(growable: false);
      _googleCache[cacheKey] = _CachedFeed(tagged, DateTime.now());
      return tagged;
    } on TimeoutException {
      throw const DirectNewsException('The news source timed out.');
    } catch (error) {
      if (error is DirectNewsException) rethrow;
      throw const DirectNewsException(
        'The news source could not be reached. Check your connection.',
      );
    }
  }

  String _englishQuery(String category) {
    switch (category) {
      case 'public_health':
        return 'public health India';
      case 'vaccination':
        return 'vaccination India';
      case 'prevention':
        return 'disease prevention India';
      case 'healthcare':
        return 'healthcare India';
      case 'research':
        return 'medical research India';
      default:
        return 'health India';
    }
  }

  List<Article> _prepare(List<Article> input) {
    final now = DateTime.now();
    final oldest = now.subtract(const Duration(days: 60));
    final tomorrow = now.add(const Duration(days: 1));
    final seenTitles = <String>{};
    final result = <Article>[];

    for (final article in input) {
      if (!article.isValid) continue;
      final published = article.publishedDate;
      if (published.isBefore(oldest) || published.isAfter(tomorrow)) continue;

      final titleKey = _normalizeTitle(article.title);
      if (titleKey.isEmpty || !seenTitles.add(titleKey)) continue;

      result.add(article);
    }

    result.sort((a, b) => b.publishedDate.compareTo(a.publishedDate));
    return result;
  }

  String _normalizeTitle(String title) => title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u0900-\u0DFF]+'), '')
      .trim();

  void dispose() => _client.close();
}

/// Parses an RSS 2.0 or Atom document into validated [Article] values.
/// Exposed so the parser can be regression-tested without network access.
List<Article> parseNewsFeed(
  String xml, {
  required String fallbackSource,
  String fallbackCategory = 'all',
  String language = 'en',
  bool publisherFeed = false,
}) {
  final document = XmlDocument.parse(xml);
  final root = document.rootElement;
  final feedTitle = _childText(root, const ['title']);
  final items = document.descendants
      .whereType<XmlElement>()
      .where((element) =>
          element.name.local == 'item' || element.name.local == 'entry')
      .toList(growable: false);

  final articles = <Article>[];
  for (final item in items) {
    final rawTitle = _childText(item, const ['title']);
    final rawLink = _linkOf(item);
    final link = _safeUrl(rawLink);
    if (rawTitle.isEmpty || link == null) continue;

    final source = _childText(item, const ['source']);
    final sourceName = _clean(
      source.isNotEmpty
          ? source
          : (feedTitle.isNotEmpty && !publisherFeed
              ? feedTitle
              : fallbackSource),
      80,
    );
    var title = _clean(rawTitle, 220);
    final suffix = ' - $sourceName';
    if (source.isNotEmpty && title.endsWith(suffix)) {
      title = title.substring(0, title.length - suffix.length).trim();
    }

    final rawSummary = _childText(
      item,
      const ['description', 'summary', 'content', 'encoded'],
    );
    var summary = _clean(rawSummary, 320);
    if (summary.toLowerCase() == title.toLowerCase() ||
        summary.toLowerCase().startsWith(title.toLowerCase())) {
      summary = '';
    }

    final rawDate = _childText(
      item,
      const ['pubDate', 'published', 'updated', 'date', 'created'],
    );
    final published = parseRssDate(rawDate);
    if (published == null) continue;

    final inferred = fallbackCategory == 'all'
        ? _categoryForFeed(title, summary, 'healthcare')
        : publisherFeed
            ? _categoryForFeed(title, summary, fallbackCategory)
            : fallbackCategory;

    final id = _childText(item, const ['guid', 'id']);
    articles.add(
      Article(
        id: id.isNotEmpty ? id : link,
        title: title,
        source: sourceName.isEmpty ? fallbackSource : sourceName,
        publishedAt: published.toUtc().toIso8601String(),
        summary: summary,
        severity: RegExp(
          r'outbreak|alert|emergency|recall',
          caseSensitive: false,
        ).hasMatch(title)
            ? 'CRITICAL'
            : 'ADVISORY',
        link: link,
        language: language,
        thumbnail: _imageOf(item, rawSummary),
        category: inferred,
      ),
    );
  }
  return articles;
}

String _categoryForFeed(String title, String summary, String fallback) {
  final text = '$title $summary'.toLowerCase();
  if (RegExp(r'vaccin|immuni[sz]|booster|\bjab\b').hasMatch(text)) {
    return 'vaccination';
  }
  // Research and public-health feeds are already authoritative for their
  // category; only the general Indian health feeds need keyword inference.
  if (fallback != 'healthcare') return fallback;
  if (RegExp(
    r'\b(trial|study|studies|research|researchers|scientists|journal|lancet|clinical|cohort|genetic|gene)\b',
  ).hasMatch(text)) {
    return 'research';
  }
  if (RegExp(
    r'\b(prevent|prevention|risk|diet|nutrition|exercise|screening|awareness|obesity|smoking)\b',
  ).hasMatch(text)) {
    return 'prevention';
  }
  if (RegExp(
    r'\b(outbreak|surveillance|public health|ministry|government|who|cdc|epidemic|pandemic|measles|malaria|dengue|tuberculosis)\b',
  ).hasMatch(text)) {
    return 'public_health';
  }
  if (RegExp(
    r'\b(hospital|clinic|doctor|nurse|insurance|healthcare|health care|policy|medical|surgery|patient)\b',
  ).hasMatch(text)) {
    return 'healthcare';
  }
  return fallback;
}

String _childText(XmlElement parent, List<String> names) {
  for (final child in parent.childElements) {
    if (names.contains(child.name.local)) {
      final text = child.innerText.trim();
      if (text.isNotEmpty) return text;
    }
  }
  return '';
}

String? _linkOf(XmlElement item) {
  for (final child in item.childElements) {
    if (child.name.local != 'link') continue;
    final href = child.getAttribute('href');
    if (href != null && href.trim().isNotEmpty) return href.trim();
    final text = child.innerText.trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

String? _imageOf(XmlElement item, String descriptionHtml) {
  for (final child in item.descendants.whereType<XmlElement>()) {
    final local = child.name.local;
    if (local != 'content' && local != 'thumbnail' && local != 'enclosure') {
      continue;
    }
    final url = child.getAttribute('url') ?? child.getAttribute('href');
    if (url == null || url.trim().isEmpty) continue;
    final type = (child.getAttribute('type') ?? '').toLowerCase();
    if (local == 'enclosure' && type.isNotEmpty && !type.startsWith('image')) {
      continue;
    }
    final safe = _safeUrl(url);
    if (safe != null) return safe;
  }

  final match = RegExp(
    r'''<img[^>]+src=["']([^"']+)["']''',
    caseSensitive: false,
  ).firstMatch(descriptionHtml);
  return match == null ? null : _safeUrl(match.group(1));
}

String? _safeUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  var candidate = value;
  if (candidate.startsWith('//')) candidate = 'https:$candidate';
  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      !uri.hasScheme ||
      !uri.isAbsolute ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return uri.toString();
}

String _clean(String raw, int maxLength) {
  var text = raw
      .replaceAll(
          RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#0?39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);|&#(\d+);'),
        (match) {
          final hex = match.group(1);
          final code = hex != null
              ? int.tryParse(hex, radix: 16)
              : int.tryParse(match.group(2) ?? '');
          return code == null ? '' : String.fromCharCode(code);
        },
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.length > maxLength) {
    text = '${text.substring(0, maxLength - 1).trim()}…';
  }
  return text;
}

/// Parses RFC 822 dates used by RSS feeds (including Indian publishers) and
/// ISO-8601 dates used by Atom feeds. Returns null for undated entries so old
/// items are never stamped with the current time.
DateTime? parseRssDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final iso = DateTime.tryParse(value);
  if (iso != null) return iso.toUtc();

  final withoutWeekday = value.replaceFirst(
    RegExp(r'^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)[a-z]*,?\s+', caseSensitive: false),
    '',
  );
  final match = RegExp(
    r'^(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{2}:?\d{2}|[A-Za-z]{1,5})?',
  ).firstMatch(withoutWeekday);
  if (match == null) return null;

  const months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final month = months[match.group(2)!.toLowerCase().substring(0, 3)];
  final day = int.tryParse(match.group(1)!);
  final year = int.tryParse(match.group(3)!);
  final hour = int.tryParse(match.group(4)!);
  final minute = int.tryParse(match.group(5)!);
  final second = int.tryParse(match.group(6) ?? '0');
  if (month == null ||
      day == null ||
      year == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }

  final offset = _timezoneOffset(match.group(7));
  final parsed = DateTime.utc(year, month, day, hour, minute, second);
  return parsed.subtract(offset);
}

Duration _timezoneOffset(String? raw) {
  if (raw == null || raw.isEmpty) return Duration.zero;
  final value = raw.toUpperCase();
  if (value == 'Z' || value == 'GMT' || value == 'UTC' || value == 'UT') {
    return Duration.zero;
  }
  final numeric = RegExp(r'^([+-])(\d{2}):?(\d{2})$').firstMatch(value);
  if (numeric != null) {
    final sign = numeric.group(1) == '-' ? -1 : 1;
    final hours = int.tryParse(numeric.group(2)!) ?? 0;
    final minutes = int.tryParse(numeric.group(3)!) ?? 0;
    return Duration(minutes: sign * (hours * 60 + minutes));
  }
  const named = {
    'IST': 330,
    'PKT': 300,
    'BST': 60,
    'CET': 60,
    'CEST': 120,
    'EST': -300,
    'EDT': -240,
    'CST': -360,
    'CDT': -300,
    'MST': -420,
    'MDT': -360,
    'PST': -480,
    'PDT': -420,
    'AEST': 600,
    'AEDT': 660,
  };
  return Duration(minutes: named[value] ?? 0);
}

extension on Article {
  Article copyWith({String? category}) => Article(
        id: id,
        title: title,
        source: source,
        publishedAt: publishedAt,
        summary: summary,
        severity: severity,
        link: link,
        language: language,
        thumbnail: thumbnail,
        category: category ?? this.category,
      );
}
