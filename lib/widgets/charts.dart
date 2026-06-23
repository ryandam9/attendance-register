import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_colors.dart';
import '../helpers/day_type_helper.dart';
import '../models/attendance_breakdown.dart';
import '../models/special_day.dart';
import '../providers/explain_provider.dart';

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

// ── Work-style donut ──────────────────────────────────────────────────────────

/// A donut chart of how a period's recorded days split across office / WFH /
/// leave / holiday, with a legend. Shared by Insights and the desktop dashboard.
class BreakdownDonut extends StatelessWidget {
  final AttendanceBreakdown breakdown;
  const BreakdownDonut({super.key, required this.breakdown});

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
            if (total > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Share of your $total recorded ${total == 1 ? 'day' : 'days'} '
                '(not the return-to-office rate)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
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

/// A card plotting the return-to-office percentage over the last 8 weeks, with
/// the target line. Shared by Insights and the desktop dashboard.
class TrendCard extends ConsumerWidget {
  final int officeId;
  final int target;
  const TrendCard({super.key, required this.officeId, required this.target});

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
