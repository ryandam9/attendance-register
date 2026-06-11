import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_colors.dart';
import '../helpers/day_type_helper.dart';
import '../models/attendance_breakdown.dart';
import '../models/office_location.dart';
import '../models/report_period.dart';
import '../models/special_day.dart';
import '../providers/explain_provider.dart';
import '../providers/office_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/no_office_placeholder.dart';

/// The Insights tab: explains how the "Return to office" percentage is
/// calculated for a chosen month or financial year — every contributing count
/// plus the arithmetic that turns them into the final percentage.
class ExplainScreen extends ConsumerStatefulWidget {
  const ExplainScreen({super.key});

  @override
  ConsumerState<ExplainScreen> createState() => _ExplainScreenState();
}

class _ExplainScreenState extends ConsumerState<ExplainScreen> {
  PeriodKind _kind = PeriodKind.month;
  // Any day inside the selected window; the ReportPeriod normalises it.
  DateTime _anchor = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final office = ref.watch(officeProvider).selectedOffice;
    if (office == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: const NoOfficePlaceholder(),
      );
    }

    final settings = ref.watch(settingsProvider);
    final fyStart = settings.financialYearStart;
    final period = ReportPeriod(
      kind: _kind,
      anchor: _anchor,
      financialYearStart: fyStart,
    );
    final breakdown = ref.watch(breakdownProvider((
      officeId: office.id!,
      start: period.start,
      end: period.end,
    )));

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OfficeChip(office: office),
          const SizedBox(height: 16),
          _periodKindSelector(),
          if (_kind == PeriodKind.year) ...[
            const SizedBox(height: 12),
            _financialYearSelector(fyStart),
          ],
          const SizedBox(height: 12),
          _periodNavigator(period),
          const SizedBox(height: 16),
          breakdown.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('Could not load data: $e')),
            ),
            data: (b) => _report(b, settings.rtoTarget),
          ),
        ],
      ),
    );
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _periodKindSelector() {
    return SegmentedButton<PeriodKind>(
      segments: const [
        ButtonSegment(
          value: PeriodKind.month,
          label: Text('Month'),
          icon: Icon(Icons.calendar_view_month_outlined),
        ),
        ButtonSegment(
          value: PeriodKind.year,
          label: Text('Year'),
          icon: Icon(Icons.calendar_today_outlined),
        ),
      ],
      selected: {_kind},
      onSelectionChanged: (s) => setState(() => _kind = s.first),
    );
  }

  Widget _financialYearSelector(FinancialYearStart fyStart) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_repeat_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text('Financial year',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<FinancialYearStart>(
              segments: [
                for (final v in FinancialYearStart.values)
                  ButtonSegment(value: v, label: Text(v.label)),
              ],
              selected: {fyStart},
              onSelectionChanged: (s) => ref
                  .read(settingsProvider.notifier)
                  .setFinancialYearStart(s.first),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodNavigator(ReportPeriod period) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton.filledTonal(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous',
          onPressed: () => setState(() => _anchor = period.previous.anchor),
        ),
        Expanded(
          child: Text(
            period.label,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next',
          // Don't let the user page into the future.
          onPressed: period.isCurrent
              ? null
              : () => setState(() => _anchor = period.next.anchor),
        ),
      ],
    );
  }

  // ── Report ───────────────────────────────────────────────────────────────

  Widget _report(AttendanceBreakdown b, int target) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PercentageHero(breakdown: b, target: target),
        const SizedBox(height: 16),
        _CalculationCard(breakdown: b),
        const SizedBox(height: 16),
        _CountsCard(breakdown: b),
      ],
    );
  }
}

// ── Office chip ───────────────────────────────────────────────────────────────

class _OfficeChip extends StatelessWidget {
  final OfficeLocation office;
  const _OfficeChip({required this.office});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
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
    );
  }
}

// ── Percentage hero ───────────────────────────────────────────────────────────

