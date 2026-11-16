import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../health_campaigns_screen.dart';
import '../health_news_screen.dart';
import '../l10n/app_localizations.dart';
import '../language_provider.dart';
import '../models/article.dart';
import '../models/health_campaign.dart';
import '../services/app_settings_provider.dart';
import '../services/campaign_service.dart';
import '../services/news_service.dart';
import '../services/profile_provider.dart';
import '../services/sos_service.dart';
import '../services/vaccine_service.dart';
import '../widgets/app_widgets.dart';
import 'book_screen.dart';
import 'nearby_screen.dart';
import 'profile_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'vaccine_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _newsService = NewsService();
  final _campaignService = CampaignService();
  final _vaccinationRepository = VaccinationRepository();

  List<Article> _articles = const [];
  List<CampaignView> _campaigns = const [];
  bool _loadingNews = true;
  bool _loadingCampaigns = true;
  String? _newsError;
  String? _campaignWarning;
  DateTime? _newsUpdatedAt;
  int _vaccinationCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadNews(), _loadCampaigns(), _loadVaccinations()]);
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
      lang: context.read<LanguageProvider>().languageCode,
      page: 1,
      limit: 4,
      forceRefresh: refresh,
    );
    if (!mounted) return;
    setState(() {
      _loadingNews = false;
      _articles = result.articles.take(3).toList();
      _newsError = result.isError && result.articles.isEmpty
          ? result.error?.message
          : result.warning;
      _newsUpdatedAt = result.lastUpdated;
    });
  }

  Future<void> _loadCampaigns({bool refresh = false}) async {
    if (mounted) setState(() => _loadingCampaigns = true);
    final result = await _campaignService.load(forceRefresh: refresh);
    if (!mounted) return;
    setState(() {
      _loadingCampaigns = false;
      _campaigns = _campaignService.upcoming(DateTime.now()).take(2).toList();
      _campaignWarning = result.error ?? result.warning;
    });
  }

  Future<void> _loadVaccinations() async {
    final records = await _vaccinationRepository.load();
    if (!mounted) return;
    setState(() => _vaccinationCount = records.length);
  }

  Future<void> _refresh() async {
    await _loadAll();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _showEmergency() async {
    final settings = context.read<AppSettingsProvider>();
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.dangerSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emergency_outlined, color: AppColors.danger),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('emergency_help'), style: Theme.of(context).textTheme.titleLarge),
                          Text(
                            l10n.t('emergency_help_body'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: () async {
                    try {
                      await SOSService.openDialer(settings.emergencyNumber);
                    } catch (_) {
                      if (context.mounted) {
                        showAppSnackBar(context, l10n.t('dialer_unavailable'), isError: true);
                      }
                    }
                  },
                  icon: const Icon(Icons.call_rounded),
                  label: Text('${l10n.t('call_emergency')} · ${settings.emergencyNumber}'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await SOSService.openDialer('108');
                    } catch (_) {
                      if (context.mounted) {
                        showAppSnackBar(context, l10n.t('dialer_unavailable'), isError: true);
                      }
                    }
                  },
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
                      if (context.mounted) {
                        showAppSnackBar(context, l10n.t('sms_unavailable'), isError: true);
                      }
                    }
                  },
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(l10n.t('send_sos_sms')),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.t('emergency_disclaimer'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileProvider = context.watch<ProfileProvider>();
    final settings = context.watch<AppSettingsProvider>();
    final profile = profileProvider.profile;
    final firstName = profile?.firstName.trim() ?? '';
    final greeting = firstName.isEmpty ? l10n.t('welcome') : '${l10n.t('namaste')}, $firstName';
    final now = DateTime.now();
    final hour = now.hour;
    final timeGreeting = hour < 12
        ? l10n.t('good_morning')
        : hour < 17
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
              title: Row(
                children: [
                  const AppLogo(size: 34),
                  const SizedBox(width: 10),
                  Text(
                    'HealthMate',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                        ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: l10n.t('settings_title'),
                  onPressed: () => _open(const SettingsScreen()),
                  icon: const Icon(Icons.settings_outlined),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => _open(const ProfileScreen()),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.tealSoft,
                      child: Text(
                        firstName.isEmpty ? 'H' : firstName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.tealDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: ResponsiveBody(
                maxWidth: 980,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$timeGreeting, $greeting',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.slate,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.t('home_subtitle'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: 18),
                    _SetupSummaryCard(
                      profileComplete: profileProvider.isComplete,
                      vaccinations: _vaccinationCount,
                      onTap: () => _open(const ProfileScreen()),
                    ),
                    const SizedBox(height: 14),
                    _EmergencyStrip(
                      number: settings.emergencyNumber,
                      onTap: _showEmergency,
                    ),
                    const SizedBox(height: 24),
                    SectionHeader(
                      title: l10n.t('quick_actions'),
                      actionLabel: null,
                    ),
                    const SizedBox(height: 12),
                    _QuickActions(
                      onNearby: () => _open(const NearbyScreen()),
                      onReport: () => _open(const ReportScreen()),
                      onBook: () => _open(const BookScreen()),
                      onVaccines: () => _open(const VaccineScreen()),
                      onNews: () => _open(const HealthNewsScreen()),
                      onCampaigns: () => _open(const HealthCampaignsScreen()),
                    ),
                    const SizedBox(height: 28),
                    SectionHeader(
                      title: l10n.t('latest_health_news'),
                      actionLabel: l10n.t('see_all'),
                      onAction: () => _open(const HealthNewsScreen()),
                    ),
                    const SizedBox(height: 10),
                    _buildNewsSection(l10n),
                    const SizedBox(height: 28),
                    SectionHeader(
                      title: l10n.t('verified_campaigns'),
                      actionLabel: l10n.t('see_all'),
                      onAction: () => _open(const HealthCampaignsScreen()),
                    ),
                    const SizedBox(height: 10),
                    _buildCampaignSection(l10n),
                    const SizedBox(height: 28),
                    AppListPanel(
                      children: [
                        AppNavTile(
                          icon: profileProvider.isComplete
                              ? Icons.verified_user_outlined
                              : Icons.person_outline_rounded,
                          title: l10n.t('profile_status_title'),
                          subtitle: l10n.t('sync_device_only'),
                          trailing: AppStatusChip.neutral(l10n.t('local')),
                          onTap: () => _open(const ProfileScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.t('home_disclaimer'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
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

  Widget _buildNewsSection(AppLocalizations l10n) {
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
        background: _newsError == null ? const Color(0xFFF0F5F3) : AppColors.warningSoft,
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
        AppListPanel(
          children: [
            for (var i = 0; i < _articles.length; i++)
              _CompactArticleCard(
                article: _articles[i],
                featured: i == 0,
                onTap: () => _open(HealthNewsScreen(initialArticle: _articles[i])),
              ),
          ],
        ),
        if (_newsUpdatedAt != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${l10n.t('last_updated')} ${formatShortDate(_newsUpdatedAt!, l10n)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCampaignSection(AppLocalizations l10n) {
    if (_loadingCampaigns) {
      return const ArticleSkeleton();
    }
    if (_campaigns.isEmpty) {
      return AppInfoBanner(
        icon: Icons.event_busy_outlined,
        text: _campaignWarning ?? l10n.t('no_upcoming_campaigns'),
        color: AppColors.slate,
        background: const Color(0xFFF0F5F3),
        trailing: TextButton(
          onPressed: () => _loadCampaigns(refresh: true),
          child: Text(l10n.t('retry')),
        ),
      );
    }

    return AppListPanel(
      children: [
        for (var i = 0; i < _campaigns.length; i++)
          _CampaignPreviewCard(
            view: _campaigns[i],
            onTap: () => _open(const HealthCampaignsScreen()),
          ),
      ],
    );
  }
}

class _SetupSummaryCard extends StatelessWidget {
  final bool profileComplete;
  final int vaccinations;
  final VoidCallback onTap;

  const _SetupSummaryCard({
    required this.profileComplete,
    required this.vaccinations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.t('setup_title'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: onTap,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    tooltip: l10n.t('view_profile'),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  l10n.t('setup_note'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 8),
              _SetupLine(
                label: l10n.t('profile'),
                value: profileComplete
                    ? l10n.t('profile_complete')
                    : l10n.t('profile_incomplete'),
                attention: !profileComplete,
              ),
              const Padding(
                padding: EdgeInsets.only(left: 27),
                child: Divider(),
              ),
              _SetupLine(
                label: l10n.t('records_saved_label'),
                value: '$vaccinations',
                attention: vaccinations == 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupLine extends StatelessWidget {
  final String label;
  final String value;
  final bool attention;

  const _SetupLine({
    required this.label,
    required this.value,
    this.attention = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: attention ? AppColors.warning : AppColors.teal,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13.5, color: AppColors.slate),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
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
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.emergency_outlined, color: AppColors.danger, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('emergency_help'),
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.t('emergency_help_short'),
                      style: TextStyle(
                        color: AppColors.danger.withValues(alpha: 0.86),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                number,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
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

class _QuickActions extends StatelessWidget {
  final VoidCallback onNearby;
  final VoidCallback onReport;
  final VoidCallback onBook;
  final VoidCallback onVaccines;
  final VoidCallback onNews;
  final VoidCallback onCampaigns;

  const _QuickActions({
    required this.onNearby,
    required this.onReport,
    required this.onBook,
    required this.onVaccines,
    required this.onNews,
    required this.onCampaigns,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = [
      (Icons.near_me_outlined, l10n.t('nearby'), onNearby),
      (Icons.report_problem_outlined, l10n.t('report'), onReport),
      (Icons.calendar_month_outlined, l10n.t('appointments'), onBook),
      (Icons.vaccines_outlined, l10n.t('vaccines'), onVaccines),
      (Icons.newspaper_outlined, l10n.t('news'), onNews),
      (Icons.campaign_outlined, l10n.t('campaigns'), onCampaigns),
    ];

    List<Widget> tiles(Iterable<(IconData, String, VoidCallback)> slice) => [
          for (final action in slice)
            AppNavTile(
              icon: action.$1,
              title: action.$2,
              onTap: action.$3,
              titleSize: 14.5,
            ),
        ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return AppListPanel(children: tiles(actions));
        }
        final half = (actions.length / 2).ceil();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: AppListPanel(children: tiles(actions.take(half)))),
            const SizedBox(width: 12),
            Expanded(child: AppListPanel(children: tiles(actions.skip(half)))),
          ],
        );
      },
    );
  }
}

class _CompactArticleCard extends StatelessWidget {
  final Article article;
  final bool featured;
  final VoidCallback onTap;

  const _CompactArticleCard({
    required this.article,
    required this.onTap,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final meta = Row(
      children: [
        Flexible(
          child: Text(
            article.source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.tealDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '· ${formatShortDate(article.publishedDate, l10n)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
        ),
      ],
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: featured
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: SizedBox(
                      width: 92,
                      height: 92,
                      child: _ArticleThumb(article: article),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.32,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          article.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5),
                        ),
                        const SizedBox(height: 8),
                        meta,
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.35,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 5),
                  meta,
                ],
              ),
      ),
    );
  }
}

class _ArticleThumb extends StatelessWidget {
  final Article article;

  const _ArticleThumb({required this.article});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.tealSoft,
      child: const Icon(Icons.health_and_safety_outlined, color: AppColors.teal),
    );
    if (article.thumbnail == null) return placeholder;
    return Image.network(
      article.thumbnail!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}

class _CampaignPreviewCard extends StatelessWidget {
  final CampaignView view;
  final VoidCallback onTap;

  const _CampaignPreviewCard({required this.view, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ongoing = view.status == CampaignStatus.ongoing;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    view.start.day.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tealDark,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    _monthShort(view.start.month),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
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
                      fontSize: 14.5,
                      height: 1.32,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${view.campaign.organizer} · ${view.campaign.sourceName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
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

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _monthShort(int month) => _months[(month - 1).clamp(0, 11)];
}

