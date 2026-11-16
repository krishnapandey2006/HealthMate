/// The single source of truth for a HealthMate profile.
///
/// Profiles are stored locally only. Age is always derived from [dateOfBirth];
/// it is never stored as a separate field.
class UserProfile {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime? dateOfBirth;
  final String gender;
  final String state;
  final String city;
  final String languageCode;
  final bool needsAssistance;
  final bool voiceGuidance;

  /// Optional emergency and health details. Every field is guarded so an older
  /// saved profile without these keys still loads unchanged.
  final String bloodGroup;
  final String allergies;
  final String conditions;
  final String emergencyContactName;
  final String emergencyContactPhone;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.dateOfBirth,
    this.gender = 'female',
    this.state = '',
    this.city = '',
    this.languageCode = 'en',
    this.needsAssistance = false,
    this.voiceGuidance = true,
    this.bloodGroup = '',
    this.allergies = '',
    this.conditions = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.createdAt,
    this.updatedAt,
  });

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'HealthMate user' : name;
  }

  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years < 0 ? null : years;
  }

  int? get ageInMonths {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var months = (now.year - dob.year) * 12 + now.month - dob.month;
    if (now.day < dob.day) months--;
    return months < 0 ? null : months;
  }

  /// Fields required before the dashboard can be shown. Everything else can be
  /// completed later from Profile without blocking the user.
  bool get isComplete =>
      firstName.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      dateOfBirth != null &&
      state.trim().isNotEmpty;

  List<String> get missingFields {
    final missing = <String>[];
    if (firstName.trim().isEmpty) missing.add('name');
    if (phone.trim().isEmpty) missing.add('phone');
    if (dateOfBirth == null) missing.add('date_of_birth');
    if (state.trim().isEmpty) missing.add('state');
    return missing;
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? gender,
    String? state,
    String? city,
    String? languageCode,
    bool? needsAssistance,
    bool? voiceGuidance,
    String? bloodGroup,
    String? allergies,
    String? conditions,
    String? emergencyContactName,
    String? emergencyContactPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      gender: gender ?? this.gender,
      state: state ?? this.state,
      city: city ?? this.city,
      languageCode: languageCode ?? this.languageCode,
      needsAssistance: needsAssistance ?? this.needsAssistance,
      voiceGuidance: voiceGuidance ?? this.voiceGuidance,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'gender': gender,
        'state': state,
        'city': city,
        'languageCode': languageCode,
        'needsAssistance': needsAssistance,
        'voiceGuidance': voiceGuidance,
        'bloodGroup': bloodGroup,
        'allergies': allergies,
        'conditions': conditions,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    final first =
        (map['firstName'] ?? map['first_name'] ?? '').toString().trim();
    final last = (map['lastName'] ?? map['last_name'] ?? '').toString().trim();
    final legacyName =
        (map['name'] ?? map['user_name'] ?? '').toString().trim();
    var firstName = first;
    var lastName = last;
    if (firstName.isEmpty && legacyName.isNotEmpty) {
      final parts = legacyName.split(RegExp(r'\s+'));
      firstName = parts.first;
      if (lastName.isEmpty && parts.length > 1) {
        lastName = parts.sublist(1).join(' ');
      }
    }

    return UserProfile(
      firstName: firstName,
      lastName: lastName,
      email: (map['email'] ?? map['user_email'] ?? '').toString().trim(),
      phone: (map['phone'] ?? map['user_phone'] ?? '').toString().trim(),
      dateOfBirth:
          parseDate(map['dateOfBirth'] ?? map['user_dob'] ?? map['dob']),
      gender: (map['gender'] ?? map['user_gender'] ?? 'female').toString(),
      state: (map['state'] ?? map['user_state'] ?? '').toString(),
      city: (map['city'] ?? map['user_city'] ?? '').toString(),
      languageCode:
          (map['languageCode'] ?? map['language_code'] ?? 'en').toString(),
      needsAssistance:
          map['needsAssistance'] == true || map['needs_assistance'] == true,
      voiceGuidance:
          map['voiceGuidance'] != false && map['allow_critical_alerts'] != false,
      bloodGroup: (map['bloodGroup'] ?? map['blood_group'] ?? '').toString(),
      allergies: (map['allergies'] ?? '').toString(),
      conditions: (map['conditions'] ?? map['medical_conditions'] ?? '').toString(),
      emergencyContactName:
          (map['emergencyContactName'] ?? map['emergency_contact_name'] ?? '')
              .toString(),
      emergencyContactPhone:
          (map['emergencyContactPhone'] ?? map['emergency_contact_phone'] ?? '')
              .toString(),
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      updatedAt: parseDate(map['updatedAt'] ?? map['updated_at']),
    );
  }
}
