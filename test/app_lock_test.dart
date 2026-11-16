import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/services/app_lock_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('rejects a PIN shorter than four digits or containing letters', () async {
    final lock = AppLockProvider();
    await lock.initialize();

    expect(await lock.setPin('123'), isFalse);
    expect(lock.error, contains('4 to 6 digit'));
    expect(await lock.setPin('12ab'), isFalse);
    expect(lock.enabled, isFalse);
  });

  test('enables the lock, verifies the PIN and unlocks', () async {
    final lock = AppLockProvider();
    await lock.initialize();
    expect(lock.enabled, isFalse);

    expect(await lock.setPin('4821'), isTrue);
    expect(lock.enabled, isTrue);
    expect(lock.locked, isFalse);
    expect(await lock.verify('4821'), isTrue);
    expect(await lock.verify('0000'), isFalse);

    lock.lockNow();
    expect(lock.locked, isTrue);

    expect(await lock.unlock('0000'), isFalse);
    expect(lock.locked, isTrue);
    expect(lock.error, contains('attempts left'));

    expect(await lock.unlock('4821'), isTrue);
    expect(lock.locked, isFalse);
    expect(lock.error, isNull);
  });

  test('five wrong attempts start a short cooldown', () async {
    final lock = AppLockProvider();
    await lock.initialize();
    await lock.setPin('7777');
    lock.lockNow();

    for (var attempt = 1; attempt <= 5; attempt++) {
      expect(await lock.unlock('1111'), isFalse);
    }

    expect(lock.error, contains('Too many attempts'));
    // The correct PIN is still rejected while the cooldown is active.
    expect(await lock.unlock('7777'), isFalse);
    expect(lock.locked, isTrue);
  });

  test('disabling requires the current PIN', () async {
    final lock = AppLockProvider();
    await lock.initialize();
    await lock.setPin('9090');

    expect(await lock.disable('0000'), isFalse);
    expect(lock.enabled, isTrue);
    expect(lock.error, contains('not correct'));

    expect(await lock.disable('9090'), isTrue);
    expect(lock.enabled, isFalse);
    expect(await lock.verify('9090'), isFalse);
  });

  test('a second provider restores the enabled lock after restart', () async {
    final first = AppLockProvider();
    await first.initialize();
    await first.setPin('3141');

    final second = AppLockProvider();
    await second.initialize();

    expect(second.enabled, isTrue);
    expect(second.locked, isTrue);
    expect(await second.unlock('3141'), isTrue);
  });

  test('resetToDefaults removes the PIN and lock state', () async {
    final lock = AppLockProvider();
    await lock.initialize();
    await lock.setPin('5150');
    expect(lock.enabled, isTrue);

    await lock.resetToDefaults();

    expect(lock.enabled, isFalse);
    expect(lock.locked, isFalse);
    expect(await lock.verify('5150'), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('healthmate_app_lock_enabled'), isNull);
    expect(prefs.getString('healthmate_app_lock_hash'), isNull);
  });
}
