import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../language_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/app_lock_provider.dart';
import '../services/app_settings_provider.dart';
import '../services/profile_provider.dart';
import '../services/sos_service.dart';
import '../widgets/app_widgets.dart';
import 'app_lock_settings_screen.dart';
import 'help_about_screen.dart';
import 'privacy_settings_screen.dart';
import 'profile_setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _languages = [
    ('en', 'English'),
    ('hi', 'हिन्दी'),
    ('mr', 'मराठी'),
    ('bn', 'বাংলা'),
    ('gu', 'ગુજરાતી'),
    ('ta', 'தமிழ்'),
  ];

  Future<void> _changeLanguage(BuildContext context, String code) async {
    final l10n = AppLocalizations.of(context);
    final language = context.read<LanguageProvider>();
    final profileProvider = context.read<ProfileProvider>();
    await language.setLanguage(code);
    final profile = profileProvider.profile;
    if (profile != null && profile.languageCode != code) {
      final saved =
          await profileProvider.save(profile.copyWith(languageCode: code));
      if (!context.mounted) return;
      if (!saved) {
        showAppSnackBar(context, l10n.t('auth_generic_error'), isError: true);
      }
    }
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final current = context.read<LanguageProvider>().languageCode;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSheetHeader(
                title: l10n.t('change_language'),
                subtitle: l10n.t('app_language_body'),
                icon: Icons.translate_rounded,
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final item in _languages)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.$2),
                          trailing: current == item.$1
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.teal,
                                )
                              : null,
                          onTap: () =>
                              Navigator.of(sheetContext).pop(item.$1),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t('language_fallback_note'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    await _changeLanguage(context, selected);
  }

  Future<void> _editEmergencyNumber(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final settings = context.read<AppSettingsProvider>();
    final controller = TextEditingController(text: settings.emergencyNumber);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('emergency_number')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.t('emergency_number'),
            hintText: '112',
            prefixIcon: const Icon(Icons.call_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.t('save')),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    final saved = await settings.setEmergencyNumber(value);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      saved
          ? l10n.t('emergency_number_saved')
          : l10n.t('emergency_number_invalid'),
      isError: !saved,
    );
  }

  Future<void> _callEmergency(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final number = context.read<AppSettingsProvider>().emergencyNumber;
    try {
      await SOSService.openDialer(number);
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, l10n.t('dialer_unavailable'), isError: true);
      }
    }
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<AppSettingsProvider>();
    final language = context.watch<LanguageProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final lock = context.watch<AppLockProvider>();
    final profile = profileProvider.profile;
    final languageName = _languages
        .firstWhere(
          (item) => item.$1 == language.languageCode,
          orElse: () => ('en', 'English'),
        )
        .$2;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: ResponsiveBody(
          maxWidth: 760,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  onTap: () => _open(
                    context,
                    const ProfileSetupScreen(isEdit: true),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.tealSoft,
                          child: Text(
                            profile?.firstName.trim().isNotEmpty == true
                                ? profile!.firstName
                                    .trim()
                                    .substring(0, 1)
                                    .toUpperCase()
                                : 'H',
                            style: const TextStyle(
                              color: AppColors.tealDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.displayName ?? l10n.t('profile'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.t('local_storage_short'),
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.edit_outlined,
                          size: 19,
                          color: AppColors.slate,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: l10n.t('settings_account')),
              AppListPanel(
                children: [
                  AppNavTile(
                    icon: Icons.translate_rounded,
                    title: l10n.t('app_language'),
                    subtitle: languageName,
                    onTap: () => _pickLanguage(context),
                  ),
                  AppNavTile(
                    icon: Icons.person_outline_rounded,
                    title: l10n.t('personal_information'),
                    subtitle: l10n.t('profile_personal_body'),
                    onTap: () => _open(
                      context,
                      const ProfileSetupScreen(isEdit: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: l10n.t('settings_privacy_security')),
              AppListPanel(
                children: [
                  AppNavTile(
                    icon: lock.enabled
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    title: l10n.t('settings_app_lock'),
                    subtitle: lock.enabled
                        ? l10n.t('settings_app_lock_on')
                        : l10n.t('settings_app_lock_off'),
                    onTap: () =>
                        _open(context, const AppLockSettingsScreen()),
                  ),
                  AppNavTile(
                    icon: Icons.shield_outlined,
                    title: l10n.t('privacy_settings'),
                    subtitle: l10n.t('privacy_body'),
                    onTap: () =>
                        _open(context, const PrivacySettingsScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: l10n.t('emergency')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.call_outlined,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.t('emergency_number'),
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              settings.emergencyNumber,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.t('edit'),
                        onPressed: () => _editEmergencyNumber(context),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: l10n.t('call'),
                        onPressed: () => _callEmergency(context),
                        icon: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l10n.t('settings_emergency_body'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 11.5, height: 1.45),
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: l10n.t('accessibility')),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.text_fields_rounded,
                        color: AppColors.teal,
                      ),
                      title: Text(l10n.t('reading_assistance')),
                      subtitle: Text(l10n.t('reading_assistance_body')),
                      value: settings.readingAssistance,
                      onChanged: settings.setReadingAssistance,
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.format_size_rounded,
                                color: AppColors.teal,
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  l10n.t('text_size'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.navy,
                                      ),
                                ),
                              ),
                              Text(
                                '${(settings.textScale * 100).round()}%',
                                style: const TextStyle(
                                  color: AppColors.tealDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: settings.textScale.clamp(1.0, 1.5),
                            min: 1.0,
                            max: 1.5,
                            divisions: 5,
                            label:
                                '${(settings.textScale * 100).round()}%',
                            onChanged: settings.setTextScale,
                          ),
                          Text(
                            l10n.t('text_size_preview'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 15 * settings.textScale,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.volume_up_outlined,
                        color: AppColors.teal,
                      ),
                      title: Text(l10n.t('voice_guidance')),
                      subtitle: Text(l10n.t('voice_guidance_body')),
                      value: settings.voiceGuidance,
                      onChanged: settings.setVoiceGuidance,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: l10n.t('settings_notifications_note')),
              AppInfoBanner(
                icon: Icons.notifications_off_outlined,
                text: l10n.t('notifications_not_supported'),
                color: AppColors.slate,
                background: AppColors.neutralSoft,
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: l10n.t('settings_help')),
              AppListPanel(
                children: [
                  AppNavTile(
                    icon: Icons.help_outline_rounded,
                    title: l10n.t('help_support'),
                    subtitle: l10n.t('help_support_body'),
                    onTap: () => _open(context, const HelpAboutScreen()),
                  ),
                  AppNavTile(
                    icon: Icons.info_outline_rounded,
                    title: l10n.t('about_healthmate'),
                    subtitle: l10n.t('settings_version')
                        .replaceAll('{version}', '1.0.0'),
                    onTap: () => _open(context, const HelpAboutScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                l10n.t('settings_local_first_note'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 11.5, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.slate,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
      ),
    );
  }
}
