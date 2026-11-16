import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/appointment.dart';
import '../services/appointment_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/health_calendar.dart';

class AppointmentFormScreen extends StatefulWidget {
  final Appointment? appointment;

  const AppointmentFormScreen({super.key, this.appointment});

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _providerController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _date;
  late TimeOfDay _time;
  AppointmentKind _kind = AppointmentKind.consultation;
  int _duration = 30;
  String? _error;
  bool _saving = false;

  bool get _isEditing => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.appointment;
    final now = DateTime.now();
    if (existing != null) {
      _titleController.text = existing.title;
      _providerController.text = existing.provider;
      _locationController.text = existing.location;
      _notesController.text = existing.notes;
      _kind = existing.kind;
      _duration = existing.durationMinutes;
      _date = DateTime(existing.scheduledAt.year, existing.scheduledAt.month, existing.scheduledAt.day);
      _time = TimeOfDay.fromDateTime(existing.scheduledAt);
      if (_date.isBefore(DateTime(now.year, now.month, now.day))) {
        _date = DateTime(now.year, now.month, now.day);
      }
    } else {
      final suggested = now.add(const Duration(hours: 2));
      _date = DateTime(suggested.year, suggested.month, suggested.day);
      _time = TimeOfDay(hour: suggested.hour, minute: (suggested.minute ~/ 15) * 15);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _providerController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime get _scheduledAt => DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final provider = context.read<AppointmentProvider>();
    final eventDates = provider.appointments
        .where((appointment) =>
            appointment.status != AppointmentStatus.cancelled &&
            appointment.id != widget.appointment?.id)
        .map((appointment) => DateTime(
              appointment.scheduledAt.year,
              appointment.scheduledAt.month,
              appointment.scheduledAt.day,
            ))
        .toSet();
    final l10n = AppLocalizations.of(context);
    final picked = await showHealthDatePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(now.year + 2, now.month, now.day),
      initialDate: _date.isBefore(today) ? today : _date,
      eventDates: eventDates,
      title: l10n.t('choose_appointment_date'),
      subtitle: l10n.t('calendar_legend_note'),
      confirmLabel: l10n.t('use_this_date'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      final candidate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _time.hour,
        _time.minute,
      );
      if (!candidate.isAfter(DateTime.now())) {
        final next = DateTime.now().add(const Duration(hours: 1));
        _time = TimeOfDay(hour: next.hour, minute: (next.minute ~/ 15) * 15);
      }
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: AppLocalizations.of(context).t('choose_appointment_time'),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_saving) return;

    final scheduled = _scheduledAt;
    if (!scheduled.isAfter(DateTime.now())) {
      setState(() => _error = AppLocalizations.of(context).t('appointment_future_required'));
      return;
    }

    setState(() => _saving = true);
    try {
      final provider = context.read<AppointmentProvider>();
      final error = _isEditing
          ? await provider.update(
              appointment: widget.appointment!,
              title: _titleController.text,
              scheduledAt: scheduled,
              provider: _providerController.text,
              location: _locationController.text,
              durationMinutes: _duration,
              kind: _kind,
              notes: _notesController.text,
            )
          : await provider.create(
              title: _titleController.text,
              scheduledAt: scheduled,
              provider: _providerController.text,
              location: _locationController.text,
              durationMinutes: _duration,
              kind: _kind,
              notes: _notesController.text,
            );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error;
      });
      if (error == null) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context)
              .t(_isEditing ? 'appointment_updated' : 'appointment_saved'),
        );
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            AppLocalizations.of(context).t('appointment_save_failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t(_isEditing ? 'edit_appointment' : 'new_appointment')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: ResponsiveBody(
            maxWidth: 700,
            padding: EdgeInsets.zero,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppInfoBanner(
                    icon: Icons.event_note_outlined,
                    text: l10n.t('appointment_local_note'),
                    color: AppColors.tealDark,
                    background: AppColors.tealSoft,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.t('what_is_this_visit_for'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: l10n.t('appointment_reason'),
                      hintText: l10n.t('appointment_reason_hint'),
                      prefixIcon: const Icon(Icons.assignment_outlined),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.length < 3) return l10n.t('appointment_reason_required');
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<AppointmentKind>(
                    initialValue: _kind,
                    decoration: InputDecoration(
                      labelText: l10n.t('appointment_type'),
                      prefixIcon: const Icon(Icons.category_outlined),
                    ),
                    items: [
                      for (final kind in AppointmentKind.values)
                        DropdownMenuItem(
                          value: kind,
                          child: Text(_kindLabel(l10n, kind)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _kind = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _providerController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: '${l10n.t('doctor_or_clinic')} (${l10n.t('optional')})',
                      prefixIcon: const Icon(Icons.medical_services_outlined),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _locationController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: '${l10n.t('visit_location')} (${l10n.t('optional')})',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.t('when'),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _PickerTile(
                                icon: Icons.calendar_month_outlined,
                                label: l10n.t('date'),
                                value: formatFriendlyDate(_date, includeWeekday: true),
                                onTap: _pickDate,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PickerTile(
                                icon: Icons.schedule_outlined,
                                label: l10n.t('time'),
                                value: formatClockTime(_time),
                                onTap: _pickTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: _duration,
                          decoration: InputDecoration(
                            labelText: l10n.t('duration'),
                            prefixIcon: const Icon(Icons.timelapse_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(value: 15, child: Text('15 minutes')),
                            DropdownMenuItem(value: 30, child: Text('30 minutes')),
                            DropdownMenuItem(value: 45, child: Text('45 minutes')),
                            DropdownMenuItem(value: 60, child: Text('1 hour')),
                            DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                            DropdownMenuItem(value: 120, child: Text('2 hours')),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _duration = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.t('calendar_legend_note'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: '${l10n.t('notes')} (${l10n.t('optional')})',
                      hintText: l10n.t('appointment_notes_hint'),
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 56),
                        child: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSoft,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 19),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 12.8,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
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
                            l10n.t(_isEditing ? 'save_changes' : 'save_appointment'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _kindLabel(AppLocalizations l10n, AppointmentKind kind) {
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
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: AppColors.tealDark),
                  const SizedBox(width: 5),
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.tealDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
