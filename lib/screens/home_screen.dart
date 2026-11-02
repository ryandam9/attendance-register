import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../helpers/day_marking.dart';
import '../helpers/day_type_helper.dart';
import '../helpers/layout.dart';
import '../helpers/route_helper.dart';
import '../models/attendance_breakdown.dart';
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
import '../widgets/garden_art.dart';
import '../widgets/garden_header.dart';
import '../widgets/garden_tag.dart';
import '../widgets/check_in_celebration.dart';
import '../widgets/quick_mark_sheet.dart';
import '../widgets/responsive_body.dart';
import '../widgets/rto_arc_card.dart';
import '../widgets/stat_card.dart';
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
    ref
        .read(attendanceProvider.notifier)
        .loadForMonth(office.id!, target.year, target.month);
    ref
        .read(specialDayProvider.notifier)
        .loadForMonth(target.year, target.month);
    // The dashboard's return-to-office gauge, work-style donut, KPI cards and
    // 8-week trend read the breakdown straight from the database, so reloading
    // the month providers above doesn't refresh them — invalidate them so they
    // recompute after a day is marked or edited.
    ref.invalidate(breakdownProvider);
    ref.invalidate(weeklyTrendProvider);
  }

  void _onPageChanged(DateTime day) {
    ref.read(calendarFocusProvider.notifier).set(day);
    _refreshAttendance(day);
  }

  Future<void> _onPullRefresh() async {
    final inserted = (await HolidayService.instance.sync()).inserted;
    if (!mounted) return;
    _refreshAttendance();
    if (inserted > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added $inserted public holiday${inserted == 1 ? '' : 's'}.',
          ),
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
    final changed = await showQuickMarkSheet(
      context,
      office: office,
      date: day,
    );
    if (changed && mounted) _refreshAttendance();
  }

  Future<void> _addOffice() async {
    await openAdaptivePage<void>(context, const SetupScreen());
    if (!mounted) return;
    await ref.read(officeProvider.notifier).load();
    if (mounted) _refreshAttendance();
  }

  Future<void> _manualCheckIn() async {
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    final result = await ref
        .read(attendanceProvider.notifier)
        .manualCheckIn(office.id!, focusedMonth: DateTime.now());
    if (!mounted) return;

    if (result == CheckInResult.recorded) {
      _refreshAttendance(DateTime.now());
      unawaited(
        showCheckInCelebration(
          context,
          officeName: office.name,
          date: DateTime.now(),
        ),
      );
      return;
    }

    final message = switch (result) {
      CheckInResult.alreadyRecorded ||
      CheckInResult.alreadyRecordedByAuto => 'Today is already recorded.',
      CheckInResult.specialDayConflict =>
        'Today already has a status. Edit it before checking in.',
      CheckInResult.weekend => weekendNotMarkableMessage,
      CheckInResult.recorded => '',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final officeState = ref.watch(officeProvider);

    // Reload when the selected office first arrives or changes (startup load
    // completes after this widget mounts), and when the financial-year setting
    // changes the yearly window.
    ref.listen(officeProvider.select((s) => s.selectedOffice?.id), (
      previous,
      next,
    ) {
      if (next != null && previous != next) _refreshAttendance();
    });
    ref.listen(settingsProvider.select((s) => s.financialYearStart), (
      previous,
      next,
    ) {
      if (previous != next) _refreshAttendance();
    });

    // Hold the dashboard back until today's status, the month's days and its
    // progress have all loaded, then show everything at once. Otherwise each
    // card pops in or changes size as its data arrives.
    final office = officeState.selectedOffice;
    var ready = false;
    if (!officeState.loading && office != null) {
      final args = _homeMonthArgs(ref, office.id!);
      ref.listen(breakdownProvider(args), (_, next) {
        if (next.hasValue) {
          ref.read(_lastMonthBreakdownProvider.notifier).set(next.value);
        }
      });
      final loadedOffice = ref.watch(
        attendanceProvider.select((s) => s.loadedOfficeId),
      );
      final daysLoaded = ref.watch(
        specialDayProvider.select((s) => s.hasLoaded),
      );
      final breakdown = ref.watch(breakdownProvider(args));
      final hadBreakdown = ref.watch(_lastMonthBreakdownProvider) != null;
      ready =
          loadedOffice == office.id &&
          daysLoaded &&
          (breakdown.hasValue || breakdown.hasError || hadBreakdown);
    }

    // Desktop: a two-pane dashboard that fills the window. The navigation shell
    // supplies the sidebar, so this screen has no app bar of its own. The
    // loading and "no office" states fall through to the single-column layout.
    if (isDesktopWidth(context) && ready) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: _DesktopDashboard(
          selected: officeState.selectedOffice!,
          offices: officeState.offices,
          onOfficeChanged: (o) =>
              ref.read(officeProvider.notifier).selectOffice(o),
          onPageChanged: _onPageChanged,
          onDayTapped: _quickMarkDay,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        // Today's date, in the same spaced capitals as the garden headers.
        title: Text(
          DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ResponsiveBody(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: officeState.loading
              ? const _DelayedSpinner(key: ValueKey('loading'))
              : !officeState.hasOffice
              ? _EmptyState(key: const ValueKey('empty'), onAdd: _addOffice)
              : !ready
              ? const _DelayedSpinner(key: ValueKey('loading'))
              : _Dashboard(
                  key: ValueKey(officeState.selectedOffice?.id),
                  offices: officeState.offices,
                  selected: officeState.selectedOffice!,
                  onRefresh: _onPullRefresh,
                  onOfficeChanged: (o) =>
                      ref.read(officeProvider.notifier).selectOffice(o),
                  onPageChanged: _onPageChanged,
                  onDayTapped: _quickMarkDay,
                  onCheckIn: _manualCheckIn,
                ),
        ),
      ),
    );
  }
}

