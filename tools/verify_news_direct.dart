// ignore_for_file: avoid_print
import 'package:healthmate_mb/services/news_direct_source.dart';

String norm(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

Future<void> main() async {
  final source = NewsDirectSource();
  var failures = 0;

  try {
    final cases = <(String, String)>[
      ('all', 'en'),
      ('research', 'en'),
      ('public_health', 'en'),
      ('vaccination', 'en'),
      ('all', 'hi'),
    ];

    for (final (category, lang) in cases) {
      final started = DateTime.now();
      try {
        final result =
            await source.fetch(category: category, lang: lang, limit: 12);
        final elapsed = DateTime.now().difference(started).inMilliseconds;
        final articles = result.articles;
        final titles = <String>{};
        var duplicates = 0;
        var unsorted = 0;
        var invalidDates = 0;
        var unsafeLinks = 0;
        DateTime? previous;
        final oldest = DateTime.now().subtract(const Duration(days: 60));

        for (final article in articles) {
          final key = norm(article.title);
          if (!titles.add(key)) duplicates++;
          final date = article.publishedDate;
          if (!article.isValid || date.isBefore(oldest)) invalidDates++;
          if (previous != null && date.isAfter(previous)) unsorted++;
          previous = date;
          final link = article.link;
          if (link == null ||
              !(link.startsWith('https://') || link.startsWith('http://'))) {
            unsafeLinks++;
          }
        }

        print(
          '$lang/$category: ${articles.length} articles in ${elapsed}ms '
          'dupes=$duplicates unsorted=$unsorted badDates=$invalidDates badLinks=$unsafeLinks',
        );
        print('  source=${result.source}');
        if (result.warning != null) print('  warning=${result.warning}');
        for (final article in articles.take(3)) {
          print(
            '  - [${article.category}] ${article.source} | ${article.publishedAt} | '
            '${article.title.length > 80 ? article.title.substring(0, 80) : article.title}',
          );
        }
        if (articles.isEmpty ||
            duplicates > 0 ||
            unsorted > 0 ||
            invalidDates > 0 ||
            unsafeLinks > 0) {
          failures++;
        }
      } catch (error) {
        failures++;
        final elapsed = DateTime.now().difference(started).inMilliseconds;
        print('$lang/$category: FAILED in ${elapsed}ms -> $error');
      }
    }
  } finally {
    source.dispose();
  }

  if (failures > 0) {
    print('DIRECT NEWS VERIFICATION FAILED ($failures case(s))');
    throw StateError('$failures direct news case(s) failed');
  }
  print('DIRECT NEWS VERIFICATION PASSED');
}
