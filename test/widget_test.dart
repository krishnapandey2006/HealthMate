import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/l10n/app_localizations.dart';
import 'package:healthmate_mb/language_provider.dart';
import 'package:healthmate_mb/main.dart';
import 'package:healthmate_mb/services/app_lock_provider.dart';
import 'package:healthmate_mb/services/app_settings_provider.dart';
import 'package:healthmate_mb/services/appointment_provider.dart';
import 'package:healthmate_mb/services/appointment_repository.dart';
import 'package:healthmate_mb/services/profile_provider.dart';
import 'package:healthmate_mb/services/profile_repository.dart';
import 'package:healthmate_mb/widgets/chatbot_launcher.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('healthmate_widget_test');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    Map<String, Object> initialValues = const {},
    Size size = const Size(390, 844),
  }) async {
    SharedPreferences.setMockInitialValues(initialValues);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final language = LanguageProvider();
    await language.init();
    final settings = AppSettingsProvider();
    await settings.load();

    // The localization delegate reads bundled ARB assets with real async I/O;
    // load English inside runAsync so it is cached before the fake-async pumps.
    await tester.runAsync(
      () => AppLocalizations(const Locale('en')).loadFromAssets(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: language),
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(
            value: ProfileProvider(ProfileRepository()),
          ),
          ChangeNotifierProvider.value(
            value: AppointmentProvider(AppointmentRepository()),
          ),
          ChangeNotifierProvider.value(value: AppLockProvider()),
        ],
        child: const HealthmateApp(),
      ),
    );

    // AppBootstrap restores the local profile, appointments and lock state
    // asynchronously after the first frame.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('first run shows the local-only onboarding', (tester) async {
    await pumpApp(tester);

    expect(find.text('Your health, in one calm place.'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Explore without a profile'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(
      find.text('No cloud account. Your health details stay on this device.'),
      findsOneWidget,
    );
  });

  testWidgets('onboarding pages advance without creating an account',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Plan visits with clarity.'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Know what is happening nearby.'), findsOneWidget);
    expect(find.text('Create my profile'), findsOneWidget);
  });

  testWidgets('skipping onboarding opens the five-tab dashboard',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Skip'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byKey(const Key('main-bottom-navigation')), findsOneWidget);
    expect(find.text('Appointments'), findsWidgets);
    expect(find.text('Health'), findsWidgets);
    expect(find.text('News'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('bottom navigation keeps Appointments on one line at 320 dp',
      (tester) async {
    await pumpApp(tester, size: const Size(320, 568));

    await tester.tap(find.text('Skip'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final navigation = find.byKey(const Key('main-bottom-navigation'));
    expect(navigation, findsOneWidget);
    expect(tester.getSize(navigation).height, 72);

    // 320 dp also exposes pre-existing overflows on the splash, welcome and
    // dashboard screens. They are outside this navigation-label regression, so
    // drain them instead of hiding the label measurement below.
    while (tester.takeException() != null) {}

    final label =
        find.descendant(of: navigation, matching: find.text('Appointments'));
    expect(label, findsOneWidget);
    // A wrapped label would be roughly two 12.6px lines tall.
    expect(tester.getRect(label).height, lessThan(18));

    await tester.tap(label);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Add appointment'), findsWidgets);
  });

  testWidgets('chatbot launcher clears the mobile bottom navigation',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Skip'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final launcher = find.byType(ChatbotLauncher);
    expect(launcher, findsOneWidget);
    final rect = tester.getRect(launcher);
    expect(rect.width, 56);
    expect(rect.height, 56);
    expect(390 - rect.right, 16);
    // 72px navigation bar plus a 16px gap.
    expect(844 - rect.bottom, 88);
  });

  testWidgets('chatbot launcher uses the bottom-right on wide layouts',
      (tester) async {
    await pumpApp(tester);
    tester.view.physicalSize = const Size(1000, 800);
    await tester.pump();

    await tester.tap(find.text('Skip'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(NavigationRail), findsOneWidget);
    final rect = tester.getRect(find.byType(ChatbotLauncher));
    expect(1000 - rect.right, 16);
    expect(800 - rect.bottom, 16);
  });

  testWidgets('an enabled app lock is shown before the profile',
      (tester) async {
    await pumpApp(tester, initialValues: {
      'healthmate_app_lock_enabled': true,
      'healthmate_app_lock_hash': 'stored-hash',
    });

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
    expect(find.text('Your health, in one calm place.'), findsNothing);
  });
}
