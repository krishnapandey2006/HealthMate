import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional four-to-six digit screen lock for the local HealthMate profile.
///
/// This is a privacy screen, not file encryption: someone with access to the
/// device's storage or developer tools may still be able to read local data.
class AppLockProvider extends ChangeNotifier {
  static const _enabledKey = 'healthmate_app_lock_enabled';
  static const _hashKey = 'healthmate_app_lock_hash';
  static const _attemptsKey = 'healthmate_app_lock_attempts';
  static const _lockoutUntilKey = 'healthmate_app_lock_lockout_until';

  bool _initialized = false;
  bool _enabled = false;
  bool _locked = false;
  bool _busy = false;
  String? _error;

  bool get initialized => _initialized;
  bool get enabled => _enabled;
  bool get locked => _enabled && _locked;
  bool get busy => _busy;
  String? get error => _error;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
      _locked = _enabled;
      _error = null;
    } catch (_) {
      _enabled = false;
      _locked = false;
      _error = 'The optional app lock is unavailable on this device.';
    }
    _initialized = true;
    notifyListeners();
  }

  void lockNow() {
    if (!_enabled) return;
    _locked = true;
    notifyListeners();
  }

  /// Returns true only when the PIN was correct. A short cooldown after five
  /// failed attempts makes repeated guessing harder on a shared device.
  Future<bool> unlock(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutUntil = prefs.getInt(_lockoutUntilKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < lockoutUntil) {
      _error = 'Too many attempts. Wait a few seconds and try again.';
      notifyListeners();
      return false;
    }

    final hash = prefs.getString(_hashKey) ?? '';
    if (hash.isEmpty) {
      _enabled = false;
      _locked = false;
      await prefs.setBool(_enabledKey, false);
      notifyListeners();
      return true;
    }

    if (_hashPin(pin) == hash) {
      _locked = false;
      _error = null;
      await prefs.setInt(_attemptsKey, 0);
      await prefs.remove(_lockoutUntilKey);
      notifyListeners();
      return true;
    }

    final attempts = (prefs.getInt(_attemptsKey) ?? 0) + 1;
    await prefs.setInt(_attemptsKey, attempts);
    if (attempts >= 5) {
      await prefs.setInt(
        _lockoutUntilKey,
        DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch,
      );
      await prefs.setInt(_attemptsKey, 0);
      _error = 'Too many attempts. Wait 30 seconds and try again.';
    } else {
      _error = 'That PIN is not correct. ${5 - attempts} attempts left.';
    }
    notifyListeners();
    return false;
  }

  Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString(_hashKey) ?? '';
    return hash.isNotEmpty && _hashPin(pin) == hash;
  }

  /// Enables the lock or changes the PIN. Returns false when the PIN is invalid
  /// or storage rejected the change.
  Future<bool> setPin(String pin) async {
    if (!_isValidPin(pin)) {
      _error = 'Use a 4 to 6 digit PIN.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final hashSaved = await prefs.setString(_hashKey, _hashPin(pin));
      final enabledSaved = await prefs.setBool(_enabledKey, true);
      if (!hashSaved || !enabledSaved) {
        _error = 'The PIN could not be saved on this device.';
        return false;
      }
      _enabled = true;
      _locked = false;
      return true;
    } catch (_) {
      _error = 'The PIN could not be saved on this device.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> disable(String pin) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final hash = prefs.getString(_hashKey) ?? '';
      if (hash.isEmpty || _hashPin(pin) != hash) {
        _error = 'That PIN is not correct.';
        return false;
      }
      await prefs.setBool(_enabledKey, false);
      await prefs.remove(_hashKey);
      await prefs.remove(_attemptsKey);
      await prefs.remove(_lockoutUntilKey);
      _enabled = false;
      _locked = false;
      return true;
    } catch (_) {
      _error = 'The app lock could not be disabled.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Removes the PIN and all lock state. Used when local data is erased.
  Future<void> resetToDefaults() async {
    _enabled = false;
    _locked = false;
    _busy = false;
    _error = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_enabledKey);
      await prefs.remove(_hashKey);
      await prefs.remove(_attemptsKey);
      await prefs.remove(_lockoutUntilKey);
    } catch (_) {
      // State is still cleared in memory for this session.
    }
    notifyListeners();
  }

  static bool _isValidPin(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  static String _hashPin(String pin) =>
      sha256.convert(utf8.encode('HealthMate|app-lock|v1|$pin')).toString();
}
