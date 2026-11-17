import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../health_campaigns_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/appointment_provider.dart';
import '../services/profile_provider.dart';
import '../services/report_service.dart';
import '../services/vaccine_service.dart';
import '../widgets/app_widgets.dart';
import 'nearby_screen.dart';
import 'report_history_screen.dart';
import 'report_screen.dart';
import 'vaccine_screen.dart';

class HealthHubScreen extends StatefulWidget {
  const HealthHubScreen({super.key});

  @override
  State<HealthHubScreen> createState() => _HealthHubScreenState();
}

class _HealthHubScreenState extends State<HealthHubScreen> {
  final VaccinationRepository _vaccinationRepository = VaccinationRepository();
  final ReportService _reportService = ReportService();

  int _vaccineRecords = 0;
  int _reports = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _vaccinationRepository.load(),
        _reportService.loadHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _vaccineRecords = results[0].length;
        _reports = results[1].length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = context.watch<ProfileProvider>().profile;
    final appointments = context.watch<AppointmentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('health')),
        actions: [
          IconButton(
            tooltip: l10n.t('refresh'),
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: ResponsiveBody(
            maxWidth: 880,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    boxShadow: AppShadows.brand,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.favorite_outline_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile == null
                                      ? l10n.t('health_hub_title')
                                      : l10n
                                          .t('health_hub_greeting')
                                          .replaceAll('{name}', profile.firstName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.t('health_hub_body'),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12.5,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _HubStat(
                            value: _loading ? '–' : '$_vaccineRecords',
                            label: l10n.t('vaccine_records_label'),
                          ),
                          _HubDivider(),
                          _HubStat(
                            value: appointments.scheduledCount.toString(),
                            label: l10n.t('upcoming_appointments'),
                          ),
                          _HubDivider(),
                          _HubStat(
                            value: _loading ? '–' : '$_reports',
                            label: l10n.t('reports'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (profile == null)
                  AppInfoBanner(
                    icon: Icons.person_outline_rounded,
                    text: l10n.t('health_hub_profile_prompt'),
                    color: AppColors.tealDark,
                    background: AppColors.tealSoft,
                  )
                else
                  AppInfoBanner(
                    icon: Icons.lock_outline_rounded,
                    text: l10n.t('health_hub_local_note'),
                    color: AppColors.tealDark,
                    background: AppColors.tealSoft,
                  ),
                const SizedBox(height: 22),
                AppSectionHeading(
                  title: l10n.t('records_and_reports'),
                  subtitle: l10n.t('records_and_reports_body'),
                ),
                _HubCard(
                  icon: Icons.vaccines_outlined,
                  color: AppColors.teal,
                  background: AppColors.tealSoft,
                  title: l10n.t('vaccine_records'),
                  subtitle: l10n
                      .t('vaccine_records_count')
                      .replaceAll('{count}', _loading ? '…' : '$_vaccineRecords'),
                  onTap: () => _open(const VaccineScreen()),
                ),
                const SizedBox(height: 10),
                _HubCard(
                  icon: Icons.report_problem_outlined,
                  color: AppColors.info,
                  background: AppColors.infoSoft,
                  title: l10n.t('report_a_health_concern'),
                  subtitle: l10n.t('report_a_health_concern_body'),
                  onTap: () => _open(const ReportScreen()),
                ),
                const SizedBox(height: 10),
                _HubCard(
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.warning,
                  background: AppColors.warningSoft,
                  title: l10n.t('my_reports'),
                  subtitle: l10n
                      .t('reports_saved_count')
                      .replaceAll('{count}', _loading ? '…' : '$_reports'),
                  onTap: () => _open(const ReportHistoryScreen()),
                ),
                const SizedBox(height: 22),
                AppSectionHeading(
                  title: l10n.t('explore_care'),
                  subtitle: l10n.t('explore_care_body'),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = [
                      _HubCard(
                        icon: Icons.near_me_outlined,
                        color: AppColors.teal,
                        background: AppColors.tealSoft,
                        title: l10n.t('nearby_care'),
                        subtitle: l10n.t('nearby_care_body'),
                        onTap: () => _open(const NearbyScreen()),
                      ),
                      _HubCard(
                        icon: Icons.campaign_outlined,
                        color: AppColors.info,
                        background: AppColors.infoSoft,
                        title: l10n.t('health_campaigns'),
                        subtitle: l10n.t('health_campaigns_body'),
                        onTap: () => _open(const HealthCampaignsScreen()),
                      ),
                    ];
                    if (constraints.maxWidth < 640) {
                      return Column(
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            cards[i],
                            if (i != cards.length - 1) const SizedBox(height: 10),
                          ],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                AppSectionHeading(title: l10n.t('everyday_health')),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _TipRow(
                        icon: Icons.wash_outlined,
                        text: l10n.t('more_tip_1'),
                      ),
                      const Divider(height: 22),
                      _TipRow(
                        icon: Icons.restaurant_outlined,
                        text: l10n.t('more_tip_2'),
                      ),
                      const Divider(height: 22),
                      _TipRow(
                        icon: Icons.directions_walk_rounded,
                        text: l10n.t('more_tip_3'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.t('health_disclaimer_short'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HubStat extends StatelessWidget {
  final String value;
  final String label;

  const _HubStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _HubDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.18),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AppIconBadge(
            icon: icon,
            color: color,
            background: background,
            size: 46,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.tealSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: AppColors.tealDark),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.navy,
            ),
          ),
        ),
      ],
    );
  }
}
