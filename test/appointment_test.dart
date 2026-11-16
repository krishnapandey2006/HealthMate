import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/models/appointment.dart';
import 'package:healthmate_mb/services/appointment_provider.dart';
import 'package:healthmate_mb/services/appointment_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingRepository extends AppointmentRepository {
  @override
  Future<bool> save(List<Appointment> appointments) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppointmentRepository> repository() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return AppointmentRepository(prefs: prefs);
  }

  Appointment sample({
    String id = 'a1',
    DateTime? scheduledAt,
    AppointmentStatus status = AppointmentStatus.scheduled,
  }) {
    final slot = scheduledAt ?? DateTime.now().add(const Duration(days: 2));
    return Appointment(
      id: id,
      title: 'Cardiology follow-up',
      provider: 'Dr Rao',
      location: 'City Clinic',
      scheduledAt: slot,
      durationMinutes: 30,
      kind: AppointmentKind.followUp,
      status: status,
      notes: 'Bring previous reports',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
    );
  }

  group('Appointment model', () {
    test('serializes and restores every field', () {
      final original = sample(
        scheduledAt: DateTime(2026, 12, 10, 9, 30),
        status: AppointmentStatus.cancelled,
      );
      final restored = Appointment.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.provider, original.provider);
      expect(restored.location, original.location);
      expect(restored.scheduledAt, original.scheduledAt);
      expect(restored.durationMinutes, 30);
      expect(restored.kind, AppointmentKind.followUp);
      expect(restored.status, AppointmentStatus.cancelled);
      expect(restored.notes, original.notes);
    });

    test('status keys distinguish upcoming, past and closed appointments', () {
      final future = sample(
        scheduledAt: DateTime.now().add(const Duration(days: 4)),
      );
      final past = sample(
        scheduledAt: DateTime.now().subtract(const Duration(days: 4)),
      );

      expect(future.statusKey, 'upcoming');
      expect(past.statusKey, 'past');
      expect(
        sample(status: AppointmentStatus.completed).statusKey,
        'completed',
      );
      expect(
        sample(status: AppointmentStatus.cancelled).statusKey,
        'cancelled',
      );
    });

    test('duration is clamped when reading damaged storage', () {
      final restored = Appointment.fromMap({
        ...sample().toMap(),
        'durationMinutes': 5000,
      });
      expect(restored.durationMinutes, 240);
    });

    test('generated ids are unique and never empty', () {
      final first = Appointment.create(
        title: 'Blood test',
        scheduledAt: DateTime(2026, 12, 1, 9),
      );
      final second = Appointment.create(
        title: 'Blood test',
        scheduledAt: DateTime(2026, 12, 1, 9),
      );

      expect(first.id, isNotEmpty);
      expect(second.id, isNotEmpty);
      expect(first.id, isNot(second.id));
    });
  });

  group('AppointmentRepository', () {
    test('saves and reloads appointments in time order', () async {
      final store = await repository();
      final later = sample(
        id: 'later',
        scheduledAt: DateTime.now().add(const Duration(days: 5)),
      );
      final sooner = sample(
        id: 'sooner',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
      );

      expect(await store.save([later, sooner]), isTrue);
      final loaded = await store.load();

      expect(loaded.map((item) => item.id), ['sooner', 'later']);
    });

    test('skips malformed entries instead of failing the whole list', () async {
      SharedPreferences.setMockInitialValues({
        AppointmentRepository.storageKey:
            '[{"id":"","title":""},{"id":"ok","title":"Visit",'
                '"scheduledAt":"2030-01-01T10:00:00.000"}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = AppointmentRepository(prefs: prefs);

      final loaded = await store.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'ok');
    });

    test('clear removes the saved list', () async {
      final store = await repository();
      await store.save([sample()]);
      await store.clear();
      expect(await store.load(), isEmpty);
    });
  });

  group('AppointmentProvider', () {
    test('creates a valid appointment and persists it', () async {
      final store = await repository();
      final provider = AppointmentProvider(store);
      await provider.initialize();

      final slot = DateTime.now().add(const Duration(days: 2));
      final error = await provider.create(
        title: '  Eye check-up  ',
        scheduledAt: slot,
        provider: 'Dr Shah',
        location: 'Vision Centre',
        durationMinutes: 45,
        kind: AppointmentKind.consultation,
      );

      expect(error, isNull);
      expect(provider.appointments, hasLength(1));
      expect(provider.appointments.single.title, 'Eye check-up');
      expect(provider.scheduledCount, 1);

      final secondProvider = AppointmentProvider(store);
      await secondProvider.initialize();
      expect(secondProvider.appointments.single.title, 'Eye check-up');
    });

    test('rejects short titles, past dates and invalid durations', () async {
      final provider = AppointmentProvider(await repository());
      await provider.initialize();

      expect(
        await provider.create(title: 'Hi', scheduledAt: DateTime.now().add(
          const Duration(days: 1),
        )),
        contains('at least 3 characters'),
      );
      expect(
        await provider.create(
          title: 'Valid reason',
          scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        contains('future'),
      );
      expect(
        await provider.create(
          title: 'Valid reason',
          scheduledAt: DateTime.now().add(const Duration(days: 1)),
          durationMinutes: 5,
        ),
        contains('between 10 minutes and 4 hours'),
      );
      expect(provider.appointments, isEmpty);
    });

    test('prevents two appointments in the same minute', () async {
      final provider = AppointmentProvider(await repository());
      await provider.initialize();
      final slot = DateTime.now().add(const Duration(days: 3));
      final day = DateTime(slot.year, slot.month, slot.day, 10, 15);

      expect(
        await provider.create(title: 'First visit', scheduledAt: day),
        isNull,
      );
      final duplicate = await provider.create(
        title: 'Second visit',
        scheduledAt: day.add(const Duration(seconds: 20)),
      );

      expect(duplicate, contains('already have an appointment'));
      expect(provider.appointments, hasLength(1));
    });

    test('cancelling frees the slot and marks the appointment cancelled',
        () async {
      final provider = AppointmentProvider(await repository());
      await provider.initialize();
      final slot = DateTime.now().add(const Duration(days: 4));
      final day = DateTime(slot.year, slot.month, slot.day, 11, 0);

      await provider.create(title: 'First visit', scheduledAt: day);
      final id = provider.appointments.single.id;

      expect(await provider.cancel(id), isNull);
      expect(provider.appointments.single.status, AppointmentStatus.cancelled);
      expect(provider.appointments.single.cancelledAt, isNotNull);
      expect(provider.scheduledCount, 0);

      final replacement = await provider.create(
        title: 'Replacement visit',
        scheduledAt: day,
      );
      expect(replacement, isNull);
      expect(provider.appointments, hasLength(2));
    });

    test('completes and removes appointments', () async {
      final provider = AppointmentProvider(await repository());
      await provider.initialize();
      await provider.create(
        title: 'Blood test',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
      );
      final id = provider.appointments.single.id;

      expect(await provider.markCompleted(id), isNull);
      expect(
        provider.appointments.single.status,
        AppointmentStatus.completed,
      );

      expect(await provider.remove(id), isNull);
      expect(provider.appointments, isEmpty);
    });

    test('reports a storage failure and keeps the previous list', () async {
      final provider = AppointmentProvider(_FailingRepository());
      await provider.initialize();
      final error = await provider.create(
        title: 'Cardiology visit',
        scheduledAt: DateTime.now().add(const Duration(days: 2)),
      );

      expect(error, contains('did not accept'));
      expect(provider.storageError, contains('did not accept'));
      expect(provider.appointments, isEmpty);
    });

    test('resetToDefaults clears the list and stored payload', () async {
      final store = await repository();
      final provider = AppointmentProvider(store);
      await provider.initialize();
      await provider.create(
        title: 'Dermatology visit',
        scheduledAt: DateTime.now().add(const Duration(days: 2)),
      );

      await provider.resetToDefaults();

      expect(provider.appointments, isEmpty);
      expect(await store.load(), isEmpty);
    });
  });
}
