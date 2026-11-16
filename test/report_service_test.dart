import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/models/health_report.dart';
import 'package:healthmate_mb/services/report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ReportService> service([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return ReportService(prefs: prefs);
  }

  test('a report is saved locally with a device reference', () async {
    final reports = await service();

    final result = await reports.submitReport(
      type: ReportType.personalConcern,
      category: 'vaccination',
      description: 'The vaccine stock was unavailable at the clinic today.',
      area: 'Pune',
    );

    expect(result.saved, isTrue);
    expect(result.report.reference, startsWith('HM-'));
    expect(result.report.status, ReportStatus.saved);
    expect(result.report.description, contains('vaccine stock'));

    final history = await reports.loadHistory();
    expect(history, hasLength(1));
    expect(history.single.category, 'vaccination');
    expect(history.single.area, 'Pune');
  });

  test('history is newest first and capped at one hundred reports', () async {
    final reports = await service();
    for (var index = 0; index < 105; index++) {
      await reports.submitReport(
        type: ReportType.feedback,
        category: 'other',
        description: 'Feedback number $index',
        area: '',
      );
    }

    final history = await reports.loadHistory();
    expect(history, hasLength(100));
    expect(history.first.description, contains('104'));
  });

  test('rapid submissions keep unique ids and references', () async {
    final reports = await service();
    for (var index = 0; index < 20; index++) {
      await reports.submitReport(
        type: ReportType.feedback,
        category: 'other',
        description: 'Rapid report $index',
        area: '',
      );
    }

    final history = await reports.loadHistory();
    expect(history, hasLength(20));
    expect(history.map((report) => report.id).toSet(), hasLength(20));
    expect(history.map((report) => report.reference).toSet(), hasLength(20));
  });

  test('duplicate protection applies to the same text within two minutes',
      () async {
    final reports = await service();
    const description = 'A sufficiently long description for duplicate checking.';

    await reports.submitReport(
      type: ReportType.feedback,
      category: 'other',
      description: description,
      area: '',
    );

    expect(await reports.isDuplicate('other', description), isTrue);
    expect(await reports.isDuplicate('vaccination', description), isFalse);
    expect(
      await reports.isDuplicate('other', 'A different description'),
      isFalse,
    );
  });

  test('clearAll removes reports and duplicate state', () async {
    final reports = await service();
    await reports.submitReport(
      type: ReportType.feedback,
      category: 'other',
      description: 'Clear this report from the device.',
      area: '',
    );

    expect(await reports.clearAll(), isTrue);
    expect(await reports.loadHistory(), isEmpty);
    expect(await reports.isDuplicate('other', 'Clear this report'), isFalse);
  });

  test('legacy report payload migrates into the current store', () async {
    final legacy = [
      {
        'id': 'local_1',
        'reference': 'LOCAL-1',
        'uid': '',
        'type': 'personalConcern',
        'category': 'vaccination',
        'description': 'A legacy report that should remain available offline.',
        'area': '',
        'status': 'pendingSync',
        'createdAt': '2026-01-01T10:00:00.000',
      },
    ];
    final reports = await service({
      'healthmate_reports_v1': jsonEncode(legacy),
    });

    final history = await reports.loadHistory();
    expect(history, hasLength(1));
    expect(history.single.id, 'local_1');
    expect(history.single.status, ReportStatus.saved);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('healthmate_reports_v1'), isNull);
  });
}
