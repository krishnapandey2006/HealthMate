import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/appointment.dart';
import '../services/appointment_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/appointment_status.dart';
import '../widgets/health_calendar.dart';
import 'appointment_form_screen.dart';

class AppointmentDetailScreen extends StatelessWidget {
  final String appointmentId;

  const AppointmentDetailScreen({super.key, required this.appointmentId});

  Appointment? _find(AppointmentProvider provider) {
    for (final appointment in provider.appointments) {
      if (appointment.id == appointmentId) return appointment;
    }
    return null;
  }

  Future<void> _edit(BuildContext context, Appointment appointment) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppointmentFormScreen(appointment: appointment),
      ),
    );
  }

  Future<void> _markCompleted(
    BuildContext context,
    Appointment appointment,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('mark_completed')),
        content: Text(l10n.t('mark_completed_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('mark_completed')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final error =
        await context.read<AppointmentProvider>().markCompleted(appointment.id);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      error ?? l10n.t('appointment_completed'),
      isError: error != null,
    );
  }

  Future<void> _cancel(BuildContext context, Appointment appointment) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('cancel_appointment')),
        content: Text(l10n.t('cancel_appointment_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('keep_appointment')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(l10n.t('cancel_appointment')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final error =
        await context.read<AppointmentProvider>().cancel(appointment.id);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      error ?? l10n.t('appointment_cancelled_local'),
      isError: error != null,
    );
  }

  Future<void> _delete(BuildContext context, Appointment appointment) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('remove_appointment')),
        content: Text(l10n.t('remove_appointment_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(l10n.t('remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final error =
        await context.read<AppointmentProvider>().remove(appointment.id);
    if (!context.mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      showAppSnackBar(context, l10n.t('appointment_removed'));
    } else {
      showAppSnackBar(context, error, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<AppointmentProvider>();
    final appointment = _find(provider);

    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('appointment_details'))),
        body: AppEmptyState(
          icon: Icons.event_busy_outlined,
          title: l10n.t('appointment_not_found'),
          message: l10n.t('appointment_not_found_body'),
          actionLabel: l10n.t('close'),
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }

    final style = appointmentStatusStyle(appointment);
    final date = appointment.scheduledAt;
    final time = TimeOfDay.fromDateTime(date);
    final isScheduled = appointment.status == AppointmentStatus.scheduled;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('appointment_details')),
        actions: [
          if (isScheduled)
            IconButton(
              tooltip: l10n.t('edit'),
              onPressed: () => _edit(context, appointment),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: ResponsiveBody(
          maxWidth: 720,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58,
                          height: 64,
                          decoration: BoxDecoration(
                            color: style.background,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: style.color,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _shortMonth(date.month),
                                style: TextStyle(
                                  color: style.color,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
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
                              AppStatusChip(
                                label: appointmentStatusLabel(l10n, appointment),
                                color: style.color,
                                background: style.background,
                                icon: style.icon,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                appointment.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.calendar_month_outlined,
                      label: l10n.t('date'),
                      value: formatFriendlyDate(date, includeWeekday: true),
                    ),
                    _DetailRow(
                      icon: Icons.schedule_outlined,
                      label: l10n.t('time'),
                      value:
                          '${formatClockTime(time)} – ${formatClockTime(TimeOfDay.fromDateTime(appointment.endsAt))} (${appointment.durationMinutes} min)',
                    ),
                    _DetailRow(
                      icon: Icons.category_outlined,
                      label: l10n.t('appointment_type'),
                      value: appointmentKindLabel(l10n, appointment.kind),
                    ),
                    if (appointment.provider.isNotEmpty)
                      _DetailRow(
                        icon: Icons.medical_services_outlined,
                        label: l10n.t('doctor_or_clinic'),
                        value: appointment.provider,
                      ),
                    if (appointment.location.isNotEmpty)
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: l10n.t('visit_location'),
                        value: appointment.location,
                      ),
                    if (appointment.notes.trim().isNotEmpty)
                      _DetailRow(
                        icon: Icons.notes_rounded,
                        label: l10n.t('notes'),
                        value: appointment.notes,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppInfoBanner(
                icon: Icons.info_outline_rounded,
                text: l10n.t('appointment_no_hospital_sync'),
                color: AppColors.warning,
                background: AppColors.warningSoft,
              ),
              const SizedBox(height: 18),
              if (isScheduled) ...[
                FilledButton.icon(
                  onPressed: () => _markCompleted(context, appointment),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(l10n.t('mark_completed')),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _edit(context, appointment),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.t('edit_appointment')),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _cancel(context, appointment),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  icon: const Icon(Icons.event_busy_outlined),
                  label: Text(l10n.t('cancel_appointment')),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () => _delete(context, appointment),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.6)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(l10n.t('remove_appointment')),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '${l10n.t('saved_on_device')} · ${formatDateTime(appointment.createdAt)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.tealDark),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.navy,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String appointmentKindLabel(AppLocalizations l10n, AppointmentKind kind) {
  switch (kind) {
    case AppointmentKind.consultation:
      return l10n.t('consultation');
    case AppointmentKind.vaccination:
      return l10n.t('vaccination');
    case AppointmentKind.lab:
      return l10n.t('lab_test');
    case AppointmentKind.followUp:
      return l10n.t('follow_up');
    case AppointmentKind.other:
      return l10n.t('other');
  }
}
