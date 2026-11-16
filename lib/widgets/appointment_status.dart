import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/appointment.dart';

/// Visual treatment shared by appointment cards and the detail screen.
class AppointmentStatusStyle {
  final Color color;
  final Color background;
  final IconData icon;

  const AppointmentStatusStyle(this.color, this.background, this.icon);
}

AppointmentStatusStyle appointmentStatusStyle(Appointment appointment) {
  switch (appointment.status) {
    case AppointmentStatus.completed:
      return const AppointmentStatusStyle(
        AppColors.success,
        AppColors.successSoft,
        Icons.check_circle_outline_rounded,
      );
    case AppointmentStatus.cancelled:
      return const AppointmentStatusStyle(
        AppColors.danger,
        AppColors.dangerSoft,
        Icons.cancel_outlined,
      );
    case AppointmentStatus.scheduled:
      if (appointment.isPast) {
        return const AppointmentStatusStyle(
          AppColors.slate,
          AppColors.neutralSoft,
          Icons.history_rounded,
        );
      }
      return const AppointmentStatusStyle(
        AppColors.tealDark,
        AppColors.tealSoft,
        Icons.event_available_outlined,
      );
  }
}

String appointmentStatusLabel(
  AppLocalizations l10n,
  Appointment appointment,
) {
  switch (appointment.statusKey) {
    case 'completed':
      return l10n.t('completed');
    case 'cancelled':
      return l10n.t('cancelled');
    default:
      if (appointment.isPast) return l10n.t('appointment_status_past');
      return l10n.t('appointment_status_scheduled');
  }
}