/// The focused month's breakdown request for [officeId], shared by the
/// loading check and the dashboards so they always ask for the same thing.
BreakdownArgs _homeMonthArgs(WidgetRef ref, int officeId) {
  final period = ReportPeriod(
    kind: PeriodKind.month,
    anchor: ref.watch(calendarFocusProvider),
    financialYearStart: ref.watch(
      settingsProvider.select((s) => s.financialYearStart),
    ),
  );
  return (officeId: officeId, start: period.start, end: period.end);
}

/// The last month progress the home page showed, kept so returning to Home
/// or swiping months shows the previous numbers instead of a spinner.
class _LastMonthBreakdown extends Notifier<AttendanceBreakdown?> {
  @override
  AttendanceBreakdown? build() => null;
  void set(AttendanceBreakdown? value) => state = value;
}

final _lastMonthBreakdownProvider =
    NotifierProvider<_LastMonthBreakdown, AttendanceBreakdown?>(
      _LastMonthBreakdown.new,
    );

/// A spinner that only appears if loading takes a noticeable time, so quick
/// loads don't flash it on and off.
class _DelayedSpinner extends StatefulWidget {
  const _DelayedSpinner({super.key});

  @override
  State<_DelayedSpinner> createState() => _DelayedSpinnerState();
}

class _DelayedSpinnerState extends State<_DelayedSpinner> {
  bool _show = false;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(
      const Duration(milliseconds: 400),
      () => setState(() => _show = true),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: _show ? const CircularProgressIndicator() : const SizedBox.shrink(),
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget feature(IconData icon, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          GardenIconTile(color: cs.primary, icon: icon),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: text.bodyLarge)),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const GardenHeader(
          eyebrow: 'Attendance Register',
          title: 'A little presence. A little growth.',
        ),
        const SizedBox(height: 20),
        const GardenArt(),
        const SizedBox(height: 20),
        Text('Make room for your workday.', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Keep your office days, time at home and leave in one peaceful '
          'place.',
          style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        feature(Icons.check_circle_outline, 'A clear view of your attendance'),
        feature(
          Icons.my_location_outlined,
          'Automatic check-in, if you choose',
        ),
        feature(
          Icons.track_changes_outlined,
          'Progress towards your own target',
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onAdd,
          child: const Text('Add your first office'),
        ),
        const SizedBox(height: 8),
        Text(
          'Start with an office name. Set up location later.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
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
  final Future<void> Function() onCheckIn;

  const _Dashboard({
    super.key,
    required this.offices,
    required this.selected,
    required this.onRefresh,
    required this.onOfficeChanged,
    required this.onPageChanged,
    required this.onDayTapped,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(attendanceProvider);
    final settings = ref.watch(settingsProvider);
    final focusedDay = ref.watch(calendarFocusProvider);

    // Home shows the return-to-office gauge for the focused month.
    final monthPeriod = ReportPeriod(
      kind: PeriodKind.month,
      anchor: focusedDay,
      financialYearStart: settings.financialYearStart,
    );
    final monthBreakdown = ref.watch(
      breakdownProvider(_homeMonthArgs(ref, selected.id!)),
    );
    // While a newly swiped-to month loads, keep the last numbers on screen
    // rather than flashing a spinner.
    final shownBreakdown =
        monthBreakdown.value ?? ref.watch(_lastMonthBreakdownProvider);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your month, gently growing.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 20),
                const GardenArt(),
              ],
            ),
          ),
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: offices
                    .map((o) => DropdownMenuItem(value: o, child: Text(o.name)))
                    .toList(),
                onChanged: (o) {
                  if (o != null) onOfficeChanged(o);
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _MobileTodayCard(
              // From today's own record, not the focused month's: paging the
              // calendar must not change what "Today" says.
              status: ap.todayStatus,
              checkInTime: ap.todayCheckInTime,
              onCheckIn: onCheckIn,
              onEdit: () => onDayTapped(DateTime.now()),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 112),
              child: shownBreakdown == null && monthBreakdown.hasError
                  ? Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Could not load month progress: '
                            '${monthBreakdown.error}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    )
                  : shownBreakdown == null
                  ? const Card(margin: EdgeInsets.zero)
                  : _MobileProgressCard(
                      breakdown: shownBreakdown,
                      target: settings.rtoTarget,
                      periodLabel: monthPeriod.label,
                      onTap: () => ref.read(tabIndexProvider.notifier).set(1),
                    ),
            ),
          ),

          // Calendar — the home page leads with the month, statuses shown as
          // icons/markers inside each day cell (Monday-first week), with this
          // month's key underneath.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _CalendarCard(
              onPageChanged: onPageChanged,
              onDayTapped: onDayTapped,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileTodayCard extends StatelessWidget {
  final DayStatus? status;
  final DateTime? checkInTime;
  final Future<void> Function() onCheckIn;
  final VoidCallback onEdit;

  const _MobileTodayCard({
    required this.status,
    required this.checkInTime,
    required this.onCheckIn,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = status?.colorIn(context) ?? cs.primary;
    final recorded = status != null;
    final title = switch (status) {
      null => 'Where are you today?',
      DayStatus.attended => 'At the office',
      final s => s.label,
    };
    final subtitle = switch (status) {
      null => null,
      DayStatus.attended when checkInTime != null =>
        'Checked in at ${DateFormat('h:mm a').format(checkInTime!)}',
      DayStatus.attended => null,
      _ => 'Tap to change',
    };
    final tag = recorded
        ? const GardenTag('Recorded', icon: Icons.check)
        : const GardenTag('Not recorded', muted: true);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      // Checking in shrinks the card; ease that rather than jump.
      child: AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: InkWell(
          // Once recorded, the whole card is the way to change today.
          onTap: recorded ? onEdit : null,
          child: Semantics(
            button: recorded,
            hint: recorded ? 'Edit today' : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // With large text on a narrow phone the tag drops under the
                  // title, and the two buttons stack.
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final roomy = constraints.maxWidth / scale >= 260;
                  final heading = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // The page header above already gives the date.
                        'TODAY',
                        style: text.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: text.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      if (!roomy) ...[const SizedBox(height: 6), tag],
                    ],
                  );
                  // Tighter sides so both labels fit on one line side by side.
                  const pad = EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  );
                  final checkIn = FilledButton.icon(
                    style: FilledButton.styleFrom(padding: pad),
                    onPressed: onCheckIn,
                    icon: const Icon(Icons.apartment, size: 18),
                    label: const Text('Check in'),
                  );
                  final other = OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: pad),
                    onPressed: onEdit,
                    icon: const Icon(Icons.home_work_outlined, size: 18),
                    label: const Text('Home or leave'),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GardenIconTile(
                            color: color,
                            icon: status == DayStatus.attended
                                ? Icons.check
                                : status?.icon ?? Icons.today_outlined,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: heading),
                          if (roomy) ...[const SizedBox(width: 8), tag],
                        ],
                      ),
                      if (!recorded) ...[
                        const SizedBox(height: 14),
                        if (roomy)
                          Row(
                            children: [
                              Expanded(child: checkIn),
                              const SizedBox(width: 8),
                              Expanded(child: other),
                            ],
                          )
                        else ...[
                          checkIn,
                          const SizedBox(height: 8),
                          other,
                        ],
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileProgressCard extends StatelessWidget {
  final AttendanceBreakdown breakdown;
  final int target;
  final String periodLabel;
  final VoidCallback onTap;

  const _MobileProgressCard({
    required this.breakdown,
    required this.target,
    required this.periodLabel,
    required this.onTap,
  });

  /// The line under the title: what is still needed, or — once the target can
  /// no longer be reached — how the period ended. A month that is over cannot
  /// take "5 more office days", so it reports the outcome instead.
  String _subtitle(double? pct) {
    if (pct == null) return 'No eligible working days yet';
    final needed = breakdown.officeDaysToTarget(target);
    if (needed == 0) return 'Target met';
    if (breakdown.targetReachable(target)) {
      return '$needed more office ${needed == 1 ? 'day' : 'days'} '
          'to reach $target%';
    }
    if (breakdown.isFinal) return 'Did not reach $target%';
    return '$target% is out of reach';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = breakdown.returnToOfficePercentage;
    final progress = ((pct ?? 0) / 100).clamp(0.0, 1.0);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Return to office · $periodLabel',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          _subtitle(pct),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    // Reserve room for values from “—” through “100%” so the
                    // text column does not resize as months change.
                    width: MediaQuery.textScalerOf(context).scale(64),
                    child: Text(
                      pct == null ? '—' : '${pct.round()}%',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            // Numbers use the body font, even when
                            // headings are serif.
                            fontFamily: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.fontFamily,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: cs.primary,
                          ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                label: pct == null
                    ? 'No return to office percentage available'
                    : 'Return to office ${pct.toStringAsFixed(1)} percent, target $target percent',
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Calendar day cell ─────────────────────────────────────────────────────────

/// A single calendar day rendered per the Feathers spec:
/// • today           → solid navy (primary) circle with the day number
/// • attended        → solid green circle with the day number
/// • other statuses  → the status' icon in its colour (sick face, WFH home,
///   holiday umbrella, annual suitcase, carer's hands, misc dots)
/// • no status       → the plain day number
class _DayCell extends StatelessWidget {
  final DateTime day;
  final DayStatus? status;
  final bool isToday;

  const _DayCell({
    required this.day,
    required this.status,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final number = '${day.day}';
    final s = status;

    Widget filled(Color bg, Color fg) => Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        number,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );

    // The marker for a given status (no "today" treatment).
    Widget markerFor(DayStatus st) {
      if (st == DayStatus.attended) {
        final bg = st.colorIn(context);
        return filled(bg, _numberColorOn(bg));
      }
      // Sick / leave / WFH / holiday / misc — show the status icon.
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
      return Center(child: Text(number, style: const TextStyle(fontSize: 14)));
    }
    return markerFor(s);
  }
}

// ── Calendar key ──────────────────────────────────────────────────────────────

/// The number colour that stays readable on a filled day circle: the attended
/// green is dark in light mode but a light lime in dark mode.
Color _numberColorOn(Color fill) =>
    ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
    ? Colors.white
    : const Color(0xFF1B2A12);

/// A small copy of how [status] looks in the calendar, so the key matches the
/// grid exactly. With no status it shows today's circle; with [ring] it shows
/// the ring that marks today once it's recorded.
class _StatusSwatch extends StatelessWidget {
  final DayStatus? status;
  final bool ring;
  const _StatusSwatch(this.status, {this.ring = false});

  static const size = 24.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = status;
    Widget circle(Color fill) => Container(
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '8',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: _numberColorOn(fill),
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
    final Widget mark;
    if (ring) {
      mark = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: cs.primary, width: 2),
        ),
      );
    } else if (s == null) {
      mark = Container(
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
      );
    } else if (s == DayStatus.attended) {
      mark = circle(s.colorIn(context));
    } else {
      mark = Icon(s.icon, color: s.colorIn(context), size: 20);
    }
    return SizedBox.square(
      dimension: size,
      child: Center(child: mark),
    );
  }
}

/// The key under the calendar: only the statuses used in the focused month,
/// each with its count, plus a link to the full list of symbols.
class _MonthKey extends ConsumerWidget {
  const _MonthKey();

  static final _dayKeyFmt = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focused = ref.watch(calendarFocusProvider);
    final attended = ref.watch(attendanceProvider).attendanceDateKeys;
    final special = ref.watch(specialDayProvider).typeByDate;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // Attendance wins over a special day, as in the calendar itself.
    final counts = <DayStatus, int>{};
    final days = DateTime(focused.year, focused.month + 1, 0).day;
    for (var d = 1; d <= days; d++) {
      final key = _dayKeyFmt.format(DateTime(focused.year, focused.month, d));
      final status = attended.contains(key)
          ? DayStatus.attended
          : special[key]?.dayStatus;
      if (status != null) counts[status] = (counts[status] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 14,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (counts.isEmpty)
              Text(
                'Nothing marked this month',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            // Listed in the usual status order, not by count, so each status
            // keeps its place from month to month.
            for (final s in DayStatus.values)
              if (counts[s] case final n?)
                Semantics(
                  label: '${s.label}: $n ${n == 1 ? 'day' : 'days'}',
                  excludeSemantics: true,
                  // Long labels wrap rather than overflow on narrow screens.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatusSwatch(s),
                        const SizedBox(width: 6),
                        Flexible(child: Text(s.label, style: text.bodySmall)),
                        const SizedBox(width: 4),
                        Text(
                          '$n',
                          style: text.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            TextButton.icon(
              onPressed: () => _showAllSymbols(context),
              icon: const Icon(Icons.info_outline, size: 18),
              label: const Text('All symbols'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every symbol the calendar can show, with what it means.
void _showAllSymbols(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      final cs = Theme.of(context).colorScheme;
      Widget row(Widget swatch, String title, String subtitle) => ListTile(
        leading: swatch,
        title: Text(title),
        subtitle: Text(subtitle),
        minLeadingWidth: _StatusSwatch.size,
      );
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Calendar symbols', style: text.titleLarge),
              ),
              for (final s in DayStatus.values)
                row(_StatusSwatch(s), s.label, s.description),
              Divider(indent: 16, endIndent: 16, color: cs.outlineVariant),
              row(
                const _StatusSwatch(null),
                'Today',
                'Today, before anything is recorded',
              ),
              row(
                const _StatusSwatch(null, ring: true),
                'Today, recorded',
                'A ring around today\'s symbol',
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ── Shared month calendar ─────────────────────────────────────────────────────

/// The status-marked month calendar, watching the attendance/special-day
/// providers itself so both the phone and desktop dashboards can drop it in.
class _CalendarCard extends ConsumerWidget {
  final ValueChanged<DateTime> onPageChanged;
  final ValueChanged<DateTime> onDayTapped;

  const _CalendarCard({required this.onPageChanged, required this.onDayTapped});

  static final _dayKeyFmt = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(attendanceProvider);
    final sp = ref.watch(specialDayProvider);
    final focusedDay = ref.watch(calendarFocusProvider);

    final attendedKeys = ap.attendanceDateKeys;
    final specialTypes = sp.typeByDate;
    DayStatus? statusFor(DateTime day) {
      final key = _dayKeyFmt.format(day);
      if (attendedKeys.contains(key)) return DayStatus.attended;
      return specialTypes[key]?.dayStatus;
    }

    Widget? dayCell(DateTime day, {required bool isToday}) {
      final status = statusFor(day);
      if (!isToday && status == null) return null;
      return _DayCell(day: day, status: status, isToday: isToday);
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(DateTime.now().year + 5, 12, 31),
            focusedDay: focusedDay,
            calendarFormat: CalendarFormat.month,
            availableGestures: AvailableGestures.horizontalSwipe,
            startingDayOfWeek: StartingDayOfWeek.monday,
            sixWeekMonthsEnforced: true,
            onPageChanged: onPageChanged,
            selectedDayPredicate: (_) => false,
            // Future days are tappable too — see the phone calendar above.
            onDaySelected: (selectedDay, _) => onDayTapped(selectedDay),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, _) => dayCell(day, isToday: false),
              todayBuilder: (context, day, _) => dayCell(day, isToday: true),
            ),
            calendarStyle: const CalendarStyle(outsideDaysVisible: false),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const _MonthKey(),
        ],
      ),
    );
  }
}

// ── Desktop dashboard ─────────────────────────────────────────────────────────

/// The wide-window home: a stats strip + calendar fill the main column, with a
/// gauge and selected-day detail panel on the right. Tapping a day selects it
/// (updating the right panel); the panel's button opens the quick-mark sheet.
class _DesktopDashboard extends ConsumerStatefulWidget {
  final OfficeLocation selected;
  final List<OfficeLocation> offices;
  final ValueChanged<OfficeLocation> onOfficeChanged;
  final ValueChanged<DateTime> onPageChanged;
  final ValueChanged<DateTime> onDayTapped;

  const _DesktopDashboard({
    required this.selected,
    required this.offices,
    required this.onOfficeChanged,
    required this.onPageChanged,
    required this.onDayTapped,
  });

  @override
  ConsumerState<_DesktopDashboard> createState() => _DesktopDashboardState();
}

class _DesktopDashboardState extends ConsumerState<_DesktopDashboard> {
  static final _dayKeyFmt = DateFormat('yyyy-MM-dd');
  static final _dayLabelFmt = DateFormat('EEEE, d MMM yyyy');
  DateTime _selectedDay = DateTime.now();

  Future<void> _checkInToday() async {
    final result = await ref
        .read(attendanceProvider.notifier)
        .manualCheckIn(widget.selected.id!, focusedMonth: DateTime.now());
    if (!mounted) return;
    if (result == CheckInResult.recorded) {
      ref.invalidate(breakdownProvider);
      ref.invalidate(weeklyTrendProvider);
    }
    final msg = switch (result) {
      CheckInResult.recorded => 'Attendance recorded for today!',
      CheckInResult.alreadyRecorded => 'Already checked in for today.',
      CheckInResult.alreadyRecordedByAuto =>
        'Attendance already recorded by auto check-in.',
      CheckInResult.specialDayConflict =>
        'Today is already marked (holiday or leave) — change it first.',
      CheckInResult.weekend => weekendNotMarkableMessage,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final focusedDay = ref.watch(calendarFocusProvider);
    final monthPeriod = ReportPeriod(
      kind: PeriodKind.month,
      anchor: focusedDay,
      financialYearStart: settings.financialYearStart,
    );
    final monthBreakdown = ref.watch(
      breakdownProvider((
        officeId: widget.selected.id!,
        start: monthPeriod.start,
        end: monthPeriod.end,
      )),
    );
    final bird = birdAssetForTheme(settings.themeId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, monthPeriod),
          const SizedBox(height: 20),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gauge = _gaugeCard(
                  context,
                  monthBreakdown,
                  settings.rtoTarget,
                  bird,
                  monthPeriod.label,
                );
                final calendar = _CalendarCard(
                  onPageChanged: widget.onPageChanged,
                  onDayTapped: _onDayTap,
                );

                // Compact desktop windows keep all content readable by
                // stacking the secondary cards. Only use the two-pane layout
                // once both the calendar and the fixed-width detail rail fit.
                if (constraints.maxWidth < 880) {
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _kpiStrip(context, monthBreakdown, settings.rtoTarget),
                      const SizedBox(height: 20),
                      gauge,
                      const SizedBox(height: 16),
                      calendar,
                      const SizedBox(height: 16),
                      _dayDetailCard(context),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _kpiStrip(
                            context,
                            monthBreakdown,
                            settings.rtoTarget,
                          ),
                          const SizedBox(height: 20),
                          calendar,
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 340,
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          gauge,
                          const SizedBox(height: 16),
                          _dayDetailCard(context),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onDayTap(DateTime day) => setState(() => _selectedDay = day);

  Widget _header(BuildContext context, ReportPeriod monthPeriod) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                monthPeriod.label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (widget.offices.length > 1) ...[
          DropdownButton<OfficeLocation>(
            value: widget.selected,
            borderRadius: BorderRadius.circular(12),
            underline: const SizedBox.shrink(),
            items: widget.offices
                .map((o) => DropdownMenuItem(value: o, child: Text(o.name)))
                .toList(),
            onChanged: (o) {
              if (o != null) widget.onOfficeChanged(o);
            },
          ),
          const SizedBox(width: 12),
        ],
        FilledButton.icon(
          onPressed: _checkInToday,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Check in for today'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
        ),
      ],
    );
  }

  Widget _kpiStrip(
    BuildContext context,
    AsyncValue<AttendanceBreakdown> bd,
    int target,
  ) {
    final b = bd.asData?.value;
    final present = b?.officeDays;
    final eligible = b?.eligibleWorkingDays;
    final pct = b?.returnToOfficePercentage;
    final toTarget = (b == null || eligible == null)
        ? null
        : ((target / 100 * eligible).ceil() - (present ?? 0)).clamp(0, 9999);
    String n(num? v) => v == null ? '—' : '$v';

    final cards = [
      StatCard(
        icon: Icons.check_circle,
        color: Colors.green.shade600,
        value: n(present),
        label: 'Days in office',
      ),
      StatCard(
        icon: Icons.trending_up,
        color: Theme.of(context).colorScheme.primary,
        value: pct == null ? '—' : '${pct.round()}%',
        label: 'This month',
      ),
      StatCard(
        icon: Icons.event_available,
        color: Colors.blue.shade600,
        value: n(eligible),
        label: 'Working days',
      ),
      StatCard(
        icon: Icons.flag_outlined,
        color: Colors.orange.shade700,
        value: n(toTarget),
        label: 'Days to target',
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        // Pick the most columns (up to 4) that still leave each card wide
        // enough to render its icon chip + value without overflowing — narrow
        // desktop windows with the sidebar extended squeeze this strip hard.
        const minItem = 150.0;
        final perRow = ((c.maxWidth + 16) / (minItem + 16)).floor().clamp(1, 4);
        final itemW = (c.maxWidth - (perRow - 1) * 16) / perRow;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final card in cards) SizedBox(width: itemW, child: card),
          ],
        );
      },
    );
  }

  Widget _gaugeCard(
    BuildContext context,
    AsyncValue<AttendanceBreakdown> bd,
    int target,
    String? bird,
    String periodLabel,
  ) {
    return bd.when(
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
        target: target,
        birdAsset: bird,
        periodLabel: periodLabel,
        onTap: () => ref.read(tabIndexProvider.notifier).set(1),
      ),
    );
  }

  Widget _dayDetailCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ap = ref.watch(attendanceProvider);
    final sp = ref.watch(specialDayProvider);
    final key = _dayKeyFmt.format(_selectedDay);
    final DayStatus? status = ap.attendanceDateKeys.contains(key)
        ? DayStatus.attended
        : sp.typeByDate[key]?.dayStatus;
    final isPlanned = isPlannedDay(_selectedDay);
    // An empty weekend cannot be marked; one with an entry can still be opened
    // so that entry can be removed.
    final blocked = status == null && isWeekendDay(_selectedDay);

    return _AttentionBorder(
      trigger: _selectedDay,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.event_note_outlined, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Selected day',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _dayLabelFmt.format(_selectedDay),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (status != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusBadge(status: status),
                )
              else
                Text(
                  blocked
                      ? weekendNotMarkableMessage
                      : isPlanned
                      ? 'Nothing planned for this day yet.'
                      : 'No attendance recorded for this day.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: blocked
                    ? null
                    : () => widget.onDayTapped(_selectedDay),
                icon: const Icon(Icons.edit_calendar_outlined),
                label: Text(
                  status != null
                      ? 'Edit this day'
                      : isPlanned
                      ? 'Plan this day'
                      : 'Mark this day',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Briefly pulses a primary-coloured border + glow around [child] for ~5s each
/// time [trigger] changes. Used on the selected-day panel so that picking a new
/// day visibly draws the eye to the panel (and its action), instead of the
/// change going unnoticed.
class _AttentionBorder extends StatefulWidget {
  final Object trigger;
  final Widget child;
  const _AttentionBorder({required this.trigger, required this.child});

  @override
  State<_AttentionBorder> createState() => _AttentionBorderState();
}

class _AttentionBorderState extends State<_AttentionBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  int _pulseId = 0;

  @override
  void didUpdateWidget(covariant _AttentionBorder old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _pulse();
  }

  void _pulse() {
    final id = ++_pulseId;
    _controller
      ..reset()
      ..repeat(reverse: true);
    // Pulse for ~5 seconds, then ease the border back out. A newer pulse
    // supersedes this one (guarded by the id) so it isn't cut short.
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || id != _pulseId) return;
      _controller.stop();
      _controller.animateBack(0, duration: const Duration(milliseconds: 300));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        // foregroundDecoration paints the border over the card edge without
        // insetting it (no layout shift); the shadow goes behind.
        return Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.primary.withValues(alpha: t),
              width: 2,
            ),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: t > 0
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.25 * t),
                      blurRadius: 14 * t,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A small coloured pill showing a day's status (icon + label).
class _StatusBadge extends StatelessWidget {
  final DayStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.colorIn(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
