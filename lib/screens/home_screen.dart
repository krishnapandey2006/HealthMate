import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../health_campaigns_screen.dart';
import '../health_news_screen.dart';
import '../l10n/app_localizations.dart';
import '../language_provider.dart';
import '../models/appointment.dart';
import '../models/article.dart';
import '../models/health_campaign.dart';
import '../services/app_settings_provider.dart';
import '../services/appointment_provider.dart';
import '../services/campaign_service.dart';
import '../services/news_service.dart';
import '../services/profile_provider.dart';
import '../services/sos_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/health_calendar.dart';
import 'appointment_detail_screen.dart';
import 'main_scaffold.dart';
import 'nearby_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NewsService _newsService = NewsService();
  final CampaignService _campaignService = CampaignService();

  List<Article> _articles = const [];
  List<CampaignView> _campaigns = const [];
  bool _loadingNews = true;
  bool _loadingCampaigns = true;
  String? _newsError;
  String? _campaignError;
  String _languageCode = 'en';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = context.watch<LanguageProvider>().languageCode;
    if (code != _languageCode) {
      _languageCode = code;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAll();
      });
    }
  }

  @override
  void dispose() {
    _newsService.dispose();
    _campaignService.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadNews(), _loadCampaigns()]);
  }

  Future<void> _loadNews({bool refresh = false}) async {
    if (mounted) {
      setState(() {
        _loadingNews = true;
        _newsError = null;
      });
    }
    final result = await _newsService.fetchPage(
      category: 'all',
      lang: _languageCode,
      // Share one 12-article cache entry with the full News tab. The dashboard
      // only renders three of them, so opening News later is instant instead of
      // issuing a second overlapping request.
      page: 1,
      limit: 12,
      forceRefresh: refresh,
    );
    if (!mounted) return;
    setState(() {
      _loadingNews = false;
      _articles = result.articles.take(3).toList();
      _newsError = result.isError && result.articles.isEmpty
          ? result.error?.message
          : result.warning;
    });
  }

  Future<void> _loadCampaigns({bool refresh = false}) async {
    if (mounted) setState(() => _loadingCampaigns = true);
    final result = await _campaignService.load(forceRefresh: refresh);
    if (!mounted) return;
    setState(() {
      _loadingCampaigns = false;
      _campaigns = _campaignService.upcoming(DateTime.now()).take(2).toList();
      _campaignError = result.error ?? result.warning;
    });
  }

  Future<void> _refresh() async {
    await _loadAll();
  }

  void _selectTab(int index) {
    final scope = MainTabScope.maybeOf(context);
    if (scope != null) {
      scope.selectTab(index);
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _showEmergency() {
    final l10n = AppLocalizations.of(context);
    final settings = context.read<AppSettingsProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSheetHeader(
                  title: l10n.t('emergency_help'),
                  subtitle: l10n.t('emergency_help_body'),
                  icon: Icons.emergency_outlined,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: () =>
                      _call(sheetContext, settings.emergencyNumber),
                  icon: const Icon(Icons.call_rounded),
                  label: Text(
                    '${l10n.t('call_emergency')} · ${settings.emergencyNumber}',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _call(sheetContext, '108'),
                  icon: const Icon(Icons.local_hospital_outlined),
                  label: Text(l10n.t('call_ambulance_108')),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await SOSService.sendSms(
                        settings.emergencyNumber,
                        l10n.t('sos_message'),
                      );
                    } catch (_) {
                      if (sheetContext.mounted) {
                        showAppSnackBar(
                          sheetContext,
                          l10n.t('sms_unavailable'),
                          isError: true,
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(l10n.t('send_sos_sms')),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.t('emergency_disclaimer'),
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _call(BuildContext context, String number) async {
    try {
      await SOSService.openDialer(number);
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context).t('dialer_unavailable'),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileProvider = context.watch<ProfileProvider>();
    final appointmentProvider = context.watch<AppointmentProvider>();
    final profile = profileProvider.profile;
    final firstName = profile?.firstName.trim() ?? '';
    final now = DateTime.now();
    final timeGreeting = now.hour < 12
        ? l10n.t('good_morning')
        : now.hour < 17
            ? l10n.t('good_afternoon')
            : l10n.t('good_evening');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.mintBackground,
              titleSpacing: 16,
              title: const AppLogo(size: 32, showWordmark: true),
              actions: [
                IconButton(
                  tooltip: l10n.t('settings_title'),
                  onPressed: () => _open(const SettingsScreen()),
                  icon: const Icon(Icons.settings_outlined),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14, left: 2),
                  child: GestureDetector(
                    onTap: () => _selectTab(4),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.tealSoft,
                      child: Text(
                        firstName.isEmpty
                            ? 'H'
                            : firstName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.tealDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: ResponsiveBody(
                maxWidth: 920,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$timeGreeting${firstName.isEmpty ? '' : ', $firstName'}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.tealDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                l10n.t('home_hero_title'),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontSize: 27,
                                      letterSpacing: -0.7,
                                      height: 1.15,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatFriendlyDate(now, includeWeekday: true)
                              .replaceAll(', ${now.year}', ''),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 11.5,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _NextVisitCard(
                      next: appointmentProvider.nextAppointment,
                      onView: appointmentProvider.nextAppointment == null
                          ? () => _selectTab(1)
                          : () {
                              final next = appointmentProvider.nextAppointment;
                              if (next != null) {
                                _open(AppointmentDetailScreen(
                                    appointmentId: next.id));
                              }
                            },
                      onAdd: () => _selectTab(1),
                    ),
                    const SizedBox(height: 12),
                    _EmergencyStrip(
                      number:
                          context.watch<AppSettingsProvider>().emergencyNumber,
                      onTap: _showEmergency,
                    ),
                    const SizedBox(height: 22),
                    AppSectionHeading(
                      title: l10n.t('quick_actions'),
                      subtitle: l10n.t('home_quick_actions_body'),
                    ),
                    _QuickGrid(
                      onNearby: () => _open(const NearbyScreen()),
                      onAppointments: () => _selectTab(1),
                      onHealth: () => _selectTab(2),
                      onReport: () => _open(const ReportScreen()),
                    ),
                    const SizedBox(height: 24),
                    AppSectionHeading(
                      title: l10n.t('latest_health_news'),
                      actionLabel: l10n.t('see_all'),
                      onAction: () => _selectTab(3),
                    ),
                    _buildNews(l10n),
                    const SizedBox(height: 24),
                    AppSectionHeading(
                      title: l10n.t('health_campaigns'),
                      actionLabel: l10n.t('see_all'),
                      onAction: () => _open(const HealthCampaignsScreen()),
                    ),
                    _buildCampaigns(l10n),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const AppIconBadge(
                            icon: Icons.smartphone_outlined,
                            size: 42,
                            iconSize: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profileProvider.isComplete
                                      ? l10n.t('profile_complete')
                                      : l10n.t('profile_incomplete'),
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.t('home_local_footer'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _selectTab(4),
                            child: Text(l10n.t('view_profile')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.t('home_disclaimer'),
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
          ],
        ),
      ),
    );
  }

  Widget _buildNews(AppLocalizations l10n) {
    if (_loadingNews) {
      return const Column(
        children: [
          ArticleSkeleton(),
          SizedBox(height: 10),
          ArticleSkeleton(),
        ],
      );
    }
    if (_articles.isEmpty) {
      return AppInfoBanner(
        icon: Icons.newspaper_outlined,
        text: _newsError ?? l10n.t('no_updates'),
        color: _newsError == null ? AppColors.slate : AppColors.warning,
        background:
            _newsError == null ? AppColors.neutralSoft : AppColors.warningSoft,
        trailing: TextButton(
          onPressed: () => _loadNews(refresh: true),
          child: Text(l10n.t('retry')),
        ),
      );
    }
    return Column(
      children: [
        if (_newsError != null) ...[
          AppInfoBanner(
            icon: Icons.info_outline_rounded,
            text: _newsError!,
            color: AppColors.warning,
            background: AppColors.warningSoft,
          ),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < _articles.length; i++) ...[
          _NewsPreview(
            article: _articles[i],
            featured: i == 0,
            onTap: () => _open(HealthNewsScreen(initialArticle: _articles[i])),
          ),
          if (i != _articles.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildCampaigns(AppLocalizations l10n) {
    if (_loadingCampaigns) {
      return const ArticleSkeleton();
    }
    if (_campaigns.isEmpty) {
      return AppInfoBanner(
        icon: Icons.event_busy_outlined,
        text: _campaignError ?? l10n.t('no_upcoming_campaigns'),
        color: AppColors.slate,
        background: AppColors.neutralSoft,
        trailing: TextButton(
          onPressed: () => _loadCampaigns(refresh: true),
          child: Text(l10n.t('retry')),
        ),
      );
    }
    return AppListPanel(
      children: [
        for (var i = 0; i < _campaigns.length; i++)
          _CampaignPreview(
            view: _campaigns[i],
            onTap: () => _open(const HealthCampaignsScreen()),
          ),
      ],
    );
  }
}

class _NextVisitCard extends StatelessWidget {
  final Appointment? next;
  final VoidCallback onView;
  final VoidCallback onAdd;

  const _NextVisitCard({
    required this.next,
    required this.onView,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appointment = next;
    return Container(
      padding: const EdgeInsets.all(20),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.favorite_outline_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  appointment == null
                      ? l10n.t('home_no_visits_title')
                      : l10n.t('home_next_visit'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (appointment != null)
                AppStatusChip(
                  label: l10n.t('upcoming'),
                  color: AppColors.tealDeep,
                  background: Colors.white,
                  icon: Icons.event_available_outlined,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (appointment == null) ...[
            Text(
              l10n.t('home_no_visits_body'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.tealDeep,
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.t('add_appointment')),
            ),
          ] else ...[
            Text(
              appointment.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: Colors.white.withValues(alpha: 0.82),
                  size: 16,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${formatFriendlyDate(appointment.scheduledAt, includeWeekday: true)} · ${formatClockTime(TimeOfDay.fromDateTime(appointment.scheduledAt))}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
            if (appointment.provider.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    color: Colors.white.withValues(alpha: 0.82),
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      [appointment.provider, appointment.location]
                          .where((value) => value.isNotEmpty)
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 13),
            OutlinedButton.icon(
              onPressed: onView,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(l10n.t('view_details')),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmergencyStrip extends StatelessWidget {
  final String number;
  final VoidCallback onTap;

  const _EmergencyStrip({required this.number, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.18)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              const Icon(Icons.emergency_outlined,
                  color: AppColors.danger, size: 21),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('emergency_help'),
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.t('emergency_help_short'),
                      style: TextStyle(
                        color: AppColors.danger.withValues(alpha: 0.82),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                number,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.danger),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  final VoidCallback onNearby;
  final VoidCallback onAppointments;
  final VoidCallback onHealth;
  final VoidCallback onReport;

  const _QuickGrid({
    required this.onNearby,
    required this.onAppointments,
    required this.onHealth,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      _QuickItem(
        icon: Icons.near_me_outlined,
        title: l10n.t('nearby_care'),
        subtitle: l10n.t('home_quick_nearby'),
        color: AppColors.teal,
        background: AppColors.tealSoft,
        onTap: onNearby,
      ),
      _QuickItem(
        icon: Icons.calendar_month_outlined,
        title: l10n.t('appointments'),
        subtitle: l10n.t('home_quick_visits'),
        color: AppColors.info,
        background: AppColors.infoSoft,
        onTap: onAppointments,
      ),
      _QuickItem(
        icon: Icons.health_and_safety_outlined,
        title: l10n.t('health_records'),
        subtitle: l10n.t('home_quick_records'),
        color: AppColors.success,
        background: AppColors.successSoft,
        onTap: onHealth,
      ),
      _QuickItem(
        icon: Icons.report_problem_outlined,
        title: l10n.t('report_a_concern'),
        subtitle: l10n.t('home_quick_report'),
        color: AppColors.warning,
        background: AppColors.warningSoft,
        onTap: onReport,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        final columns = wide ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: wide ? 1.15 : 1.36,
          children: [
            for (final item in items)
              AppCard(
                onTap: item.onTap,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 39,
                      height: 39,
                      decoration: BoxDecoration(
                        color: item.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, size: 20, color: item.color),
                    ),
                    const Spacer(),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _QuickItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });
}

class _NewsPreview extends StatelessWidget {
  final Article article;
  final bool featured;
  final VoidCallback onTap;

  const _NewsPreview({
    required this.article,
    required this.featured,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final featuredWidth = featured ? 100 : 78;
    final cacheWidth =
        (featuredWidth * MediaQuery.devicePixelRatioOf(context)).round();
    final thumbnail = article.thumbnail == null
        ? Container(
            color: AppColors.tealSoft,
            child: const Icon(
              Icons.health_and_safety_outlined,
              color: AppColors.teal,
            ),
          )
        : Image.network(
            article.thumbnail!,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.tealSoft,
              child: const Icon(
                Icons.health_and_safety_outlined,
                color: AppColors.teal,
              ),
            ),
          );

    return AppCard(
      onTap: onTap,
      clip: true,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: featured ? 100 : 78,
                height: featured ? 100 : 78,
                child: thumbnail,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: featured ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: featured ? 15 : 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.32,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          article.source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.tealDark,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '· ${formatShortDate(article.publishedDate, l10n)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignPreview extends StatelessWidget {
  final CampaignView view;
  final VoidCallback onTap;

  const _CampaignPreview({required this.view, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ongoing = view.status == CampaignStatus.ongoing;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 45,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: ongoing ? AppColors.successSoft : AppColors.tealSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Column(
                children: [
                  Text(
                    view.start.day.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ongoing ? AppColors.success : AppColors.tealDark,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    _month(view.start.month),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: ongoing ? AppColors.success : AppColors.tealDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    view.campaign.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                      fontSize: 13.5,
                      height: 1.32,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    view.campaign.organizer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppStatusChip(
              label: ongoing ? l10n.t('ongoing') : l10n.t('upcoming'),
              color: ongoing ? AppColors.success : AppColors.tealDark,
              background: ongoing ? AppColors.successSoft : AppColors.tealSoft,
            ),
          ],
        ),
      ),
    );
  }

  static String _month(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}
