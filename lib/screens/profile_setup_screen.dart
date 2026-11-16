import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../data/india_states.dart';
import '../l10n/app_localizations.dart';
import '../language_provider.dart';
import '../models/user_profile.dart';
import '../services/app_settings_provider.dart';
import '../services/facility_service.dart';
import '../services/profile_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/health_calendar.dart';

/// Two-step local profile creation and editing.
///
/// Step one captures the details needed for personalisation. Step two captures
/// location and optional care details. No account or network identity is
/// created; the location button is optional and only resolves a state name.
class ProfileSetupScreen extends StatefulWidget {
  final bool isEdit;

  /// Set this when the setup screen was pushed from another page and should
  /// return there after a successful save instead of waiting for AppGate.
  final bool popOnSave;

  const ProfileSetupScreen({
    super.key,
    this.isEdit = false,
    this.popOnSave = false,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _stepOneKey = GlobalKey<FormState>();
  final _stepTwoKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _cityController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  final FacilityService _facilityService = FacilityService();

  int _step = 0;
  DateTime? _dateOfBirth;
  String _gender = 'female';
  String _state = '';
  bool _voiceGuidance = true;
  bool _saving = false;
  bool _detectingLocation = false;
  bool _optionalExpanded = false;
  bool _stateError = false;
  String? _saveError;
  String? _locationMessage;
  String? _suggestedState;

  static const _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unknown',
  ];

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().profile;
    final settings = context.read<AppSettingsProvider>();
    if (profile != null) {
      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
      _phoneController.text = profile.phone;
      _emailController.text = profile.email;
      _dateOfBirth = profile.dateOfBirth;
      if (profile.dateOfBirth != null) {
        _dobController.text = formatFriendlyDate(profile.dateOfBirth!, includeWeekday: false);
      }
      _gender = profile.gender;
      _state = profile.state;
      _cityController.text = profile.city;
      _bloodGroupController.text = profile.bloodGroup;
      _allergiesController.text = profile.allergies;
      _conditionsController.text = profile.conditions;
      _emergencyNameController.text = profile.emergencyContactName;
      _emergencyPhoneController.text = profile.emergencyContactPhone;
      _voiceGuidance = profile.voiceGuidance;
      _optionalExpanded = profile.bloodGroup.isNotEmpty ||
          profile.allergies.isNotEmpty ||
          profile.conditions.isNotEmpty ||
          profile.emergencyContactName.isNotEmpty ||
          profile.emergencyContactPhone.isNotEmpty;
    } else {
      _voiceGuidance = settings.voiceGuidance;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _cityController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 120, now.month, now.day);
    var initial = _dateOfBirth ?? DateTime(now.year - 30, now.month, now.day);
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(now)) initial = now;
    final picked = await showHealthDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      initialDate: initial,
      title: AppLocalizations.of(context).t('select_date_of_birth'),
      subtitle: AppLocalizations.of(context).t('dob_calendar_note'),
      confirmLabel: AppLocalizations.of(context).t('use_this_date'),
      markEvents: false,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateOfBirth = picked;
      _dobController.text = formatFriendlyDate(picked, includeWeekday: false);
    });
  }

  Future<void> _pickState() async {
    final selected = await showStatePicker(
      context: context,
      selectedState: _state,
      suggestedState: _suggestedState,
    );
    if (selected != null && mounted) {
      setState(() {
        _state = selected;
        _stateError = false;
      });
    }
  }

  Future<void> _detectState() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _detectingLocation = true;
      _locationMessage = null;
      _suggestedState = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _detectingLocation = false;
            _locationMessage = l10n.t('location_services_off');
          });
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _detectingLocation = false;
            _locationMessage = l10n.t('location_permission_denied');
          });
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _detectingLocation = false;
            _locationMessage = l10n.t('location_permission_forever');
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final place = await _facilityService.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      if (place == null) {
        setState(() {
          _detectingLocation = false;
          _locationMessage = l10n.t('state_detect_failed');
        });
        return;
      }
      final match = findIndiaState(place.state) ??
          findIndiaState(place.displayName) ??
          findIndiaState(place.city);
      if (match == null) {
        setState(() {
          _detectingLocation = false;
          _locationMessage = l10n.t('state_detect_unknown');
        });
        return;
      }
      setState(() {
        _detectingLocation = false;
        _suggestedState = match.name;
        _locationMessage = l10n
            .t('state_detected_message')
            .replaceAll('{state}', match.name);
        if (_cityController.text.trim().isEmpty && place.city.isNotEmpty) {
          _cityController.text = place.city;
        }
      });
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _detectingLocation = false;
          _locationMessage = l10n.t('location_timeout');
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _detectingLocation = false;
          _locationMessage = l10n.t('location_unavailable');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _detectingLocation = false;
          _locationMessage = l10n.t('location_unavailable');
        });
      }
    }
  }

  Future<void> _openLocationSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context).t('settings_unavailable'),
          isError: true,
        );
      }
    }
  }

  void _nextStep() {
    if (!(_stepOneKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = 1);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saveError = null);
    // Step one is unmounted while step two is shown, so its form state is not
    // available here. It was already validated by [_nextStep] before advancing;
    // re-validate only when the user is on step one (for example in edit mode).
    if (_step == 0 &&
        !(_stepOneKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!(_stepTwoKey.currentState?.validate() ?? false)) return;
    if (_state.trim().isEmpty) {
      setState(() {
        _stateError = true;
        _step = 1;
      });
      return;
    }
    if (_saving) return;

    setState(() => _saving = true);
    final provider = context.read<ProfileProvider>();
    final settings = context.read<AppSettingsProvider>();
    final language = context.read<LanguageProvider>();
    final current = provider.profile;

    final profile = UserProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      dateOfBirth: _dateOfBirth,
      gender: _gender,
      state: _state,
      city: _cityController.text.trim(),
      languageCode: language.languageCode,
      needsAssistance: settings.readingAssistance,
      voiceGuidance: _voiceGuidance,
      bloodGroup: _bloodGroupController.text.trim(),
      allergies: _allergiesController.text.trim(),
      conditions: _conditionsController.text.trim(),
      emergencyContactName: _emergencyNameController.text.trim(),
      emergencyContactPhone: _emergencyPhoneController.text.trim(),
      createdAt: current?.createdAt,
    );

    final saved = await provider.save(profile);
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _saving = false;
        _saveError = AppLocalizations.of(context).t('profile_save_failed');
      });
      return;
    }

    await settings.setVoiceGuidance(_voiceGuidance);
    if (!mounted) return;
    setState(() => _saving = false);
    showAppSnackBar(context, AppLocalizations.of(context).t('profile_saved'));

    if (widget.isEdit || widget.popOnSave) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<ProfileProvider>();
    final content = widget.isEdit
        ? _buildContent(context, l10n, provider)
        : _buildOnboardingShell(context, l10n, provider);

    if (widget.isEdit) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('edit_profile'))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          child: ResponsiveBody(
            maxWidth: 680,
            padding: EdgeInsets.zero,
            child: content,
          ),
        ),
      );
    }
    return Scaffold(body: SafeArea(child: content));
  }

  Widget _buildOnboardingShell(
    BuildContext context,
    AppLocalizations l10n,
    ProfileProvider provider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppLogo(size: 40, showWordmark: true),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            await provider.skipSetup();
                          },
                    child: Text(l10n.t('skip')),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildContent(context, l10n, provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    ProfileProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(step: _step, isEdit: widget.isEdit),
        const SizedBox(height: 18),
        if (provider.storageError != null) ...[
          AppInfoBanner(
            icon: Icons.sd_card_alert_outlined,
            text: provider.storageError!,
            color: AppColors.warning,
            background: AppColors.warningSoft,
          ),
          const SizedBox(height: 14),
        ],
        AnimatedSwitcher(
          duration: AppMotion.base,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _step == 0
              ? _buildStepOne(context, l10n)
              : _buildStepTwo(context, l10n),
        ),
      ],
    );
  }

  Widget _buildStepOne(BuildContext context, AppLocalizations l10n) {
    return Form(
      key: _stepOneKey,
      child: Column(
        key: const ValueKey('profile-step-one'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.t('about_you_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 27,
                  letterSpacing: -0.7,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('about_you_body'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.t('first_name'),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return l10n.t('name_required');
                    if (text.length < 2) return l10n.t('name_too_short');
                    if (text.length > 60) return l10n.t('name_too_long');
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.t('last_name'),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length > 60) return l10n.t('name_too_long');
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _dobController,
            readOnly: true,
            onTap: _pickDateOfBirth,
            decoration: InputDecoration(
              labelText: l10n.t('date_of_birth'),
              prefixIcon: const Icon(Icons.cake_outlined),
              suffixIcon: const Icon(Icons.calendar_month_outlined),
            ),
            validator: (_) => _dateOfBirth == null ? l10n.t('dob_required') : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: InputDecoration(
              labelText: l10n.t('gender'),
              prefixIcon: const Icon(Icons.wc_outlined),
            ),
            items: [
              DropdownMenuItem(value: 'female', child: Text(l10n.t('gender_female'))),
              DropdownMenuItem(value: 'male', child: Text(l10n.t('gender_male'))),
              DropdownMenuItem(value: 'other', child: Text(l10n.t('gender_other'))),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _gender = value);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: InputDecoration(
              labelText: l10n.t('mobile_number'),
              prefixIcon: const Icon(Icons.phone_outlined),
              helperText: l10n.t('phone_privacy_note'),
            ),
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.isEmpty) return l10n.t('phone_required');
              if (digits.length < 10 || digits.length > 13) {
                return l10n.t('phone_invalid');
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: '${l10n.t('email')} (${l10n.t('optional')})',
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                return l10n.t('email_invalid');
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          AppInfoBanner(
            icon: Icons.lock_outline_rounded,
            text: l10n.t('local_profile_note'),
            color: AppColors.tealDark,
            background: AppColors.tealSoft,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _nextStep,
            child: Text(l10n.t('continue_label')),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTwo(BuildContext context, AppLocalizations l10n) {
    final stateData = findIndiaState(_state);
    final cityHints = stateData?.cities ?? const <String>[];
    return Form(
      key: _stepTwoKey,
      child: Column(
        key: const ValueKey('profile-step-two'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.t('location_and_care_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 27,
                  letterSpacing: -0.7,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('location_and_care_body'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          InkWell(
            onTap: _pickState,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.t('state_region'),
                prefixIcon: const Icon(Icons.map_outlined),
                suffixIcon: const Icon(Icons.search_rounded),
              ),
              child: Text(
                _state.isEmpty ? l10n.t('select_state') : _state,
                style: TextStyle(
                  color: _state.isEmpty ? AppColors.muted : AppColors.navy,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (_stateError && _state.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 6),
              child: Text(
                l10n.t('state_required'),
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.t('state_detect_helper'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _detectingLocation ? null : _detectState,
                icon: _detectingLocation
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded, size: 17),
                label: Text(l10n.t('detect_state')),
              ),
            ],
          ),
          if (_locationMessage != null) ...[
            const SizedBox(height: 8),
            AppInfoBanner(
              icon: _suggestedState != null
                  ? Icons.assistant_navigation
                  : Icons.info_outline_rounded,
              text: _locationMessage!,
              color: _suggestedState != null ? AppColors.tealDark : AppColors.slate,
              background:
                  _suggestedState != null ? AppColors.tealSoft : AppColors.neutralSoft,
              trailing: _suggestedState != null
                  ? TextButton(
                      onPressed: () => setState(() {
                        _state = _suggestedState!;
                        _stateError = false;
                      }),
                      child: Text(l10n.t('use_state')),
                    )
                  : (_locationMessage!.toLowerCase().contains('permission') ||
                          _locationMessage!.toLowerCase().contains('settings'))
                      ? TextButton(
                          onPressed: _openLocationSettings,
                          child: Text(l10n.t('settings')),
                        )
                      : null,
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _cityController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: '${l10n.t('city')} (${l10n.t('optional')})',
              prefixIcon: const Icon(Icons.location_city_outlined),
              helperText: l10n.t('city_optional_note'),
            ),
            validator: (value) {
              if ((value?.trim().length ?? 0) > 80) {
                return l10n.t('city_too_long');
              }
              return null;
            },
          ),
          if (cityHints.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final city in cityHints.take(5))
                  ActionChip(
                    label: Text(city),
                    onPressed: () => setState(() => _cityController.text = city),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: ExpansionTile(
              initiallyExpanded: _optionalExpanded,
              onExpansionChanged: (value) =>
                  setState(() => _optionalExpanded = value),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const AppIconBadge(
                icon: Icons.health_and_safety_outlined,
                size: 38,
                iconSize: 19,
              ),
              title: Text(
                l10n.t('optional_health_details'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
              ),
              subtitle: Text(
                l10n.t('optional_health_details_body'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _bloodGroups.contains(_bloodGroupController.text) &&
                          _bloodGroupController.text.isNotEmpty
                      ? _bloodGroupController.text
                      : null,
                  decoration: InputDecoration(labelText: l10n.t('blood_group')),
                  items: [
                    for (final group in _bloodGroups)
                      DropdownMenuItem(value: group, child: Text(group)),
                  ],
                  onChanged: (value) =>
                      _bloodGroupController.text = value ?? '',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _allergiesController,
                  maxLines: 2,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: l10n.t('allergies'),
                    hintText: l10n.t('allergies_hint'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _conditionsController,
                  maxLines: 2,
                  maxLength: 300,
                  decoration: InputDecoration(
                    labelText: l10n.t('conditions'),
                    hintText: l10n.t('conditions_hint'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.t('care_details_local_note'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.volume_up_outlined, color: AppColors.teal),
              title: Text(l10n.t('voice_guidance')),
              subtitle: Text(l10n.t('voice_guidance_body')),
              value: _voiceGuidance,
              onChanged: (value) => setState(() => _voiceGuidance = value),
            ),
          ),
          if (_saveError != null) ...[
            const SizedBox(height: 12),
            Text(
              _saveError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : () => setState(() => _step = 0),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(l10n.t('back')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.isEdit
                              ? l10n.t('save_changes')
                              : l10n.t('create_local_profile'),
                        ),
                ),
              ),
            ],
          ),
          if (!widget.isEdit && !widget.popOnSave) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => context.read<ProfileProvider>().skipSetup(),
              child: Text(l10n.t('explore_without_profile')),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int step;
  final bool isEdit;

  const _StepHeader({required this.step, required this.isEdit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isEdit) ...[
          Text(
            l10n.t('step_of').replaceAll('{current}', '${step + 1}').replaceAll('{total}', '2'),
            style: const TextStyle(
              color: AppColors.tealDark,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (step + 1) / 2,
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.teal),
            ),
          ),
        ] else
          AppEyebrow(l10n.t('edit_profile')),
      ],
    );
  }
}

/// Searchable state and union-territory selector. The full official list is
/// always available, and the search also matches aliases and major cities.
Future<String?> showStatePicker({
  required BuildContext context,
  String? selectedState,
  String? suggestedState,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _StatePickerSheet(
      selectedState: selectedState,
      suggestedState: suggestedState,
    ),
  );
}

class _StatePickerSheet extends StatefulWidget {
  final String? selectedState;
  final String? suggestedState;

  const _StatePickerSheet({this.selectedState, this.suggestedState});

  @override
  State<_StatePickerSheet> createState() => _StatePickerSheetState();
}

class _StatePickerSheetState extends State<_StatePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matches =
        indiaStates.where((state) => stateMatchesQuery(state, _query)).toList();
    final states = matches.where((state) => state.type == 'State').toList();
    final territories =
        matches.where((state) => state.type != 'State').toList();
    final suggested = widget.suggestedState == null
        ? null
        : findIndiaState(widget.suggestedState!);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: AppSheetHeader(
                      title: l10n.t('select_state'),
                      subtitle: l10n.t('select_state_body'),
                      icon: Icons.map_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.t('close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.t('search_state_hint'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.t('clear'),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? AppEmptyState(
                      icon: Icons.search_off_rounded,
                      title: l10n.t('state_no_results'),
                      message: l10n.t('state_no_results_body'),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      children: [
                        if (suggested != null && _query.isEmpty) ...[
                          _StateSectionLabel(label: l10n.t('suggested_state')),
                          _StateTile(
                            state: suggested,
                            selected: widget.selectedState == suggested.name,
                            suggested: true,
                            onTap: () => Navigator.of(context).pop(suggested.name),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (states.isNotEmpty) ...[
                          _StateSectionLabel(label: l10n.t('indian_states')),
                          for (final state in states)
                            _StateTile(
                              state: state,
                              selected: widget.selectedState == state.name,
                              onTap: () => Navigator.of(context).pop(state.name),
                            ),
                        ],
                        if (territories.isNotEmpty) ...[
                          _StateSectionLabel(label: l10n.t('union_territories')),
                          for (final state in territories)
                            _StateTile(
                              state: state,
                              selected: widget.selectedState == state.name,
                              onTap: () => Navigator.of(context).pop(state.name),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateSectionLabel extends StatelessWidget {
  final String label;

  const _StateSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _StateTile extends StatelessWidget {
  final IndiaState state;
  final bool selected;
  final bool suggested;
  final VoidCallback onTap;

  const _StateTile({
    required this.state,
    required this.selected,
    required this.onTap,
    this.suggested = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AppColors.tealSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  suggested ? Icons.my_location_rounded : Icons.location_on_outlined,
                  size: 19,
                  color: suggested ? AppColors.teal : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.type,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
