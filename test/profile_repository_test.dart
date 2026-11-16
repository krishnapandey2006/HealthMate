import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/models/user_profile.dart';
import 'package:healthmate_mb/services/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProfileRepository> repository([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return ProfileRepository(prefs: prefs);
  }

  final profile = UserProfile(
    firstName: 'Asha',
    lastName: 'Patil',
    email: 'asha@example.com',
    phone: '9876543210',
    dateOfBirth: DateTime(1992, 8, 15),
    gender: 'female',
    state: 'Maharashtra',
    city: 'Pune',
    languageCode: 'mr',
    needsAssistance: true,
    bloodGroup: 'O+',
    allergies: 'Penicillin',
    conditions: 'Asthma',
    emergencyContactName: 'Ravi Patil',
    emergencyContactPhone: '9988776655',
    createdAt: DateTime(2026, 1, 2, 10),
    updatedAt: DateTime(2026, 1, 3, 11),
  );

  test('profile saves and reloads from local storage with all fields',
      () async {
    final store = await repository();

    expect(await store.save(profile), isTrue);
    final loaded = await store.load();

    expect(loaded, isNotNull);
    expect(loaded!.firstName, 'Asha');
    expect(loaded.lastName, 'Patil');
    expect(loaded.email, 'asha@example.com');
    expect(loaded.phone, '9876543210');
    expect(loaded.dateOfBirth, DateTime(1992, 8, 15));
    expect(loaded.state, 'Maharashtra');
    expect(loaded.city, 'Pune');
    expect(loaded.languageCode, 'mr');
    expect(loaded.needsAssistance, isTrue);
    expect(loaded.bloodGroup, 'O+');
    expect(loaded.allergies, 'Penicillin');
    expect(loaded.conditions, 'Asthma');
    expect(loaded.emergencyContactName, 'Ravi Patil');
    expect(loaded.emergencyContactPhone, '9988776655');
    expect(loaded.createdAt, DateTime(2026, 1, 2, 10));
    expect(loaded.updatedAt, DateTime(2026, 1, 3, 11));
    expect(loaded.age, profile.age);
  });

  test('missing and corrupt values return null instead of throwing', () async {
    expect(await (await repository()).load(), isNull);

    final store = await repository({
      'healthmate_profile_v2_device': '{not valid json',
    });
    expect(await store.load(), isNull);
  });

  test('clear removes the profile and the skipped-setup flag', () async {
    final store = await repository();
    await store.save(profile);
    await store.setSetupSkipped(true);
    expect(await store.loadSetupSkipped(), isTrue);

    await store.clear();

    expect(await store.load(), isNull);
    expect(await store.loadSetupSkipped(), isFalse);
  });

  test('legacy split keys migrate into one profile', () async {
    final store = await repository({
      'first_name': 'Ravi',
      'last_name': 'Kumar',
      'user_phone': '9999999999',
      'user_dob': '1988-03-04',
      'user_gender': 'male',
      'user_state': 'Tamil Nadu',
      'language_code': 'ta',
    });

    final migrated = await store.migrateLegacy();
    final loaded = await store.load();

    expect(migrated?.firstName, 'Ravi');
    expect(migrated?.lastName, 'Kumar');
    expect(migrated?.dateOfBirth, DateTime(1988, 3, 4));
    expect(loaded?.phone, '9999999999');
    expect(loaded?.state, 'Tamil Nadu');
    expect(loaded?.languageCode, 'ta');
  });

  test('legacy user_name is split without storing a separate age', () async {
    final store = await repository({
      'user_name': 'Meera Joshi',
      'user_phone': '9888888888',
      'user_dob': '1995-06-10',
    });

    final migrated = await store.migrateLegacy();

    expect(migrated?.firstName, 'Meera');
    expect(migrated?.lastName, 'Joshi');
    expect(migrated?.age, isNotNull);
    expect(migrated?.toMap().containsKey('age'), isFalse);
  });

  test('profile completeness requires name, phone, date of birth and state',
      () {
    expect(profile.isComplete, isTrue);
    expect(profile.missingFields, isEmpty);

    final incomplete = profile.copyWith(
      firstName: '',
      phone: '',
      clearDateOfBirth: true,
      state: '',
    );
    expect(incomplete.isComplete, isFalse);
    expect(
      incomplete.missingFields,
      containsAll(<String>['name', 'phone', 'date_of_birth', 'state']),
    );
  });
}
