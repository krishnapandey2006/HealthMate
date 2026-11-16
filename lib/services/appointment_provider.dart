import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import 'appointment_repository.dart';

/// Local appointment planner state. All writes are confirmed by the repository
/// before the in-memory list changes, so the UI never reports a save that did
/// not happen.
class AppointmentProvider extends ChangeNotifier {
  final AppointmentRepository _repository;

  List<Appointment> _appointments = const [];
  bool _loading = true;
  bool _initialized = false;
  bool _saving = false;
  String? _storageError;

  AppointmentProvider(this._repository);

  List<Appointment> get appointments => List.unmodifiable(_appointments);
  bool get loading => _loading;
  bool get initialized => _initialized;
  bool get saving => _saving;
  String? get storageError => _storageError;

  List<Appointment> get upcoming {
    final now = DateTime.now();
    return _appointments
        .where((appointment) =>
            appointment.status == AppointmentStatus.scheduled &&
            !appointment.scheduledAt.isBefore(now))
        .toList(growable: false)
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<Appointment> get past {
    final now = DateTime.now();
    return _appointments
        .where((appointment) =>
            appointment.status == AppointmentStatus.completed ||
            appointment.status == AppointmentStatus.cancelled ||
            appointment.scheduledAt.isBefore(now))
        .where((appointment) => appointment.status != AppointmentStatus.scheduled ||
            appointment.scheduledAt.isBefore(now))
        .toList(growable: false)
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  }

  Appointment? get nextAppointment {
    final list = upcoming;
    return list.isEmpty ? null : list.first;
  }

  int get scheduledCount => _appointments
      .where((appointment) =>
          appointment.status == AppointmentStatus.scheduled &&
          !appointment.scheduledAt.isBefore(DateTime.now()))
      .length;

  Future<void> initialize() async {
    if (_initialized) return;
    _loading = true;
    notifyListeners();
    try {
      _appointments = await _repository.load();
      _storageError = null;
    } catch (_) {
      _storageError =
          'Appointments could not be read from this device. New changes cannot be saved right now.';
    }
    _initialized = true;
    _loading = false;
    notifyListeners();
  }

  /// Returns null on success, or a user-readable validation/persistence error.
  Future<String?> create({
    required String title,
    required DateTime scheduledAt,
    String provider = '',
    String location = '',
    int durationMinutes = 30,
    AppointmentKind kind = AppointmentKind.consultation,
    String notes = '',
  }) async {
    final validation = _validate(
      title: title,
      scheduledAt: scheduledAt,
      provider: provider,
      location: location,
      durationMinutes: durationMinutes,
    );
    if (validation != null) return validation;

    if (_hasSlotConflict(scheduledAt)) {
      return 'You already have an appointment at this date and time. Choose another time or cancel the existing one first.';
    }

    final appointment = Appointment.create(
      title: title,
      scheduledAt: scheduledAt,
      provider: provider,
      location: location,
      durationMinutes: durationMinutes,
      kind: kind,
      notes: notes,
    );
    return _commit([..._appointments, appointment]);
  }

  /// Returns null on success, or a user-readable validation/persistence error.
  Future<String?> update({
    required Appointment appointment,
    required String title,
    required DateTime scheduledAt,
    String provider = '',
    String location = '',
    int durationMinutes = 30,
    AppointmentKind kind = AppointmentKind.consultation,
    String notes = '',
  }) async {
    final validation = _validate(
      title: title,
      scheduledAt: scheduledAt,
      provider: provider,
      location: location,
      durationMinutes: durationMinutes,
    );
    if (validation != null) return validation;

    if (_hasSlotConflict(scheduledAt, ignoreId: appointment.id)) {
      return 'Another appointment already uses this date and time. Choose a different slot.';
    }

    final updated = appointment.copyWith(
      title: title.trim(),
      provider: provider.trim(),
      location: location.trim(),
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      kind: kind,
      notes: notes.trim(),
      updatedAt: DateTime.now(),
    );
    return _commit([
      for (final item in _appointments)
        if (item.id == appointment.id) updated else item,
    ]);
  }

  Future<String?> markCompleted(String id) async {
    final updated = _appointments.map((appointment) {
      if (appointment.id != id) return appointment;
      return appointment.copyWith(
        status: AppointmentStatus.completed,
        updatedAt: DateTime.now(),
      );
    }).toList(growable: false);
    return _commit(updated);
  }

  Future<String?> cancel(String id) async {
    final now = DateTime.now();
    final updated = _appointments.map((appointment) {
      if (appointment.id != id) return appointment;
      return appointment.copyWith(
        status: AppointmentStatus.cancelled,
        updatedAt: now,
        cancelledAt: now,
      );
    }).toList(growable: false);
    return _commit(updated);
  }

  Future<String?> remove(String id) async {
    return _commit(
      _appointments.where((appointment) => appointment.id != id).toList(),
    );
  }

  Future<String?> clearAll() => _commit(const []);

  /// Removes appointments without writing a replacement payload. Used by the
  /// full local-data reset.
  Future<void> resetToDefaults() async {
    try {
      await _repository.clear();
    } catch (_) {
      // The in-memory list is still cleared for this session.
    }
    _appointments = const [];
    _storageError = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _appointments = await _repository.load();
      _storageError = null;
    } catch (_) {
      _storageError = 'Appointments could not be read from this device.';
    }
    notifyListeners();
  }

  Future<String?> _commit(List<Appointment> next) async {
    if (_saving) return 'A change is already being saved. Please wait.';
    _saving = true;
    notifyListeners();
    try {
      next.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      final saved = await _repository.save(next);
      if (!saved) {
        _storageError =
            'This device did not accept the appointment change. Free up storage and try again.';
        return _storageError;
      }
      _appointments = List.unmodifiable(next);
      _storageError = null;
      return null;
    } catch (_) {
      _storageError =
          'Appointments are stored on this device, but storage is unavailable right now.';
      return _storageError;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  bool _hasSlotConflict(DateTime slot, {String? ignoreId}) {
    return _appointments.any((appointment) {
      if (appointment.status == AppointmentStatus.cancelled) return false;
      if (ignoreId != null && appointment.id == ignoreId) return false;
      return Appointment.isSameSlot(appointment, Appointment(
        id: '',
        title: '',
        scheduledAt: slot,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    });
  }

  String? _validate({
    required String title,
    required DateTime scheduledAt,
    required String provider,
    required String location,
    required int durationMinutes,
  }) {
    if (title.trim().length < 3) {
      return 'Add a reason for the appointment (at least 3 characters).';
    }
    if (!scheduledAt.isAfter(DateTime.now())) {
      return 'Choose a date and time in the future.';
    }
    if (scheduledAt.isAfter(DateTime.now().add(const Duration(days: 730)))) {
      return 'Please choose a date within the next two years.';
    }
    if (durationMinutes < 10 || durationMinutes > 240) {
      return 'Choose a duration between 10 minutes and 4 hours.';
    }
    if (provider.length > 120 || location.length > 200) {
      return 'The doctor/clinic or location is too long.';
    }
    return null;
  }
}
