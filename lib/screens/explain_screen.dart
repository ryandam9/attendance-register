import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_colors.dart';
import '../helpers/day_type_helper.dart';
import '../models/attendance_breakdown.dart';
import '../models/office_location.dart';
import '../models/report_period.dart';
import '../models/special_day.dart';
import '../providers/explain_provider.dart';
import '../providers/office_provider.dart';
import '../providers/settings_provider.dart';
import '../themes/bird_art.dart';
import '../widgets/no_office_placeholder.dart';
import '../widgets/rto_arc_card.dart';

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
    final target = settings.rtoTarget;
    final bird = birdAssetForTheme(settings.themeId);

    // The two headline gauges: this month and the (financial) year to date.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthNow = ReportPeriod(kind: PeriodKind.month, anchor: now);
    final yearNow = ReportPeriod(
        kind: PeriodKind.year, anchor: now, financialYearStart: fyStart);
    // Cap the year at today so it reads as year-to-date, not the whole year
    // (future weekdays would otherwise dilute the percentage).
    final yearEnd = yearNow.end.isAfter(today) ? today : yearNow.end;
    final monthBd = ref.watch(breakdownProvider(
        (officeId: office.id!, start: monthNow.start, end: monthNow.end)));
    final yearBd = ref.watch(breakdownProvider(
        (officeId: office.id!, start: yearNow.start, end: yearEnd)));

    // The period the detailed breakdown below is shown for.
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

          // Headline gauges — month then year-to-date, one below another.
          _arcCard(monthBd, monthNow.label, target, bird),
          const SizedBox(height: 16),
          _arcCard(yearBd, '${yearNow.label} · YTD', target, bird),

          const SizedBox(height: 24),
          _sectionTitle(context, Icons.tune, 'Detailed breakdown'),
          const SizedBox(height: 12),
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
            data: (b) => _details(b, target, office.id!),
          ),
        ],
      ),
    );
  }

  /// A return-to-office gauge card wrapped in its async states.
  Widget _arcCard(
      AsyncValue<AttendanceBreakdown> bd, String label, int target, String? bird) {
    return bd.when(
      loading: () => const Card(
        margin: EdgeInsets.zero,
        child: SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('Could not load $label: $e')),
        ),
      ),
      data: (b) => RtoArcCard(
        breakdown: b,
        target: target,
        periodLabel: label,
        birdAsset: bird,
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

  // ── Detailed breakdown (for the selected period) ───────────────────────────

  Widget _details(AttendanceBreakdown b, int target, int officeId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BreakdownDonut(breakdown: b),
        const SizedBox(height: 16),
        _TrendCard(officeId: officeId, target: target),
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

// ── Work-style donut ──────────────────────────────────────────────────────────

class _BreakdownDonut extends StatelessWidget {
  final AttendanceBreakdown breakdown;
  const _BreakdownDonut({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    final leave = b.countOf(DayType.sickLeave) +
        b.countOf(DayType.annualLeave) +
        b.countOf(DayType.carersLeave) +
        b.countOf(DayType.miscLeave);
    final segments = <_DonutSegment>[
      _DonutSegment('Attended', b.officeDays,
          DayTypeColors.of(context).attendance),
      _DonutSegment('WFH', b.countOf(DayType.workFromHome),
          DayType.workFromHome.colorIn(context)),
      _DonutSegment('Leave', leave, DayType.annualLeave.colorIn(context)),
      _DonutSegment('Holiday', b.countOf(DayType.holiday),
          DayType.holiday.colorIn(context)),
    ];
    final total = segments.fold<int>(0, (s, seg) => s + seg.value);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, Icons.donut_large_outlined,
                'Work style breakdown'),
            const SizedBox(height: 16),
            if (total == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No recorded days in this period yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: _DonutPainter(segments, total),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$total',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'days',
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final seg in segments)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: seg.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(seg.label)),
                                Text(
                                  '${seg.value} · ${(seg.value / total * 100).toStringAsFixed(1)}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DonutSegment {
  final String label;
  final int value;
  final Color color;
  const _DonutSegment(this.label, this.value, this.color);
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final int total;
  _DonutPainter(this.segments, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - stroke / 2,
    );
    var start = -math.pi / 2; // 12 o'clock
    const gap = 0.04;
    for (final seg in segments) {
      if (seg.value == 0) continue;
      final sweep = (seg.value / total) * (2 * math.pi);
      canvas.drawArc(
        rect,
        start + gap / 2,
        sweep - gap,
        false,
        Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total || old.segments != segments;
}

// ── 8-week trend ──────────────────────────────────────────────────────────────

class _TrendCard extends ConsumerWidget {
  final int officeId;
  final int target;
  const _TrendCard({required this.officeId, required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(weeklyTrendProvider(officeId));
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, Icons.show_chart, 'Trend (last 8 weeks)'),
            const SizedBox(height: 16),
            trend.when(
              loading: () => const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SizedBox(
                height: 140,
                child: Center(child: Text('Could not load trend: $e')),
              ),
              data: (points) => _TrendChart(points: points, target: target),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<TrendPoint> points;
  final int target;
  const _TrendChart({required this.points, required this.target});

  static final _weekFmt = DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasData = points.any((p) => p.percentage != null);
    if (!hasData) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Not enough data yet — keep marking your days.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 140,
          width: double.infinity,
          child: CustomPaint(
            painter: _TrendPainter(
              points: points,
              targetFraction: (target / 100).clamp(0.0, 1.0),
              line: cs.primary,
              fill: cs.primary.withValues(alpha: 0.12),
              targetColor: AppColors.attendance,
              grid: cs.outlineVariant,
              dot: cs.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_weekFmt.format(points.first.weekStart),
                style: Theme.of(context).textTheme.labelSmall),
            Text(_weekFmt.format(points.last.weekStart),
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> points;
  final double targetFraction;
  final Color line;
  final Color fill;
  final Color targetColor;
  final Color grid;
  final Color dot;

  _TrendPainter({
    required this.points,
    required this.targetFraction,
    required this.line,
    required this.fill,
    required this.targetColor,
    required this.grid,
    required this.dot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 6.0;
    final h = size.height - pad * 2;
    final w = size.width - pad * 2;
    double x(int i) =>
        pad + (points.length == 1 ? w / 2 : w * i / (points.length - 1));
    double y(double pct) => pad + h * (1 - pct / 100);

    // Target line.
    final ty = pad + h * (1 - targetFraction);
    final dashPaint = Paint()
      ..color = targetColor.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    for (var dx = pad; dx < size.width - pad; dx += 10) {
      canvas.drawLine(Offset(dx, ty), Offset(dx + 5, ty), dashPaint);
    }

    // Build the line through known points (skip null weeks by bridging).
    final pts = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final pct = points[i].percentage;
      if (pct != null) pts.add(Offset(x(i), y(pct)));
    }
    if (pts.isEmpty) return;

    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }

    // Area fill under the line.
    final fillPath = Path.from(linePath)
      ..lineTo(pts.last.dx, pad + h)
      ..lineTo(pts.first.dx, pad + h)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fill);

    canvas.drawPath(
      linePath,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );

    for (final p in pts) {
      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3, Paint()..color = dot);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.points != points || old.targetFraction != targetFraction;
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
