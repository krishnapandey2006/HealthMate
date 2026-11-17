import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/appointment.dart';
import '../services/appointment_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/appointment_status.dart';
import '../widgets/health_calendar.dart';
import 'appointment_detail_screen.dart';
import 'appointment_form_screen.dart';
import 'nearby_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool _showPast = false;

  Future<void> _openForm([Appointment? appointment]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppointmentFormScreen(appointment: appointment),
      ),
    );
  }

  Future<void> _openDetails(Appointment appointment) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppointmentDetailScreen(appointmentId: appointment.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<AppointmentProvider>();
    final upcoming = provider.upcoming;
    final past = provider.past;
    final visible = _showPast ? past : upcoming;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('appointments')),
        actions: [
          IconButton(
            tooltip: l10n.t('new_appointment'),
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_rounded, size: 27),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ResponsiveBody(
                maxWidth: 820,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (provider.storageError != null) ...[
                      AppInfoBanner(
                        icon: Icons.sd_card_alert_outlined,
                        text: provider.storageError!,
                        color: AppColors.warning,
                        background: AppColors.warningSoft,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _AppointmentHero(
                      next: provider.nextAppointment,
                      scheduledCount: provider.scheduledCount,
                      onAdd: () => _openForm(),
                      onDetails: provider.nextAppointment == null
                          ? null
                          : () => _openDetails(provider.nextAppointment!),
                    ),
                    const SizedBox(height: 12),
                    AppInfoBanner(
                      icon: Icons.info_outline_rounded,
                      text: l10n.t('appointment_planner_disclaimer'),
                      color: AppColors.slate,
                      background: AppColors.neutralSoft,
                    ),
                    const SizedBox(height: 18),
                    _SegmentedTabs(
                      selectedPast: _showPast,
                      upcomingCount: upcoming.length,
                      pastCount: past.length,
                      onChanged: (value) => setState(() => _showPast = value),
                    ),
                    const SizedBox(height: 12),
                    if (provider.loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Column(
                          children: [
                            ArticleSkeleton(),
                            SizedBox(height: 10),
                            ArticleSkeleton(),
                          ],
                        ),
                      )
                    else if (visible.isEmpty)
                      _EmptyAppointments(
                        past: _showPast,
                        onAdd: _showPast ? null : () => _openForm(),
                        onFindCare: _showPast
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const NearbyScreen(),
                                  ),
                                ),
                      )
                    else
                      for (var index = 0; index < visible.length; index++) ...[
                        _AppointmentCard(
                          appointment: visible[index],
                          onTap: () => _openDetails(visible[index]),
                        ),
                        if (index != visible.length - 1)
                          const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 16),
                    AppInfoBanner(
                      icon: Icons.lock_outline_rounded,
                      text: l10n.t('appointment_device_only'),
                      color: AppColors.tealDark,
                      background: AppColors.tealSoft,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.t('add_appointment')),
      ),
    );
  }
}

class _AppointmentHero extends StatelessWidget {
  final Appointment? next;
  final int scheduledCount;
  final VoidCallback onAdd;
  final VoidCallback? onDetails;

  const _AppointmentHero({
    required this.next,
    required this.scheduledCount,
    required this.onAdd,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (next == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.teal,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          boxShadow: AppShadows.brand,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.t('appointments_empty_hero'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('appointments_empty_hero_body'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.tealDeep,
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.t('add_appointment')),
            ),
          ],
        ),
      );
    }

    final appointment = next!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.brand,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onDetails,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'NEXT APPOINTMENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      l10n.t('scheduled_count').replaceAll('{count}', '$scheduledCount'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${appointment.scheduledAt.day}',
                            style: const TextStyle(
                              color: AppColors.tealDeep,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _month(appointment.scheduledAt).toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.tealDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
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
                            appointment.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              letterSpacing: -0.25,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${_weekday(appointment.scheduledAt)}, ${formatClockTime(TimeOfDay.fromDateTime(appointment.scheduledAt))} · ${appointment.durationMinutes} min',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 12.5,
                            ),
                          ),
                          if (appointment.provider.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              appointment.provider,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _month(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[date.month - 1];
  }

  static String _weekday(DateTime date) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    return days[date.weekday - 1];
  }
}

class _SegmentedTabs extends StatelessWidget {
  final bool selectedPast;
  final int upcomingCount;
  final int pastCount;
  final ValueChanged<bool> onChanged;

  const _SegmentedTabs({
    required this.selectedPast,
    required this.upcomingCount,
    required this.pastCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: '${l10n.t('upcoming')} ($upcomingCount)',
              selected: !selectedPast,
              onTap: () => onChanged(false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _Segment(
              label: '${l10n.t('past')} ($pastCount)',
              selected: selectedPast,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected ? AppShadows.card : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.tealDark : AppColors.slate,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;

  const _AppointmentCard({required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = appointmentStatusStyle(appointment);
    final date = appointment.scheduledAt;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: status.color,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _shortMonth(date.month),
                      style: TextStyle(
                        color: status.color,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            appointment.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              height: 1.32,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        AppStatusChip(
                          label: appointmentStatusLabel(l10n, appointment),
                          color: status.color,
                          background: status.background.withValues(alpha: 0.85),
                          icon: status.icon,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule_outlined, size: 14, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text(
                          '${formatClockTime(TimeOfDay.fromDateTime(date))} · ${appointment.durationMinutes} min',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                    if (appointment.provider.isNotEmpty || appointment.location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 14, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              [appointment.provider, appointment.location]
                                  .where((value) => value.isNotEmpty)
                                  .join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 22),
                child: Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortMonth(int month) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}

class _EmptyAppointments extends StatelessWidget {
  final bool past;
  final VoidCallback? onAdd;
  final VoidCallback? onFindCare;

  const _EmptyAppointments({
    required this.past,
    this.onAdd,
    this.onFindCare,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: AppColors.tealSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              past ? Icons.history_rounded : Icons.event_available_outlined,
              color: AppColors.teal,
              size: 29,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            past ? l10n.t('no_past_appointments') : l10n.t('no_upcoming_appointments'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 7),
          Text(
            past
                ? l10n.t('no_past_appointments_body')
                : l10n.t('no_upcoming_appointments_body'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onAdd != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.t('add_appointment')),
            ),
          ],
          if (onFindCare != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onFindCare,
              icon: const Icon(Icons.near_me_outlined, size: 18),
              label: Text(l10n.t('find_nearby_care')),
            ),
          ],
        ],
      ),
    );
  }
}


