import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_widgets.dart';

/// Help, public-data sources and legal information. The app has no support
/// inbox or backend account, so no contact channel is invented here.
class HelpAboutScreen extends StatelessWidget {
  const HelpAboutScreen({super.key});

  static const _version = '1.0.0';

  void _showText(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSheetHeader(title: title, icon: Icons.description_outlined),
                const SizedBox(height: 14),
                Text(
                  body,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(height: 1.6),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(l10n.t('close')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('help_support'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: ResponsiveBody(
          maxWidth: 780,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppLogo(size: 54),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.t('help_about_title'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.t('help_about_tagline'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppInfoBanner(
                icon: Icons.smartphone_outlined,
                text: l10n.t('help_about_local'),
                color: AppColors.tealDark,
                background: AppColors.tealSoft,
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: l10n.t('help_faq_title')),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _FaqTile(
                      question: l10n.t('faq_data_q'),
                      answer: l10n.t('faq_data_a'),
                    ),
                    const Divider(height: 1),
                    _FaqTile(
                      question: l10n.t('faq_location_q'),
                      answer: l10n.t('faq_location_a'),
                    ),
                    const Divider(height: 1),
                    _FaqTile(
                      question: l10n.t('faq_sources_q'),
                      answer: l10n.t('faq_sources_a'),
                    ),
                    const Divider(height: 1),
                    _FaqTile(
                      question: l10n.t('faq_booking_q'),
                      answer: l10n.t('faq_booking_a'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.t('help_faq_more'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(height: 1.5, fontSize: 11.5),
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: l10n.t('help_sources_title')),
              AppListPanel(
                children: [
                  _SourceTile(
                    title: 'WHO',
                    subtitle: l10n.t('source_who'),
                    onTap: () =>
                        openExternalUrl(context, 'https://www.who.int/'),
                  ),
                  _SourceTile(
                    title: l10n.t('source_mohfw_title'),
                    subtitle: l10n.t('source_mohfw'),
                    onTap: () =>
                        openExternalUrl(context, 'https://mohfw.gov.in/'),
                  ),
                  _SourceTile(
                    title: 'NHM',
                    subtitle: l10n.t('source_nhm'),
                    onTap: () =>
                        openExternalUrl(context, 'https://nhm.gov.in/'),
                  ),
                  _SourceTile(
                    title: 'OpenStreetMap',
                    subtitle: l10n.t('source_osm'),
                    onTap: () => openExternalUrl(
                      context,
                      'https://www.openstreetmap.org/',
                    ),
                  ),
                  _SourceTile(
                    title: l10n.t('source_news_title'),
                    subtitle: l10n.t('source_news'),
                    onTap: () => openExternalUrl(
                      context,
                      'https://news.google.com/',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                l10n.t('sources_disclaimer'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(height: 1.5, fontSize: 11.5),
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: l10n.t('help_terms_title')),
              AppListPanel(
                children: [
                  AppNavTile(
                    icon: Icons.info_outline_rounded,
                    title: l10n.t('about_healthmate'),
                    subtitle: l10n.t('about_healthmate_body'),
                    onTap: () => _showText(
                      context,
                      title: l10n.t('about_healthmate'),
                      body: '${l10n.t('about_healthmate_body')}\n\n'
                          '${l10n.t('help_no_contact')}',
                    ),
                  ),
                  AppNavTile(
                    icon: Icons.privacy_tip_outlined,
                    title: l10n.t('privacy_policy'),
                    subtitle: l10n.t('privacy_body'),
                    onTap: () => _showText(
                      context,
                      title: l10n.t('privacy_policy'),
                      body: l10n.t('privacy_policy_body'),
                    ),
                  ),
                  AppNavTile(
                    icon: Icons.gavel_outlined,
                    title: l10n.t('terms_conditions'),
                    subtitle: l10n.t('help_terms_title'),
                    onTap: () => _showText(
                      context,
                      title: l10n.t('terms_conditions'),
                      body: l10n.t('terms_body'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppInfoBanner(
                icon: Icons.health_and_safety_outlined,
                text: l10n.t('health_disclaimer_short'),
                color: AppColors.warning,
                background: AppColors.warningSoft,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.t('help_version_label').replaceAll('{version}', _version),
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

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Text(
        question,
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            answer,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(height: 1.55, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppNavTile(
      icon: Icons.public_rounded,
      title: title,
      subtitle: subtitle,
      trailing: const Icon(
        Icons.open_in_new_rounded,
        size: 17,
        color: AppColors.muted,
      ),
      onTap: onTap,
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
