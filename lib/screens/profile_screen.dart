import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../services/appointment_provider.dart';
import '../services/profile_provider.dart';
import '../services/report_service.dart';
import '../services/vaccine_service.dart';
import '../widgets/app_widgets.dart';
import 'main_scaffold.dart';
import 'profile_setup_screen.dart';
import 'report_history_screen.dart';
import 'settings_screen.dart';
import 'vaccine_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int? _vaccineCount;
  int? _reportCount;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final results = await Future.wait([
        VaccinationRepository().load(),
        ReportService().loadHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _vaccineCount = results[0].length;
        _reportCount = results[1].length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vaccineCount ??= 0;
        _reportCount ??= 0;
      });
    }
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(isEdit: true),
      ),
    );
    if (mounted) _loadCounts();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) _loadCounts();
  }

  Future<void> _refresh() async {
    await context.read<ProfileProvider>().refresh();
    await _loadCounts();
  }

  Future<void> _copyEmergency(UserProfile profile) async {
    final l10n = AppLocalizations.of(context);
    final lines = <String>[
      profile.displayName,
      if (profile.age != null)
        '${l10n.t('age_from_dob')}: ${profile.age}',
      if (profile.bloodGroup.isNotEmpty)
        '${l10n.t('blood_group')}: ${profile.bloodGroup}',
      if (profile.allergies.isNotEmpty)
        '${l10n.t('allergies')}: ${profile.allergies}',
      if (profile.conditions.isNotEmpty)
        '${l10n.t('conditions')}: ${profile.conditions}',
      if (profile.emergencyContactName.isNotEmpty ||
          profile.emergencyContactPhone.isNotEmpty)
        '${l10n.t('emergency_contact')}: '
            '${profile.emergencyContactName}'
            '${profile.emergencyContactPhone.isNotEmpty ? ' · ${profile.emergencyContactPhone}' : ''}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    showAppSnackBar(context, l10n.t('share_text_copied'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileProvider = context.watch<ProfileProvider>();
    final appointments = context.watch<AppointmentProvider>();
    final profile = profileProvider.profile;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('profile'))),
        body: AppEmptyState(
          icon: Icons.person_outline_rounded,
          title: l10n.t('profile_missing_title'),
          message: l10n.t('profile_missing_body'),
          actionLabel: l10n.t('complete_profile'),
          onAction: _edit,
        ),
      );
    }

    final hasHealthDetails = profile.bloodGroup.isNotEmpty ||
        profile.allergies.isNotEmpty ||
        profile.conditions.isNotEmpty;
    final hasEmergency = profile.emergencyContactName.isNotEmpty ||
        profile.emergencyContactPhone.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('profile')),
        actions: [
          IconButton(
            tooltip: l10n.t('settings_title'),
            onPressed: () =>
                _open(const SettingsScreen()),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: l10n.t('edit_profile'),
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: ResponsiveBody(
            maxWidth: 820,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHero(
                  profile: profile,
                  appointmentCount: appointments.scheduledCount,
                  vaccineCount: _vaccineCount,
                  reportCount: _reportCount,
                  onAppointments: () =>
                      MainTabScope.maybeOf(context)?.selectTab(1),
                  onVaccines: () => _open(const VaccineScreen()),
                  onReports: () => _open(const ReportHistoryScreen()),
                ),
                if (profileProvider.storageError != null) ...[
                  const SizedBox(height: 12),
                  AppInfoBanner(
                    icon: Icons.error_outline_rounded,
                    text: profileProvider.storageError!,
                    color: AppColors.danger,
                    background: AppColors.dangerSoft,
                  ),
                ],
                const SizedBox(height: 16),
                _SectionHeader(
                  title: l10n.t('personal_information'),
                  icon: Icons.badge_outlined,
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.t('profile_personal_body'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          label: l10n.t('phone'),
                          value: profile.phone.isEmpty
                              ? l10n.t('not_set')
                              : profile.phone,
                        ),
                        _InfoRow(
                          icon: Icons.mail_outline_rounded,
                          label: l10n.t('email'),
                          value: profile.email.isEmpty
                              ? l10n.t('not_set')
                              : profile.email,
                        ),
                        _InfoRow(
                          icon: Icons.cake_outlined,
                          label: l10n.t('date_of_birth'),
                          value: profile.dateOfBirth == null
                              ? l10n.t('not_set')
                              : formatDateTime(profile.dateOfBirth!),
                        ),
                        _InfoRow(
                          icon: Icons.hourglass_empty_rounded,
                          label: l10n.t('age_from_dob'),
                          value: profile.age == null
                              ? l10n.t('age_unknown')
                              : l10n
                                  .t('age_years')
                                  .replaceAll('{years}', '${profile.age}'),
                        ),
                        _InfoRow(
                          icon: Icons.wc_outlined,
                          label: l10n.t('gender'),
                          value: _genderLabel(l10n, profile.gender),
                        ),
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          label: l10n.t('state_region'),
                          value: profile.state.isEmpty
                              ? l10n.t('not_set')
                              : profile.state,
                        ),
                        _InfoRow(
                          icon: Icons.location_city_outlined,
                          label: l10n.t('city'),
                          value: profile.city.isEmpty
                              ? l10n.t('not_set')
                              : profile.city,
                        ),
                        _InfoRow(
                          icon: Icons.translate_rounded,
                          label: l10n.t('preferred_language'),
                          value: _languageLabel(profile.languageCode),
                        ),
                        Text(
                          l10n.t('age_derived_note'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11.5),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: l10n.t('profile_health_title'),
                  icon: Icons.health_and_safety_outlined,
                  actionLabel: hasHealthDetails
                      ? l10n.t('edit')
                      : l10n.t('profile_add_health_details'),
                  onAction: _edit,
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: hasHealthDetails
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (profile.bloodGroup.isNotEmpty)
                                _InfoRow(
                                  icon: Icons.bloodtype_outlined,
                                  label: l10n.t('blood_group'),
                                  value: profile.bloodGroup,
                                ),
                              if (profile.allergies.isNotEmpty)
                                _InfoRow(
                                  icon: Icons.warning_amber_rounded,
                                  label: l10n.t('allergies'),
                                  value: profile.allergies,
                                ),
                              if (profile.conditions.isNotEmpty)
                                _InfoRow(
                                  icon: Icons.monitor_heart_outlined,
                                  label: l10n.t('conditions'),
                                  value: profile.conditions,
                                ),
                              Text(
                                l10n.t('profile_health_body'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontSize: 11.5),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.t('profile_no_health_details'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                l10n.t('profile_health_empty_body'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _edit,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(
                                  l10n.t('profile_add_health_details'),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: l10n.t('profile_emergency_card'),
                  icon: Icons.emergency_outlined,
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: hasEmergency
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  AppIconBadge(
                                    icon: Icons.call_outlined,
                                    color: AppColors.danger,
                                    background: AppColors.dangerSoft,
                                    size: 42,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile.emergencyContactName.isEmpty
                                              ? l10n.t('emergency_contact')
                                              : profile
                                                  .emergencyContactName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        if (profile.emergencyContactPhone
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            profile.emergencyContactPhone,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.t('profile_emergency_copy_note'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _copyEmergency(profile),
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        l10n.t('profile_emergency_copy'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    tooltip: l10n.t('edit'),
                                    onPressed: _edit,
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.t('profile_emergency_empty'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                l10n.t('profile_emergency_empty_body'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _edit,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(l10n.t('emergency_contact')),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: l10n.t('records_and_reports'),
                  icon: Icons.folder_open_outlined,
                ),
                AppListPanel(
                  children: [
                    AppNavTile(
                      icon: Icons.calendar_month_outlined,
                      title: l10n.t('appointments'),
                      subtitle: l10n.t('scheduled_count').replaceAll(
                            '{count}',
                            '${appointments.scheduledCount}',
                          ),
                      onTap: () =>
                          MainTabScope.maybeOf(context)?.selectTab(1),
                    ),
                    AppNavTile(
                      icon: Icons.vaccines_outlined,
                      title: l10n.t('vaccine_records'),
                      subtitle: l10n.t('vaccine_records_count').replaceAll(
                            '{count}',
                            '${_vaccineCount ?? '—'}',
                          ),
                      onTap: () => _open(const VaccineScreen()),
                    ),
                    AppNavTile(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.t('reports'),
                      subtitle: l10n.t('reports_saved_count').replaceAll(
                            '{count}',
                            '${_reportCount ?? '—'}',
                          ),
                      onTap: () => _open(const ReportHistoryScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppInfoBanner(
                  icon: Icons.smartphone_outlined,
                  text: l10n.t('profile_local_note'),
                  color: AppColors.tealDark,
                  background: AppColors.tealSoft,
                ),
                const SizedBox(height: 12),
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
      ),
    );
  }

  String _genderLabel(AppLocalizations l10n, String gender) {
    switch (gender) {
      case 'male':
        return l10n.t('gender_male');
      case 'other':
        return l10n.t('gender_other');
      default:
        return l10n.t('gender_female');
    }
  }

  String _languageLabel(String code) {
    const names = {
      'en': 'English',
      'hi': 'हिन्दी',
      'mr': 'मराठी',
      'bn': 'বাংলা',
      'gu': 'ગુજરાતી',
      'ta': 'தமிழ்',
    };
    return names[code] ?? code;
  }
}

class _ProfileHero extends StatelessWidget {
  final UserProfile profile;
  final int appointmentCount;
  final int? vaccineCount;
  final int? reportCount;
  final VoidCallback onAppointments;
  final VoidCallback onVaccines;
  final VoidCallback onReports;

  const _ProfileHero({
    required this.profile,
    required this.appointmentCount,
    required this.vaccineCount,
    required this.reportCount,
    required this.onAppointments,
    required this.onVaccines,
    required this.onReports,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final initial = profile.firstName.trim().isEmpty
        ? 'H'
        : profile.firstName.trim().substring(0, 1).toUpperCase();
    final details = <String>[
      if (profile.age != null)
        l10n.t('age_years').replaceAll('{years}', '${profile.age}'),
      if (profile.city.isNotEmpty) profile.city,
      if (profile.state.isNotEmpty) profile.state,
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.brand,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.17),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details.isEmpty
                          ? l10n.t('profile_personal_body')
                          : details.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.smartphone_outlined,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.t('device_only'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Row(
              children: [
                _HeroStat(
                  value: '$appointmentCount',
                  label: l10n.t('appointments'),
                  icon: Icons.calendar_month_outlined,
                  onTap: onAppointments,
                ),
                _HeroDivider(),
                _HeroStat(
                  value: '${vaccineCount ?? '—'}',
                  label: l10n.t('vaccine_records_label'),
                  icon: Icons.vaccines_outlined,
                  onTap: onVaccines,
                ),
                _HeroDivider(),
                _HeroStat(
                  value: '${reportCount ?? '—'}',
                  label: l10n.t('reports'),
                  icon: Icons.receipt_long_outlined,
                  onTap: onReports,
                ),
              ],
            ),
          ),
          if (profile.updatedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              l10n.t('profile_last_updated').replaceAll(
                    '{date}',
                    formatDateTime(profile.updatedAt!),
                  ),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HeroStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            children: [
              Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: 0.18),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.slate),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.slate,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.slate),
          const SizedBox(width: 10),
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
