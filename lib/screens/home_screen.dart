import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../helpers/day_type_helper.dart';
import '../helpers/route_helper.dart';
import '../models/office_location.dart';
import '../models/report_period.dart';
import '../models/special_day.dart';
import '../providers/attendance_provider.dart';
import '../providers/office_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/special_day_provider.dart';
import '../services/holiday_service.dart';
import '../services/location_service.dart';
import 'day_entry_screen.dart';
import 'explain_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _foregroundCheckRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The background WorkManager task writes attendance to the database from a
    // separate isolate, so the foreground snapshot held by attendanceProvider
    // goes stale while the app is backgrounded. Re-read from disk on resume so
    // the calendar reflects anything recorded automatically while we were away.
    if (state == AppLifecycleState.resumed) {
      _refreshAttendance();
      unawaited(_foregroundCheckIn());
    }
  }

  Future<void> _init() async {
    await ref.read(officeProvider.notifier).load();
    _refreshAttendance();
    // Pull public holidays for the registered office's region in the background
    // and refresh the calendar if any new ones were inserted. Never blocks the
    // first paint and silently no-ops when offline.
    unawaited(_syncHolidays());
    unawaited(_foregroundCheckIn());
  }

  Future<void> _syncHolidays() async {
    final inserted = await HolidayService.instance.sync();
    if (inserted > 0 && mounted) _refreshAttendance();
  }

  /// Safety net for the 15-minute background task (which the OS may have
  /// killed): if the user opens the app while standing in the office, record
  /// today on the spot. Never prompts for permission and never runs twice
  /// concurrently.
  Future<void> _foregroundCheckIn() async {
    if (_foregroundCheckRunning) return;
    _foregroundCheckRunning = true;
    try {
      final office = await LocationService.performForegroundCheck();
      if (office == null || !mounted) return;
      _refreshAttendance();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "You're at ${office.name} — attendance recorded for today.",
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      _foregroundCheckRunning = false;
    }
  }

  /// Reloads attendance and special days for [day]'s month (defaults to the
  /// focused month).
  void _refreshAttendance([DateTime? day]) {
    final target = day ?? _focusedDay;
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    ref.read(attendanceProvider.notifier).loadForMonth(
      office.id!,
      target.year,
      target.month,
    );
    ref.read(specialDayProvider.notifier).loadForMonth(
      target.year,
      target.month,
    );
  }

  void _onPageChanged(DateTime day) {
    setState(() => _focusedDay = day);
    _refreshAttendance(day);
  }

  /// Opens the unified day-entry screen for [initialDate] (defaults to today).
  Future<void> _openDayEntry({DateTime? initialDate}) async {
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    final changed = await Navigator.push<bool>(
      context,
      slideRoute(DayEntryScreen(office: office, initialDate: initialDate)),
    );
    if (changed == true && mounted) _refreshAttendance();
  }

  @override
  Widget build(BuildContext context) {
    final officeState = ref.watch(officeProvider);

    // The yearly stat window depends on the financial-year setting (changed on
    // the Explain page, loaded asynchronously at startup) — reload when it
    // changes so the dashboard never shows a stale window.
    ref.listen(
      settingsProvider.select((s) => s.financialYearStart),
      (previous, next) {
        if (previous != next) _refreshAttendance();
      },
    );

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: officeState.hasOffice ? cs.primary : null,
        title: officeState.hasOffice
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Office Attendance'),
                  Text(
                    officeState.selectedOffice!.name,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              )
            : const Text('Office Attendance'),
        actions: [
          if (officeState.hasOffice) ...[
            IconButton(
              icon: const Icon(Icons.insights_outlined),
              tooltip: 'Explain',
              onPressed: () => Navigator.push(
                context,
                slideRoute(
                  ExplainScreen(office: officeState.selectedOffice!),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'History',
              onPressed: () => Navigator.push(
                context,
                slideRoute(
                  HistoryScreen(office: officeState.selectedOffice!),
                ),
              ).then((_) => _refreshAttendance()),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              slideRoute(const SettingsScreen()),
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
                      slideRoute(const SetupScreen()),
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
                          .manualCheckIn(officeId, focusedMonth: _focusedDay);
                      if (!context.mounted) return;
                      final msg = switch (result) {
                        CheckInResult.recorded => 'Attendance recorded for today!',
                        CheckInResult.alreadyRecorded => 'Already checked in for today.',
                        CheckInResult.alreadyRecordedByAuto =>
                          'Attendance already recorded by auto check-in.',
                        CheckInResult.specialDayConflict =>
                          'Today is already marked (holiday, sick leave or misc leave) — change it first.',
                      };
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    onMarkADay: () => _openDayEntry(),
                    onDayTapped: (day) => _openDayEntry(initialDate: day),
                  ),
      ),
    );
  }
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
  final VoidCallback onMarkADay;
  final ValueChanged<DateTime> onDayTapped;

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
    required this.onMarkADay,
    required this.onDayTapped,
  });

  static final _dayKeyFmt = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(attendanceProvider);
    final sp = ref.watch(specialDayProvider);
    final settings = ref.watch(settingsProvider);

    // O(1) status lookup per calendar cell. Attendance wins over a special day
    // (matching the precedence used everywhere else).
    final attendedKeys = ap.attendanceDateKeys;
    final specialTypes = sp.typeByDate;
    DayStatus? statusFor(DateTime day) {
      final key = _dayKeyFmt.format(day);
      if (attendedKeys.contains(key)) return DayStatus.attended;
      return specialTypes[key]?.dayStatus;
    }

    Widget? dayCell(DateTime day, {required bool isToday}) {
      final status = statusFor(day);
      if (status == null) return null;
      return _DayDot(day: day, color: status.color, isToday: isToday);
    }

    // The yearly stat follows the configured reporting year (calendar or
    // financial), labelled accordingly ("2026" / "FY 2025–2026").
    final yearPeriod = ReportPeriod(
      kind: PeriodKind.year,
      anchor: focusedDay,
      financialYearStart: settings.financialYearStart,
    );

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
          yearLabel: yearPeriod.label,
          monthly: ap.monthlyCount,
          yearly: ap.yearlyCount,
          monthlyPercentage: ap.monthlyPercentage,
          yearlyPercentage: ap.yearlyPercentage,
          target: settings.rtoTarget,
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
            // Always render six week-rows so the calendar's height stays
            // constant across months. Without this, months that span only
            // five weeks are shorter, and paging between a 5-row and a 6-row
            // month resizes the calendar — shoving everything below it up and
            // down (the "flickering" the user sees).
            sixWeekMonthsEnforced: true,
            onFormatChanged: onFormatChanged,
            onPageChanged: onPageChanged,
            selectedDayPredicate: (_) => false,
            onDaySelected: (selectedDay, _) {
              if (selectedDay.isAfter(DateTime.now())) return;
              onDayTapped(selectedDay);
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, _) => dayCell(day, isToday: false),
              todayBuilder: (context, day, _) => dayCell(day, isToday: true),
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

        // Secondary action — one screen handles attendance, holiday & sick leave
        // for any past date or today. Tapping a calendar day opens it too.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: onMarkADay,
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Mark a Day (Attendance / Leave / WFH)'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Calendar legend — centered.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final s in DayStatus.values)
                _LegendChip(color: s.color, label: s.label),
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
  final String yearLabel;
  final int monthly;
  final int yearly;
  final double? monthlyPercentage;
  final double? yearlyPercentage;
  final int target;

  const _StatsRow({
    required this.month,
    required this.yearLabel,
    required this.monthly,
    required this.yearly,
    required this.target,
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
              label: DateFormat.MMMM().format(month),
              value: '$monthly',
              percentage: monthlyPercentage,
              target: target,
              color: cs.primaryContainer,
              onColor: cs.onPrimaryContainer,
              icon: Icons.calendar_month_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: yearLabel,
              value: '$yearly',
              percentage: yearlyPercentage,
              target: target,
              color: cs.secondaryContainer,
              onColor: cs.onSecondaryContainer,
              icon: Icons.star_outline,
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
  final double? percentage;
  final int target;
  final Color color;
  final Color onColor;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.percentage,
    required this.target,
    required this.color,
    required this.onColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (percentage ?? 0) / 100;
    final pctGood = (percentage ?? 0) >= target;

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: onColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: onColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'days',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const Spacer(),
                if (percentage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pctGood ? cs.primary : cs.error,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${percentage!.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: pctGood ? cs.onPrimary : cs.onError,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            if (percentage != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  backgroundColor: onColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(
                    pctGood ? cs.primary : cs.error,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
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
