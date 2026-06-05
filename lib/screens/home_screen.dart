import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../app_colors.dart';
import '../models/office_location.dart';
import '../models/special_day.dart';
import '../providers/attendance_provider.dart';
import '../providers/office_provider.dart';
import '../providers/special_day_provider.dart';
import 'manual_attendance_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';
import 'special_day_screen.dart';

enum _BlankDayAction { attendance, holiday, sickLeave }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await ref.read(officeProvider.notifier).load();
    _refreshAttendance();
  }

  void _refreshAttendance() {
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    ref.read(attendanceProvider.notifier).loadForMonth(
      office.id!,
      _focusedDay.year,
      _focusedDay.month,
    );
    ref.read(specialDayProvider.notifier).loadForMonth(
      _focusedDay.year,
      _focusedDay.month,
    );
  }

  void _onPageChanged(DateTime day) {
    setState(() => _focusedDay = day);
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    ref.read(attendanceProvider.notifier).loadForMonth(
      office.id!,
      day.year,
      day.month,
    );
    ref.read(specialDayProvider.notifier).loadForMonth(day.year, day.month);
  }

  Future<void> _openManualAttendance({DateTime? initialDate}) async {
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    final changed = await Navigator.push<bool>(
      context,
      _slideRoute(ManualAttendanceScreen(office: office, initialDate: initialDate)),
    );
    if (changed == true && mounted) _refreshAttendance();
  }

  Future<void> _openSpecialDay({DateTime? initialDate, DayType? initialType}) async {
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    final changed = await Navigator.push<bool>(
      context,
      _slideRoute(SpecialDayScreen(
        officeId: office.id!,
        initialDate: initialDate,
        initialType: initialType,
      )),
    );
    if (changed == true && mounted) _refreshAttendance();
  }

  Future<void> _showDayTypeBottomSheet(DateTime day) async {
    final result = await showModalBottomSheet<_BlankDayAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                DateFormat('MMMM d, yyyy').format(day),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: AppColors.attendance),
              title: const Text('Mark as Attended'),
              onTap: () => Navigator.pop(ctx, _BlankDayAction.attendance),
            ),
            ListTile(
              leading: const Icon(Icons.beach_access_outlined, color: AppColors.holiday),
              title: const Text('Mark as Public Holiday'),
              onTap: () => Navigator.pop(ctx, _BlankDayAction.holiday),
            ),
            ListTile(
              leading: const Icon(Icons.sick_outlined, color: AppColors.sickLeave),
              title: const Text('Mark as Sick Leave'),
              onTap: () => Navigator.pop(ctx, _BlankDayAction.sickLeave),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (result) {
      case _BlankDayAction.attendance:
        await _openManualAttendance(initialDate: day);
      case _BlankDayAction.holiday:
        await _openSpecialDay(initialDate: day, initialType: DayType.holiday);
      case _BlankDayAction.sickLeave:
        await _openSpecialDay(initialDate: day, initialType: DayType.sickLeave);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final officeState = ref.watch(officeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Office Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              _slideRoute(const SettingsScreen()),
            ).then((_) => _init()),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: officeState.loading
            ? const Center(key: ValueKey('loading'), child: CircularProgressIndicator())
            : !officeState.hasOffice
                ? _EmptyState(
                    key: const ValueKey('empty'),
                    onAdd: () => Navigator.push(
                      context,
                      _slideRoute(const SetupScreen()),
                    ).then((_) => _init()),
                  )
                : _Dashboard(
                    key: ValueKey(officeState.selectedOffice?.id),
                    offices: officeState.offices,
                    selected: officeState.selectedOffice!,
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    onOfficeChanged: (o) {
                      ref.read(officeProvider.notifier).selectOffice(o);
                      _refreshAttendance();
                    },
                    onFormatChanged: (f) => setState(() => _calendarFormat = f),
                    onPageChanged: _onPageChanged,
                    onManualCheckIn: () async {
                      final officeId = ref.read(officeProvider).selectedOffice!.id!;
                      final result = await ref
                          .read(attendanceProvider.notifier)
                          .manualCheckIn(officeId);
                      if (!context.mounted) return;
                      final msg = switch (result) {
                        CheckInResult.recorded => 'Attendance recorded for today!',
                        CheckInResult.alreadyRecorded => 'Already checked in for today.',
                        CheckInResult.specialDayConflict =>
                          'Today is marked as a holiday or sick leave — remove that first.',
                      };
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    onPastDateCheckIn: () => _openManualAttendance(),
                    onSpecialDay: () => _openSpecialDay(),
                    onAttendanceDayTapped: (day) => _openManualAttendance(initialDate: day),
                    onSpecialDayTapped: (day) => _openSpecialDay(initialDate: day),
                    onBlankDayTapped: (day) => _showDayTypeBottomSheet(day),
                  ),
      ),
    );
  }
}

