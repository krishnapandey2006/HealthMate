import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/appointment.dart';

/// Stores personal appointments on the device. No network or account is
/// involved, and no hospital slot is reserved.
class AppointmentRepository {
  static const storageKey = 'healthmate_appointments_v1';

  final SharedPreferences? _prefsOverride;

  AppointmentRepository({SharedPreferences? prefs}) : _prefsOverride = prefs;

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  Future<List<Appointment>> load() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final appointments = <Appointment>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final appointment = Appointment.fromMap(Map<String, dynamic>.from(item));
        if (appointment.id.trim().isEmpty || appointment.title.trim().isEmpty) {
          continue;
        }
        appointments.add(appointment);
      }
      appointments.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return appointments;
    } catch (_) {
      return const [];
    }
  }

  Future<bool> save(List<Appointment> appointments) async {
    try {
      final prefs = await _prefs();
      final payload = jsonEncode(
        appointments.map((appointment) => appointment.toMap()).toList(),
      );
      return await prefs.setString(storageKey, payload);
    } catch (_) {
      return false;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await _prefs();
      await prefs.remove(storageKey);
    } catch (_) {
      // The provider still clears its in-memory copy.
    }
  }
}
