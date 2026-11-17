import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/services/news_direct_source.dart';

void main() {
  test('parses publisher RSS with real dates, images and inferred categories',
      () {
    const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
  <channel>
    <title>The Hindu - Health</title>
    <item>
      <title>Dengue cases fall in Tamil Nadu</title>
      <link>https://www.thehindu.com/news/dengue-cases-fall/article1.ece</link>
      <description><![CDATA[<p>State reports <b>fewer</b> cases this week.</p><img src="https://www.thehindu.com/img/dengue.jpg"/>]]></description>
      <pubDate>Mon, 16 Nov 2026 15:05:11 +0530</pubDate>
      <guid>article-1</guid>
    </item>
    <item>
      <title>Undated item</title>
      <link>https://www.thehindu.com/news/undated.ece</link>
      <description>No date here</description>
    </item>
    <item>
      <title>Unsafe item</title>
      <link>javascript:alert(1)</link>
      <pubDate>Mon, 16 Nov 2026 15:05:11 +0530</pubDate>
    </item>
  </channel>
</rss>''';

    final articles = parseNewsFeed(
      xml,
      fallbackSource: 'The Hindu',
      fallbackCategory: 'healthcare',
      publisherFeed: true,
    );

    expect(articles, hasLength(1));
    final article = articles.single;
    expect(article.title, 'Dengue cases fall in Tamil Nadu');
    expect(article.source, 'The Hindu');
    expect(article.link,
        'https://www.thehindu.com/news/dengue-cases-fall/article1.ece');
    expect(article.summary, 'State reports fewer cases this week.');
    expect(article.thumbnail, 'https://www.thehindu.com/img/dengue.jpg');
    expect(article.publishedAt, '2026-11-16T09:35:11.000Z');
    expect(article.category, 'public_health');
  });

  test('parses Atom entries with href links and UTC timestamps', () {
    const xml = '''<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>WHO News</title>
  <entry>
    <title>New guidance on health data</title>
    <link href="https://www.who.int/news/item/health-data"/>
    <id>tag:who.int,2026:health-data</id>
    <updated>2026-11-10T07:49:45Z</updated>
    <summary>Technical package for countries.</summary>
  </entry>
</feed>''';

    final articles = parseNewsFeed(
      xml,
      fallbackSource: 'WHO',
      fallbackCategory: 'public_health',
      publisherFeed: true,
    );

    expect(articles, hasLength(1));
    final article = articles.single;
    expect(article.link, 'https://www.who.int/news/item/health-data');
    expect(article.publishedAt, '2026-11-10T07:49:45.000Z');
    expect(article.source, 'WHO');
    expect(article.category, 'public_health');
  });

  test('Google-style source suffixes become the displayed source once', () {
    const xml = '''<rss version="2.0"><channel>
  <item>
    <title>Flu cases rise - The Hindu</title>
    <link>https://news.google.com/rss/articles/abc</link>
    <source url="https://www.thehindu.com">The Hindu</source>
    <description>Flu cases rise - The Hindu&#160;&#160;&lt;font&gt;The Hindu&lt;/font&gt;</description>
    <pubDate>Mon, 16 Nov 2026 20:10:00 GMT</pubDate>
  </item>
</channel></rss>''';

    final articles = parseNewsFeed(
      xml,
      fallbackSource: 'Google News',
      fallbackCategory: 'all',
    );

    expect(articles, hasLength(1));
    expect(articles.single.title, 'Flu cases rise');
    expect(articles.single.source, 'The Hindu');
    expect(articles.single.summary, isEmpty);
    expect(articles.single.category, 'healthcare');
  });

  test('RFC 822 dates respect IST and named zones', () {
    expect(
      parseRssDate('Mon, 16 Nov 2026 15:05:11 +0530')?.toIso8601String(),
      '2026-11-16T09:35:11.000Z',
    );
    expect(
      parseRssDate('16 Nov 2026 15:05:11 IST')?.toIso8601String(),
      '2026-11-16T09:35:11.000Z',
    );
    expect(parseRssDate('not a date'), isNull);
    expect(parseRssDate(''), isNull);
  });

  test('vaccination keywords are inferred before general healthcare', () {
    const xml = '''<rss version="2.0"><channel>
  <item>
    <title>Measles vaccination drive expands</title>
    <link>https://example.org/vaccination</link>
    <description>A new immunisation campaign starts this week.</description>
    <pubDate>Mon, 16 Nov 2026 10:00:00 GMT</pubDate>
  </item>
</channel></rss>''';

    final article = parseNewsFeed(
      xml,
      fallbackSource: 'The Hindu',
      fallbackCategory: 'healthcare',
      publisherFeed: true,
    ).single;

    expect(article.category, 'vaccination');
    expect(article.severity, 'ADVISORY');
  });
}
