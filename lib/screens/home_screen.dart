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
import '../providers/explain_provider.dart';
import '../providers/special_day_provider.dart';
import '../providers/ui_state_provider.dart';
import '../services/holiday_service.dart';
import '../themes/bird_art.dart';
import '../widgets/quick_mark_sheet.dart';
import '../widgets/rto_arc_card.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAttendance());
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

    final appBarTheme = Theme.of(context).appBarTheme;
    final birdAsset =
        birdAssetForTheme(ref.watch(settingsProvider.select((s) => s.themeId)));

    return Scaffold(
      appBar: AppBar(
        leading: birdAsset == null
            ? null
            : Padding(
                padding: const EdgeInsets.all(6),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Image.asset(birdAsset, fit: BoxFit.contain),
                  ),
                ),
              ),
        title: officeState.hasOffice
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance Register'),
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
            : const Text('Attendance Register'),
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: officeState.loading
            ? const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator(),
              )
            : !officeState.hasOffice
                ? _EmptyState(
                    key: const ValueKey('empty'),
                    birdAsset: birdAsset,
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
                    onRefresh: _onPullRefresh,
                    onOfficeChanged: (o) =>
                        ref.read(officeProvider.notifier).selectOffice(o),
                    onPageChanged: _onPageChanged,
                    onDayTapped: _quickMarkDay,
                  ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final String? birdAsset;
  const _EmptyState({super.key, required this.onAdd, this.birdAsset});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (birdAsset != null)
              Image.asset(birdAsset!, width: 180, fit: BoxFit.contain)
            else
              Icon(Icons.business_outlined,
                  size: 80, color: cs.primary.withValues(alpha: 0.4)),
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
  final Future<void> Function() onRefresh;
  final ValueChanged<OfficeLocation> onOfficeChanged;
  final ValueChanged<DateTime> onPageChanged;
  final ValueChanged<DateTime> onDayTapped;

  const _Dashboard({
    super.key,
    required this.offices,
    required this.selected,
    required this.onRefresh,
    required this.onOfficeChanged,
    required this.onPageChanged,
    required this.onDayTapped,
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
      // No marker and not today → let table_calendar draw its default number.
      if (!isToday && status == null) return null;
      return _DayCell(day: day, status: status, isToday: isToday);
    }

    // The yearly stat follows the configured reporting year (calendar or
    // financial), labelled accordingly ("2026" / "FY 2025–2026").
    final yearPeriod = ReportPeriod(
      kind: PeriodKind.year,
      anchor: focusedDay,
      financialYearStart: settings.financialYearStart,
    );
    final yearBreakdown = ref.watch(breakdownProvider((
      officeId: selected.id!,
      start: yearPeriod.start,
      end: yearPeriod.end,
    )));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          // Office picker — only shown when more than one office exists.
          if (offices.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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

          // Calendar — the home page leads with the month, statuses shown as
          // icons/markers inside each day cell (Monday-first week).
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            clipBehavior: Clip.antiAlias,
            child: TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(DateTime.now().year + 5, 12, 31),
              focusedDay: focusedDay,
              calendarFormat: calendarFormat,
              startingDayOfWeek: StartingDayOfWeek.monday,
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
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Status legend in its own card so colours/icons never need to be
          // memorised (accessibility: icon + label + colour).
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _LegendCard(),
          ),

          const SizedBox(height: 12),

          // Return-to-office hero — same gauge as the Insights tab, for the
          // current reporting year. Tapping it opens the full Insights tab.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: yearBreakdown.when(
              loading: () => const Card(
                margin: EdgeInsets.zero,
                child: SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('Could not load summary: $e')),
                ),
              ),
              data: (b) => RtoArcCard(
                breakdown: b,
                target: settings.rtoTarget,
                birdAsset: birdAssetForTheme(settings.themeId),
                onTap: () => ref.read(tabIndexProvider.notifier).set(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Calendar day cell ─────────────────────────────────────────────────────────

/// A single calendar day rendered per the Feathers spec:
/// • today           → solid navy (primary) circle with the day number
/// • attended        → solid green circle with the day number
/// • sick leave      → orange outlined ring with the day number
/// • other statuses  → the status' icon in its colour (WFH home, holiday
///   umbrella, annual suitcase, carer's hands, misc dots)
/// • no status       → the plain day number
class _DayCell extends StatelessWidget {
  final DateTime day;
  final DayStatus? status;
  final bool isToday;

  const _DayCell({required this.day, required this.status, this.isToday = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final number = '${day.day}';
    final s = status;

    Widget filled(Color bg, Color fg) => Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(number,
              style: TextStyle(
                  color: fg, fontWeight: FontWeight.bold, fontSize: 14)),
        );

    // The marker for a given status (no "today" treatment).
    Widget markerFor(DayStatus st) {
      if (st == DayStatus.attended) {
        return filled(st.colorIn(context), Colors.white);
      }
      if (st == DayStatus.sickLeave) {
        final color = st.colorIn(context);
        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(number,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        );
      }
      // Leave / WFH / holiday / misc — show the status icon (no number).
      return Center(child: Icon(st.icon, color: st.colorIn(context), size: 22));
    }

    if (isToday) {
      // Today keeps its real status visible; a primary ring marks it as today.
      // With no status it's just the solid "today" circle.
      if (s == null) return filled(cs.primary, cs.onPrimary);
      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.primary, width: 2),
              ),
            ),
          ),
          markerFor(s),
        ],
      );
    }

    // Non-today days: the builder returns null for empty days, so a status is
    // present here — but keep a safe fallback to the plain number.
    if (s == null) {
      return Center(
        child: Text(number, style: const TextStyle(fontSize: 14)),
      );
    }
    return markerFor(s);
  }
}

// ── Calendar legend ───────────────────────────────────────────────────────────

class _LegendCard extends StatelessWidget {
  const _LegendCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            for (final s in DayStatus.values)
              _LegendItem(icon: s.icon, color: s.colorIn(context), label: s.label),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _LegendItem({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
