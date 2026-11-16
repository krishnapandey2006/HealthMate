import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../language_provider.dart';
import '../services/app_lock_provider.dart';
import '../services/app_settings_provider.dart';
import '../services/appointment_provider.dart';
import '../services/news_service.dart';
import '../services/profile_provider.dart';
import '../widgets/app_widgets.dart';

/// Explains local storage, clears the public news cache and can erase every
/// piece of HealthMate data stored on this device.
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _deleting = false;

  Future<void> _clearNews() async {
    final l10n = AppLocalizations.of(context);
    final cleared = await NewsService().clearCache();
    if (!mounted) return;
    showAppSnackBar(
      context,
      cleared ? l10n.t('news_cache_cleared') : l10n.t('news_cache_clear_failed'),
      isError: !cleared,
    );
  }

  Future<void> _openSystemSettings() async {
    final l10n = AppLocalizations.of(context);
    try {
      final opened = await Geolocator.openAppSettings();
      if (!opened && mounted) {
        showAppSnackBar(
          context,
          l10n.t('privacy_app_settings_failed'),
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          l10n.t('privacy_app_settings_failed'),
          isError: true,
        );
      }
    }
  }

  Future<void> _deleteEverything() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('delete_all_data')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('delete_all_data_body')),
            const SizedBox(height: 10),
            Text(
              l10n.t('privacy_delete_warning'),
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(l10n.t('delete_all_data_confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final profileProvider = context.read<ProfileProvider>();
    final appointmentProvider = context.read<AppointmentProvider>();
    final appLockProvider = context.read<AppLockProvider>();
    final settingsProvider = context.read<AppSettingsProvider>();
    final languageProvider = context.read<LanguageProvider>();
    var cacheCleared = false;
    try {
      cacheCleared = await NewsService().clearCache();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await profileProvider.clearLocalProfile();
      await appointmentProvider.resetToDefaults();
      await appLockProvider.resetToDefaults();
      await settingsProvider.resetToDefaults();
      await languageProvider.resetToDefault();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showAppSnackBar(context, l10n.t('data_erase_failed'), isError: true);
      return;
    }
    if (!mounted) return;
    setState(() => _deleting = false);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          cacheCleared
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded,
          color: cacheCleared ? AppColors.success : AppColors.warning,
        ),
        title: Text(l10n.t('all_data_deleted')),
        content: Text(
          cacheCleared
              ? l10n.t('privacy_erase_success_body')
              : l10n.t('data_erase_partial'),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.t('ok')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings_privacy_security'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: ResponsiveBody(
          maxWidth: 760,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.softGradient,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppIconBadge(
                      icon: Icons.shield_outlined,
                      color: AppColors.tealDark,
                      background: AppColors.tealSoft,
                      size: 50,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t('local_data_title'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            l10n.t('local_data_body'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _SectionLabel(label: l10n.t('privacy_location_title')),
              AppListPanel(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.t('privacy_location_body'),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(height: 1.5),
                    ),
                  ),
                  AppNavTile(
                    icon: Icons.settings_outlined,
                    title: l10n.t('privacy_open_system_settings'),
                    onTap: _openSystemSettings,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SectionLabel(label: l10n.t('privacy_stored_title')),
              AppListPanel(
                children: [
                  _StorageRow(
                    icon: Icons.person_outline_rounded,
                    text: l10n.t('personal_information'),
                  ),
                  _StorageRow(
                    icon: Icons.calendar_month_outlined,
                    text: l10n.t('appointments'),
                  ),
                  _StorageRow(
                    icon: Icons.vaccines_outlined,
                    text: l10n.t('vaccination'),
                  ),
                  _StorageRow(
                    icon: Icons.receipt_long_outlined,
                    text: l10n.t('reports'),
                  ),
                  _StorageRow(
                    icon: Icons.newspaper_outlined,
                    text: l10n.t('clear_news_cache'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                l10n.t('privacy_stored_body'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(height: 1.5, fontSize: 11.5),
              ),
              const SizedBox(height: 18),
              AppListPanel(
                children: [
                  AppNavTile(
                    icon: Icons.newspaper_outlined,
                    title: l10n.t('clear_news_cache'),
                    subtitle: l10n.t('clear_news_cache_body'),
                    onTap: _deleting ? null : _clearNews,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionLabel(label: l10n.t('privacy_danger_zone')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.t('delete_all_data'),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.t('delete_all_data_body'),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _deleting ? null : _deleteEverything,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                        ),
                        icon: _deleting
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline_rounded, size: 18),
                        label: Text(
                          _deleting
                              ? l10n.t('deleting_data')
                              : l10n.t('delete_all_data'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.t('profile_delete_note'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StorageRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.slate),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            size: 15,
            color: AppColors.teal,
          ),
        ],
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
