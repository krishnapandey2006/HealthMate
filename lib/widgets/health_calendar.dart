import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'app_widgets.dart';

/// A compact, premium calendar used for date-of-birth capture and appointment
/// scheduling. It distinguishes today, the selected day, unavailable days and
/// days that already have an appointment.
class HealthCalendar extends StatefulWidget {
  final DateTime? selectedDate;
  final DateTime? initialMonth;
  final DateTime firstDate;
  final DateTime lastDate;
  final Set<DateTime> eventDates;
  final ValueChanged<DateTime> onDateSelected;
  final bool markEvents;

  const HealthCalendar({
    super.key,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
    this.selectedDate,
    this.initialMonth,
    this.eventDates = const {},
    this.markEvents = true,
  });

  @override
  State<HealthCalendar> createState() => HealthCalendarState();
}

class HealthCalendarState extends State<HealthCalendar> {
  late DateTime _displayMonth;
  bool _choosingMonth = false;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    final seed = widget.selectedDate ?? widget.initialMonth ?? DateTime.now();
    _displayMonth = DateTime(seed.year, seed.month);
  }

  bool get _canGoBack =>
      DateTime(_displayMonth.year, _displayMonth.month, 1).isAfter(
        DateTime(widget.firstDate.year, widget.firstDate.month, 1),
      );

  bool get _canGoForward =>
      DateTime(_displayMonth.year, _displayMonth.month, 1).isBefore(
        DateTime(widget.lastDate.year, widget.lastDate.month, 1),
      );

  void _changeMonth(int delta) {
    if (delta < 0 && !_canGoBack) return;
    if (delta > 0 && !_canGoForward) return;
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + delta);
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isEnabled(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    final first = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      widget.firstDate.day,
    );
    final last = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
      widget.lastDate.day,
    );
    return !date.isBefore(first) && !date.isAfter(last);
  }

  bool _hasEvent(DateTime day) {
    for (final event in widget.eventDates) {
      if (_sameDay(event, day)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(context),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: AppMotion.base,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, child: child),
            );
          },
          child: _choosingMonth
              ? _buildMonthPicker(context)
              : _buildMonth(context),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        _NavButton(
          icon: Icons.chevron_left_rounded,
          onPressed: _canGoBack ? () => _changeMonth(-1) : null,
          tooltip: 'Previous month',
        ),
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _choosingMonth = !_choosingMonth),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_months[_displayMonth.month - 1]} ${_displayMonth.year}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _choosingMonth
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.tealDark,
                  ),
                ],
              ),
            ),
          ),
        ),
        _NavButton(
          icon: Icons.chevron_right_rounded,
          onPressed: _canGoForward ? () => _changeMonth(1) : null,
          tooltip: 'Next month',
        ),
      ],
    );
  }

  Widget _buildMonth(BuildContext context) {
    final firstOfMonth = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final leading = firstOfMonth.weekday - 1;
    final daysInMonth =
        DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final today = DateTime.now();

    return Column(
      key: ValueKey('${_displayMonth.year}-${_displayMonth.month}'),
      children: [
        Row(
          children: [
            for (final day in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 44,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - leading + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }
            final day = DateTime(
              _displayMonth.year,
              _displayMonth.month,
              dayNumber,
            );
            final enabled = _isEnabled(day);
            final selected =
                widget.selectedDate != null && _sameDay(day, widget.selectedDate!);
            final isToday = _sameDay(day, today);
            final hasEvent = widget.markEvents && _hasEvent(day);

            Color textColor;
            if (!enabled) {
              textColor = AppColors.borderStrong;
            } else if (selected) {
              textColor = Colors.white;
            } else if (isToday) {
              textColor = AppColors.tealDark;
            } else {
              textColor = AppColors.navy;
            }

            return Semantics(
              button: enabled,
              selected: selected,
              enabled: enabled,
              label:
                  '$dayNumber ${_months[_displayMonth.month - 1]} ${_displayMonth.year}${hasEvent ? ', appointment' : ''}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: enabled ? () => widget.onDateSelected(day) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.teal
                          : isToday
                              ? AppColors.tealSoft
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isToday && !selected
                          ? Border.all(color: AppColors.teal, width: 1.2)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13.5,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        if (hasEvent)
                          Positioned(
                            bottom: 5,
                            child: Container(
                              width: selected ? 5 : 4,
                              height: selected ? 5 : 4,
                              decoration: BoxDecoration(
                                color: selected ? Colors.white : AppColors.teal,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMonthPicker(BuildContext context) {
    final years = <int>[];
    for (var year = widget.lastDate.year; year >= widget.firstDate.year; year--) {
      years.add(year);
    }
    return Column(
      key: const ValueKey('month-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Jump to a month',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: GridView.builder(
            itemCount: years.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 2.1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final year = years[index];
              final selected = year == _displayMonth.year;
              return _ChoiceBox(
                label: '$year',
                selected: selected,
                onTap: () {
                  setState(() {
                    _displayMonth = DateTime(
                      year,
                      _displayMonth.month.clamp(widget.firstDate.month, 12),
                    );
                    _choosingMonth = false;
                    if (_displayMonth.isAfter(widget.lastDate)) {
                      _displayMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
                    }
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final month = index + 1;
            final selected = month == _displayMonth.month;
            return _ChoiceBox(
              label: _months[index].substring(0, 3),
              selected: selected,
              onTap: () {
                setState(() {
                  _displayMonth = DateTime(_displayMonth.year, month);
                  _choosingMonth = false;
                });
              },
            );
          },
        ),
      ],
    );
  }
}

class _ChoiceBox extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceBox({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? AppColors.teal : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  const _NavButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: onPressed == null ? AppColors.surfaceMuted : Colors.white,
        foregroundColor:
            onPressed == null ? AppColors.borderStrong : AppColors.navy,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(38, 38),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

/// Opens the calendar in a bottom sheet. Returns the chosen date or null.
Future<DateTime?> showHealthDatePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialDate,
  Set<DateTime> eventDates = const {},
  String title = 'Choose a date',
  String? subtitle,
  String confirmLabel = 'Use this date',
  bool markEvents = true,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return _CalendarSheet(
        firstDate: firstDate,
        lastDate: lastDate,
        initialDate: initialDate,
        eventDates: eventDates,
        title: title,
        subtitle: subtitle,
        confirmLabel: confirmLabel,
        markEvents: markEvents,
      );
    },
  );
}

class _CalendarSheet extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialDate;
  final Set<DateTime> eventDates;
  final String title;
  final String? subtitle;
  final String confirmLabel;
  final bool markEvents;

  const _CalendarSheet({
    required this.firstDate,
    required this.lastDate,
    required this.initialDate,
    required this.eventDates,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.markEvents,
  });

  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final seed = widget.initialDate ??
        (now.isAfter(widget.lastDate) ? widget.lastDate : now);
    _selected = DateTime(
      seed.year,
      seed.month,
      seed.day,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.height * 0.88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSheetHeader(
                title: widget.title,
                subtitle: widget.subtitle,
                icon: Icons.event_available_outlined,
              ),
              const SizedBox(height: 14),
              HealthCalendar(
                selectedDate: _selected,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                eventDates: widget.eventDates,
                markEvents: widget.markEvents,
                onDateSelected: (date) => setState(() => _selected = date),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.tealSoft,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.tealDark, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _formatLongDate(_selected),
                        style: const TextStyle(
                          color: AppColors.tealDeep,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: Text(widget.confirmLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatLongDate(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Formats an appointment date without relying on locale data that may not be
/// bundled on every platform.
String formatFriendlyDate(DateTime date, {bool includeWeekday = true}) {
  const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final base = '${date.day} ${months[date.month - 1]} ${date.year}';
  return includeWeekday ? '${weekdays[date.weekday - 1]}, $base' : base;
}

String formatClockTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
