import 'dart:async';

import 'package:animations/animations.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../helpers/day_type_helper.dart';
import '../models/special_day.dart';
import '../providers/attendance_provider.dart';
import '../providers/explain_provider.dart';
import '../providers/office_provider.dart';
import '../providers/special_day_provider.dart';
import '../widgets/no_office_placeholder.dart';
import 'day_entry_screen.dart';

/// The "Mark" tab: the home for the two day-recording actions that used to live
/// on the home dashboard — the one-tap "Check-In for Today" (with its
/// celebration) and the full "Mark a Day" editor.
class MarkScreen extends ConsumerStatefulWidget {
  const MarkScreen({super.key});

  @override
  ConsumerState<MarkScreen> createState() => _MarkScreenState();
}

class _MarkScreenState extends ConsumerState<MarkScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 1200));
  bool _justCheckedIn = false;
  Timer? _checkedInReset;

  static final _keyFmt = DateFormat('yyyy-MM-dd');
  static final _dateFmt = DateFormat('EEEE, MMMM d');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadThisMonth());
  }

  @override
  void dispose() {
    _checkedInReset?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  /// Loads the current month so today's status can be shown and kept fresh.
  void _loadThisMonth() {
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    final now = DateTime.now();
    ref.read(attendanceProvider.notifier).loadForMonth(office.id!, now.year, now.month);
    ref.read(specialDayProvider.notifier).loadForMonth(now.year, now.month);
  }

  Future<void> _manualCheckIn() async {
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    final result = await ref
        .read(attendanceProvider.notifier)
        .manualCheckIn(office.id!, focusedMonth: DateTime.now());
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
      ref.invalidate(breakdownProvider);
      ref.invalidate(weeklyTrendProvider);
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

  void _onMarkADayClosed(bool? changed) {
    if (changed != true) return;
    _loadThisMonth();
    ref.invalidate(breakdownProvider);
    ref.invalidate(weeklyTrendProvider);
  }

  @override
  Widget build(BuildContext context) {
    final officeState = ref.watch(officeProvider);
    final office = officeState.selectedOffice;

    if (office == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mark')),
        body: const NoOfficePlaceholder(),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final ap = ref.watch(attendanceProvider);
    final sp = ref.watch(specialDayProvider);

    final todayKey = _keyFmt.format(DateTime.now());
    final DayStatus? todayStatus = ap.attendanceDateKeys.contains(todayKey)
        ? DayStatus.attended
        : sp.typeByDate[todayKey]?.dayStatus;

    return Scaffold(
      appBar: AppBar(title: const Text('Mark')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Office context.
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(Icons.business_outlined, color: cs.primary),
                  title: Text(office.name),
                  subtitle: Text(
                    office.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Today summary.
              _TodayCard(status: todayStatus, dateLabel: _dateFmt.format(DateTime.now())),
              const SizedBox(height: 20),

              // Primary action — morphs into a confirmation for a moment after a
              // successful check-in.
              FilledButton.icon(
                onPressed: _manualCheckIn,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _justCheckedIn ? Icons.celebration : Icons.check_circle_outline,
                    key: ValueKey(_justCheckedIn),
                  ),
                ),
                label: Text(_justCheckedIn ? 'Checked in!' : 'Check-In for Today'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: 12),

              // Secondary action — container-transforms into the full day-entry
              // screen for any date / status.
              OpenContainer<bool>(
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
                    height: 52,
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
                openBuilder: (context, _) => DayEntryScreen(office: office),
                onClosed: _onMarkADayClosed,
              ),
              const SizedBox(height: 16),
              Text(
                'Tip: you can also tap any day on the Home calendar to mark it.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
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

/// Shows today's date and whatever status (if any) is already recorded for it.
class _TodayCard extends StatelessWidget {
  final DayStatus? status;
  final String dateLabel;
  const _TodayCard({required this.status, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = status;
    final color = s?.colorIn(context) ?? cs.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(s?.icon ?? Icons.today_outlined, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today', style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(dateLabel, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    s == null ? 'Not recorded yet' : s.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
