import 'dart:async';

import 'package:animations/animations.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../providers/ui_state_provider.dart';
import '../services/holiday_service.dart';
import '../widgets/quick_mark_sheet.dart';
import 'day_entry_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 1200));
  bool _justCheckedIn = false;
  Timer? _checkedInReset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAttendance());
  }

  @override
  void dispose() {
    _checkedInReset?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  /// Reloads attendance and special days for [day]'s month (defaults to the
  /// focused month).
  void _refreshAttendance([DateTime? day]) {
    // Read into a local first: inside `day ?? read(...)` the nullable context
    // type would win generic inference and make the result DateTime?.
    final focused = ref.read(calendarFocusProvider);
    final target = day ?? focused;
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
    ref.read(calendarFocusProvider.notifier).set(day);
    _refreshAttendance(day);
  }

  Future<void> _onPullRefresh() async {
    final inserted = await HolidayService.instance.sync();
    if (!mounted) return;
    _refreshAttendance();
    if (inserted > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $inserted public holiday${inserted == 1 ? '' : 's'}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Tapping a calendar day opens the quick-mark sheet (one-tap statuses);
  /// "All options" inside it escalates to the full day-entry screen.
  Future<void> _quickMarkDay(DateTime day) async {
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    final changed = await showQuickMarkSheet(context, office: office, date: day);
    if (changed && mounted) _refreshAttendance();
  }

  Future<void> _manualCheckIn() async {
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    final result = await ref
        .read(attendanceProvider.notifier)
        .manualCheckIn(office.id!, focusedMonth: ref.read(calendarFocusProvider));
    if (!mounted) return;

    if (result == CheckInResult.recorded) {
      // The once-a-day moment the app exists for — celebrate it.
      unawaited(HapticFeedback.mediumImpact());
      _confetti.play();
      setState(() => _justCheckedIn = true);
      _checkedInReset?.cancel();
      _checkedInReset = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _justCheckedIn = false);
      });
    }

    final msg = switch (result) {
      CheckInResult.recorded => 'Attendance recorded for today!',
      CheckInResult.alreadyRecorded => 'Already checked in for today.',
      CheckInResult.alreadyRecordedByAuto =>
        'Attendance already recorded by auto check-in.',
      CheckInResult.specialDayConflict =>
        'Today is already marked (holiday, sick leave or misc leave) — change it first.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final officeState = ref.watch(officeProvider);

    // Reload when the selected office first arrives or changes (startup load
    // completes after this widget mounts), and when the financial-year setting
    // changes the yearly window.
    ref.listen(
      officeProvider.select((s) => s.selectedOffice?.id),
      (previous, next) {
        if (next != null && previous != next) _refreshAttendance();
      },
    );
    ref.listen(
      settingsProvider.select((s) => s.financialYearStart),
      (previous, next) {
        if (previous != next) _refreshAttendance();
      },
    );

    final cs = Theme.of(context).colorScheme;
    final appBarTheme = Theme.of(context).appBarTheme;

    return Scaffold(
      appBar: AppBar(
        title: officeState.hasOffice
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Office Attendance'),
                  Text(
                    officeState.selectedOffice!.name,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      // App bar foreground is onPrimary in light mode (navy bar);
                      // tint it down a touch for the secondary line.
                      color: appBarTheme.foregroundColor?.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              )
            : const Text('Office Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              appRoute(const SettingsScreen()),
            ).then((_) async {
              await ref.read(officeProvider.notifier).load();
              if (mounted) _refreshAttendance();
            }),
          ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: officeState.loading
                ? const Center(
                    key: ValueKey('loading'),
                    child: CircularProgressIndicator(),
                  )
                : !officeState.hasOffice
                    ? _EmptyState(
                        key: const ValueKey('empty'),
                        onAdd: () => Navigator.push(
                          context,
                          appRoute(const SetupScreen()),
                        ).then((_) async {
                          await ref.read(officeProvider.notifier).load();
                          if (mounted) _refreshAttendance();
                        }),
                      )
                    : _Dashboard(
                        key: ValueKey(officeState.selectedOffice?.id),
                        offices: officeState.offices,
                        selected: officeState.selectedOffice!,
                        justCheckedIn: _justCheckedIn,
                        onRefresh: _onPullRefresh,
                        onOfficeChanged: (o) =>
                            ref.read(officeProvider.notifier).selectOffice(o),
                        onPageChanged: _onPageChanged,
                        onManualCheckIn: _manualCheckIn,
                        onDayTapped: _quickMarkDay,
                        onMarkADayClosed: (changed) {
                          if (changed == true) _refreshAttendance();
                        },
                      ),
          ),
          // Confetti bursts from the top on a successful check-in.
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 24,
              maxBlastForce: 24,
              minBlastForce: 8,
              gravity: 0.25,
              shouldLoop: false,
              colors: [
                cs.primary,
                cs.secondary,
                cs.tertiary,
                DayStatus.attended.colorIn(context),
              ],
            ),
          ),
        ],
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
  final bool justCheckedIn;
  final Future<void> Function() onRefresh;
  final ValueChanged<OfficeLocation> onOfficeChanged;
  final ValueChanged<DateTime> onPageChanged;
  final VoidCallback onManualCheckIn;
  final ValueChanged<DateTime> onDayTapped;
  final ValueChanged<bool?> onMarkADayClosed;

  const _Dashboard({
    super.key,
    required this.offices,
    required this.selected,
    required this.justCheckedIn,
    required this.onRefresh,
    required this.onOfficeChanged,
    required this.onPageChanged,
    required this.onManualCheckIn,
    required this.onDayTapped,
    required this.onMarkADayClosed,
  });

  static final _dayKeyFmt = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(attendanceProvider);
    final sp = ref.watch(specialDayProvider);
    final settings = ref.watch(settingsProvider);
    final focusedDay = ref.watch(calendarFocusProvider);
    final calendarFormat = ref.watch(calendarFormatProvider);

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
      return _DayDot(
        day: day,
        color: status.colorIn(context),
        isToday: isToday,
      );
    }

    // The yearly stat follows the configured reporting year (calendar or
    // financial), labelled accordingly ("2026" / "FY 2025–2026").
    final yearPeriod = ReportPeriod(
      kind: PeriodKind.year,
      anchor: focusedDay,
      financialYearStart: settings.financialYearStart,
    );

    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Office picker — only shown when more than one office exists.
          if (offices.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: DropdownButtonFormField<OfficeLocation>(
                initialValue: selected,
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

          // Stats row — tapping a card jumps to the Insights tab.
          _StatsRow(
            month: focusedDay,
            yearLabel: yearPeriod.label,
            monthly: ap.monthlyCount,
            yearly: ap.yearlyCount,
            monthlyPercentage: ap.monthlyPercentage,
            yearlyPercentage: ap.yearlyPercentage,
            target: settings.rtoTarget,
            onTap: () => ref.read(tabIndexProvider.notifier).set(1),
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
              // constant across months — paging between a 5-row and 6-row
              // month would otherwise resize everything below it.
              sixWeekMonthsEnforced: true,
              onFormatChanged: (f) =>
                  ref.read(calendarFormatProvider.notifier).set(f),
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
                  color: cs.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Primary action — morphs into a confirmation for a moment after a
          // successful check-in.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: onManualCheckIn,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  justCheckedIn ? Icons.celebration : Icons.check_circle_outline,
                  key: ValueKey(justCheckedIn),
                ),
              ),
              label: Text(justCheckedIn ? 'Checked in!' : 'Check-In for Today'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),

          const SizedBox(height: 8),

          // Secondary action — container-transforms into the full day-entry
          // screen. Tapping a calendar day opens the quick sheet instead.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OpenContainer<bool>(
              transitionType: ContainerTransitionType.fadeThrough,
              transitionDuration: const Duration(milliseconds: 350),
              closedElevation: 0,
              closedColor: cs.surface,
              closedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: cs.outline),
              ),
              closedBuilder: (context, open) => InkWell(
                onTap: open,
                child: SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_calendar_outlined, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Mark a Day (Attendance / Leave / WFH)',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              openBuilder: (context, _) => DayEntryScreen(office: selected),
              onClosed: onMarkADayClosed,
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
                  _LegendChip(color: s.colorIn(context), label: s.label),
              ],
            ),
          ),
        ],
      ),
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
  final VoidCallback onTap;

  const _StatsRow({
    required this.month,
    required this.yearLabel,
    required this.monthly,
    required this.yearly,
    required this.target,
    required this.onTap,
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
              value: monthly,
              percentage: monthlyPercentage,
              target: target,
              color: cs.primaryContainer,
              onColor: cs.onPrimaryContainer,
              icon: Icons.calendar_month_outlined,
              onTap: onTap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: yearLabel,
              value: yearly,
              percentage: yearlyPercentage,
              target: target,
              color: cs.secondaryContainer,
              onColor: cs.onSecondaryContainer,
              icon: Icons.star_outline,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final double? percentage;
  final int target;
  final Color color;
  final Color onColor;
  final IconData icon;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.percentage,
    required this.target,
    required this.color,
    required this.onColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pctGood = (percentage ?? 0) >= target;

    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                  // Animated count-up; tabular figures in the theme keep the
                  // digits from jiggling as they change.
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: value),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      '$v',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: onColor,
                        height: 1,
                      ),
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
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
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (percentage! / 100).clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: v,
                      backgroundColor: onColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(
                        pctGood ? cs.primary : cs.error,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ],
          ),
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
    // Subtle scale/fade-in when a month's dots appear.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
      ),
      child: Container(
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
