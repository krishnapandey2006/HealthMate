import 'dart:math';

enum AppointmentStatus { scheduled, completed, cancelled }

enum AppointmentKind { consultation, vaccination, lab, followUp, other }

/// A personal appointment reminder saved on this device.
///
/// HealthMate does not have a connection to hospital slot systems. An
/// [Appointment] records a visit the user has arranged themselves; it is not a
/// confirmed hospital booking.
class Appointment {
  final String id;
  final String title;
  final String provider;
  final String location;
  final DateTime scheduledAt;
  final int durationMinutes;
  final AppointmentKind kind;
  final AppointmentStatus status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? cancelledAt;

  const Appointment({
    required this.id,
    required this.title,
    required this.scheduledAt,
    this.provider = '',
    this.location = '',
    this.durationMinutes = 30,
    this.kind = AppointmentKind.consultation,
    this.status = AppointmentStatus.scheduled,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    this.cancelledAt,
  });

  bool get isPast =>
      status == AppointmentStatus.scheduled &&
      scheduledAt.isBefore(DateTime.now());

  bool get isActionable => status == AppointmentStatus.scheduled;

  String get statusKey {
    switch (status) {
      case AppointmentStatus.completed:
        return 'completed';
      case AppointmentStatus.cancelled:
        return 'cancelled';
      case AppointmentStatus.scheduled:
        return isPast ? 'past' : 'upcoming';
    }
  }

  String get kindKey {
    switch (kind) {
      case AppointmentKind.consultation:
        return 'consultation';
      case AppointmentKind.vaccination:
        return 'vaccination';
      case AppointmentKind.lab:
        return 'lab_test';
      case AppointmentKind.followUp:
        return 'follow_up';
      case AppointmentKind.other:
        return 'other';
    }
  }

  DateTime get endsAt => scheduledAt.add(Duration(minutes: durationMinutes));

  Appointment copyWith({
    String? title,
    String? provider,
    String? location,
    DateTime? scheduledAt,
    int? durationMinutes,
    AppointmentKind? kind,
    AppointmentStatus? status,
    String? notes,
    DateTime? updatedAt,
    DateTime? cancelledAt,
  }) {
    return Appointment(
      id: id,
      title: title ?? this.title,
      provider: provider ?? this.provider,
      location: location ?? this.location,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'provider': provider,
        'location': location,
        'scheduledAt': scheduledAt.toIso8601String(),
        'durationMinutes': durationMinutes,
        'kind': kind.name,
        'status': status.name,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'cancelledAt': cancelledAt?.toIso8601String(),
      };

  factory Appointment.fromMap(Map<String, dynamic> map) {
    DateTime parse(dynamic value, DateTime fallback) {
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? fallback;
    }

    final created = parse(map['createdAt'], DateTime.now());
    final scheduled = parse(map['scheduledAt'], created);
    return Appointment(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString().trim(),
      provider: (map['provider'] ?? '').toString().trim(),
      location: (map['location'] ?? '').toString().trim(),
      scheduledAt: scheduled,
      durationMinutes: _asInt(map['durationMinutes'], 30).clamp(10, 240),
      kind: AppointmentKind.values.firstWhere(
        (value) => value.name == map['kind'],
        orElse: () => AppointmentKind.consultation,
      ),
      status: AppointmentStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => AppointmentStatus.scheduled,
      ),
      notes: (map['notes'] ?? '').toString(),
      createdAt: created,
      updatedAt: parse(map['updatedAt'], created),
      cancelledAt: DateTime.tryParse(map['cancelledAt']?.toString() ?? ''),
    );
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Appointment create({
    required String title,
    required DateTime scheduledAt,
    String provider = '',
    String location = '',
    int durationMinutes = 30,
    AppointmentKind kind = AppointmentKind.consultation,
    String notes = '',
  }) {
    final now = DateTime.now();
    // Avoid `1 << 32`: dart2js compiles integer shifts with 32-bit JavaScript
    // semantics, which turns that bound into 0 and makes nextInt throw.
    final random =
        Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return Appointment(
      id: '${now.microsecondsSinceEpoch}-$random',
      title: title.trim(),
      provider: provider.trim(),
      location: location.trim(),
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      kind: kind,
      notes: notes.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  static bool isSameSlot(Appointment a, Appointment b) =>
      a.scheduledAt.year == b.scheduledAt.year &&
      a.scheduledAt.month == b.scheduledAt.month &&
      a.scheduledAt.day == b.scheduledAt.day &&
      a.scheduledAt.hour == b.scheduledAt.hour &&
      a.scheduledAt.minute == b.scheduledAt.minute;
}