/// Slide-from-right page transition used for all push navigations.
Route<T> _slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 280),
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, size: 80, color: cs.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 24),
            Text(
              'No Office Registered',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Add your office address to start tracking your return-to-office days automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add Office'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard ─────────────────────────────────────────────────────────────────

class _Dashboard extends ConsumerWidget {
  final List<OfficeLocation> offices;
  final OfficeLocation selected;
  final DateTime focusedDay;
  final CalendarFormat calendarFormat;
  final ValueChanged<OfficeLocation> onOfficeChanged;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final ValueChanged<DateTime> onPageChanged;
  final VoidCallback onManualCheckIn;
  final VoidCallback onPastDateCheckIn;
  final VoidCallback onSpecialDay;
  final ValueChanged<DateTime> onAttendanceDayTapped;
  final ValueChanged<DateTime> onSpecialDayTapped;
  final ValueChanged<DateTime> onBlankDayTapped;

  const _Dashboard({
    super.key,
    required this.offices,
    required this.selected,
    required this.focusedDay,
    required this.calendarFormat,
    required this.onOfficeChanged,
    required this.onFormatChanged,
    required this.onPageChanged,
    required this.onManualCheckIn,
    required this.onPastDateCheckIn,
    required this.onSpecialDay,
    required this.onAttendanceDayTapped,
    required this.onSpecialDayTapped,
    required this.onBlankDayTapped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(attendanceProvider);
    final attended = ap.attendanceDates;
    final sp = ref.watch(specialDayProvider);
    final holidays = sp.holidayDates;
    final sickLeaves = sp.sickLeaveDates;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Office picker — only shown when more than one office exists.
        if (offices.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DropdownButtonFormField<OfficeLocation>(
              value: selected,
              decoration: const InputDecoration(
                labelText: 'Office',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: offices
                  .map((o) => DropdownMenuItem(value: o, child: Text(o.name)))
                  .toList(),
              onChanged: (o) {
                if (o != null) onOfficeChanged(o);
              },
            ),
          ),

        // Stats row
        _StatsRow(
          month: focusedDay,
          monthly: ap.monthlyCount,
          yearly: ap.yearlyCount,
          monthlyPercentage: ap.monthlyPercentage,
          yearlyPercentage: ap.yearlyPercentage,
        ),

        // Calendar
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          child: TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(DateTime.now().year + 5, 12, 31),
            focusedDay: focusedDay,
            calendarFormat: calendarFormat,
            onFormatChanged: onFormatChanged,
            onPageChanged: onPageChanged,
            selectedDayPredicate: (_) => false,
            onDaySelected: (selectedDay, _) {
              if (selectedDay.isAfter(DateTime.now())) return;
              if (attended.any((d) => isSameDay(d, selectedDay))) {
                onAttendanceDayTapped(selectedDay);
              } else if (holidays.any((d) => isSameDay(d, selectedDay)) ||
                  sickLeaves.any((d) => isSameDay(d, selectedDay))) {
                onSpecialDayTapped(selectedDay);
              } else {
                onBlankDayTapped(selectedDay);
              }
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, _) {
                if (attended.any((d) => isSameDay(d, day))) {
                  return _DayDot(day: day, color: AppColors.attendance);
                }
                if (holidays.any((d) => isSameDay(d, day))) {
                  return _DayDot(day: day, color: AppColors.holiday);
                }
                if (sickLeaves.any((d) => isSameDay(d, day))) {
                  return _DayDot(day: day, color: AppColors.sickLeave);
                }
                return null;
              },
              todayBuilder: (context, day, _) {
                if (attended.any((d) => isSameDay(d, day))) {
                  return _DayDot(day: day, color: AppColors.attendance, isToday: true);
                }
                if (holidays.any((d) => isSameDay(d, day))) {
                  return _DayDot(day: day, color: AppColors.holiday, isToday: true);
                }
                if (sickLeaves.any((d) => isSameDay(d, day))) {
                  return _DayDot(day: day, color: AppColors.sickLeave, isToday: true);
                }
                return null;
              },
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Office info chip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(selected.name),
              subtitle: Text(
                selected.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Chip(label: Text('${selected.radius.toInt()} m')),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Primary action
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            onPressed: onManualCheckIn,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Check-In for Today'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ),

        const SizedBox(height: 8),

        // Secondary actions side-by-side
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPastDateCheckIn,
                  icon: const Icon(Icons.history),
                  label: const Text('Past Date'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSpecialDay,
                  icon: const Icon(Icons.event_outlined),
                  label: const Text('Holiday / Sick'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Calendar legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _LegendChip(color: AppColors.attendance, label: 'Attended'),
              _LegendChip(color: AppColors.holiday, label: 'Public Holiday'),
              _LegendChip(color: AppColors.sickLeave, label: 'Sick Leave'),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final DateTime month;
  final int monthly;
  final int yearly;
  final double? monthlyPercentage;
  final double? yearlyPercentage;

  const _StatsRow({
    required this.month,
    required this.monthly,
    required this.yearly,
    this.monthlyPercentage,
    this.yearlyPercentage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: '${DateFormat.MMMM().format(month)} days',
              value: '$monthly',
              color: cs.primaryContainer,
              onColor: cs.onPrimaryContainer,
              icon: Icons.calendar_month_outlined,
              percentage: monthlyPercentage,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: '${month.year} total',
              value: '$yearly',
              color: cs.secondaryContainer,
              onColor: cs.onSecondaryContainer,
              icon: Icons.star_outline,
              percentage: yearlyPercentage,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color onColor;
  final IconData icon;
  final double? percentage;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.onColor,
    required this.icon,
    this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pctGood = (percentage ?? 0) >= 50;

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: onColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: onColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onColor.withValues(alpha: 0.8),
                    ),
                  ),
                  if (percentage != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: pctGood ? cs.primary : cs.error,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${percentage!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: pctGood ? cs.onPrimary : cs.onError,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Calendar day marker ───────────────────────────────────────────────────────

class _DayDot extends StatelessWidget {
  final DateTime day;
  final Color color;
  final bool isToday;

  const _DayDot({required this.day, required this.color, this.isToday = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // A contrasting white ring distinguishes "today" from past days.
        border: isToday
            ? Border.all(color: Colors.white, width: 2.5)
            : null,
        boxShadow: isToday
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4)]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