class _PercentageHero extends StatelessWidget {
  final AttendanceBreakdown breakdown;
  final int target;
  const _PercentageHero({required this.breakdown, required this.target});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = breakdown.returnToOfficePercentage;
    final text = pct == null ? '—' : '${pct.toStringAsFixed(1)}%';
    final metTarget = pct != null && pct >= target;

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Text(
              'Return to office',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              pct == null
                  ? 'No eligible working days in this period'
                  : '${breakdown.officeDays} of ${breakdown.eligibleWorkingDays} '
                      'eligible working days at the office',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
            ),
            if (pct != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    metTarget ? Icons.check_circle : Icons.flag_outlined,
                    size: 16,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    metTarget
                        ? 'Target of $target% met'
                        : 'Below the $target% target',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Calculation card ─────────────────────────────────────────────────────────

class _CalculationCard extends StatelessWidget {
  final AttendanceBreakdown breakdown;
  const _CalculationCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    final pct = b.returnToOfficePercentage;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, Icons.calculate_outlined, 'How it’s calculated'),
            const SizedBox(height: 12),
            _CalcLine(
              label: 'Eligible working days',
              expression:
                  '${b.weekdays} weekdays − ${_dayCount(b.excludedDays, 'non-working day')}',
              result: '${b.eligibleWorkingDays}',
            ),
            const Divider(height: 24),
            _CalcLine(
              label: 'Return to office %',
              expression: pct == null
                  ? '${b.officeDays} ÷ 0'
                  : '${b.officeDays} office ÷ ${b.eligibleWorkingDays} eligible × 100',
              result: pct == null ? '—' : '${pct.toStringAsFixed(1)}%',
              emphasise: true,
            ),
            const SizedBox(height: 12),
            Text(
              'Non-working days \u2014 public holidays and sick, annual, carer\u2019s '
              'and misc leave \u2014 are removed from the working-day total. '
              'Work-from-home days stay in it, so they lower the percentage.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalcLine extends StatelessWidget {
  final String label;
  final String expression;
  final String result;
  final bool emphasise;

  const _CalcLine({
    required this.label,
    required this.expression,
    required this.result,
    this.emphasise = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resultStyle = (emphasise
            ? theme.textTheme.titleLarge
            : theme.textTheme.titleMedium)
        ?.copyWith(
      fontWeight: FontWeight.bold,
      color: emphasise ? theme.colorScheme.primary : null,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(
                expression,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(result, style: resultStyle),
      ],
    );
  }
}

// ── Counts card ──────────────────────────────────────────────────────────────

class _CountsCard extends StatelessWidget {
  final AttendanceBreakdown breakdown;
  const _CountsCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, Icons.summarize_outlined, 'Day counts'),
            const SizedBox(height: 4),
            _CountRow(
              color: DayTypeColors.of(context).attendance,
              label: 'At office (Mon–Fri)',
              count: b.officeDays,
              tag: 'counts toward %',
            ),
            // Weekend check-ins are real attendance but sit outside the
            // weekday-based percentage — surfaced so the numbers add up.
            if (b.weekendOfficeDays > 0)
              _CountRow(
                color: DayTypeColors.of(context).attendance,
                label: 'At office (weekend)',
                count: b.weekendOfficeDays,
                tag: 'not counted',
                dim: true,
              ),
            // Special-day types in a stable, readable order.
            for (final type in const [
              DayType.workFromHome,
              DayType.miscLeave,
              DayType.holiday,
              DayType.sickLeave,
              DayType.annualLeave,
              DayType.carersLeave,
            ])
              _CountRow(
                color: type.colorIn(context),
                label: type.label,
                count: b.countOf(type),
                tag: excludedFromAttendanceDenominator.contains(type)
                    ? 'excluded from %'
                    : 'lowers %',
              ),
            const Divider(height: 24),
            _CountRow(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              label: 'Weekdays (Mon–Fri)',
              count: b.weekdays,
              tag: 'total working days',
              dim: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final String tag;
  final bool dim;

  const _CountRow({
    required this.color,
    required this.label,
    required this.count,
    required this.tag,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dim ? color.withValues(alpha: 0.4) : color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyLarge),
          ),
          Text(
            tag,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// "1 non-working day" / "3 non-working days" — pluralises [unit] by [n].
String _dayCount(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';

Widget _sectionTitle(BuildContext context, IconData icon, String text) {
  final cs = Theme.of(context).colorScheme;
  return Row(
    children: [
      Icon(icon, size: 18, color: cs.primary),
      const SizedBox(width: 8),
      Text(text, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
