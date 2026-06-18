import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/attendance_breakdown.dart';

/// The "Return to office" hero card: a bird-flight gauge arc whose marker sits
/// at the current percentage, with a tick at the target. Below target it warms
/// to the Feathers warning colours; on/above target it turns success-green.
///
/// Shared by the Home dashboard and the Insights tab so the headline figure is
/// presented identically in both places.
class RtoArcCard extends StatelessWidget {
  final AttendanceBreakdown breakdown;
  final int target;
  final VoidCallback? onTap;

  /// Optional bird illustration (SVG asset) that perches on the gauge at the
  /// current percentage instead of the plain marker dot.
  final String? birdAsset;

  /// Optional caption under the title, e.g. "June 2026" or "2026".
  final String? periodLabel;

  const RtoArcCard({
    super.key,
    required this.breakdown,
    required this.target,
    this.onTap,
    this.birdAsset,
    this.periodLabel,
  });

  // Feathers warning + success colours (used as fills, tints, icons and
  // accents only — never as text on white).
  static const _warning = Color(0xFFF5A200);
  static const _success = AppColors.attendance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final pct = breakdown.returnToOfficePercentage;
    final metTarget = pct != null && pct >= target;
    final accent = pct == null
        ? cs.onSurfaceVariant
        : (metTarget ? _success : _warning);

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                      'Return to office',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (periodLabel != null)
                      Text(
                        periodLabel!,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      pct == null
                          ? 'No eligible working days yet'
                          : '${breakdown.officeDays} of ${breakdown.eligibleWorkingDays} working days',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$target%',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'target',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          _RtoArc(
            percentage: pct,
            target: target,
            accent: accent,
            track: cs.surfaceContainerHighest,
            tickColor: cs.onSurfaceVariant,
            birdAsset: birdAsset,
          ),
          if (pct != null) ...[
            const SizedBox(height: 8),
            _TargetBanner(
              metTarget: metTarget,
              target: target,
              success: _success,
              warning: _warning,
            ),
          ],
        ],
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }
}

/// A pill stating whether the target is met (green) or not (amber tint), using
/// the Feathers warning colours as background/border/icon — never yellow text.
class _TargetBanner extends StatelessWidget {
  final bool metTarget;
  final int target;
  final Color success;
  final Color warning;

  const _TargetBanner({
    required this.metTarget,
    required this.target,
    required this.success,
    required this.warning,
  });

  @override
  Widget build(BuildContext context) {
    final color = metTarget ? success : warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            metTarget ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              metTarget
                  ? 'Target of $target% met — nice work!'
                  : 'You are below the $target% target',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Semicircular gauge: track + coloured progress sweep, a tick at [target], and
/// a marker dot at the current percentage, with the percentage in the centre.
class _RtoArc extends StatelessWidget {
  final double? percentage;
  final int target;
  final Color accent;
  final Color track;
  final Color tickColor;
  final String? birdAsset;

  const _RtoArc({
    required this.percentage,
    required this.target,
    required this.accent,
    required this.track,
    required this.tickColor,
    this.birdAsset,
  });

  static const _height = 132.0;
  static const _stroke = 14.0;
  static const _birdW = 54.0;
  static const _birdH = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frac = ((percentage ?? 0) / 100).clamp(0.0, 1.0);
    final showBird = birdAsset != null && percentage != null;

    return SizedBox(
      height: _height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final radius = math.min(w / 2, _height) - _stroke;
          final center = Offset(w / 2, _height - _stroke / 2);

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: frac),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, animFrac, _) {
              final angle = math.pi + math.pi * animFrac;
              final marker = Offset(
                center.dx + radius * math.cos(angle),
                center.dy + radius * math.sin(angle),
              );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ArcPainter(
                        fraction: animFrac,
                        targetFraction: (target / 100).clamp(0.0, 1.0),
                        accent: accent,
                        track: track,
                        tickColor: tickColor,
                        hasValue: percentage != null,
                        showMarkerDot: !showBird,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              percentage == null
                                  ? '—'
                                  : '${percentage!.toStringAsFixed(1)}%',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$target% target',
                              style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (showBird)
                    Positioned(
                      left: marker.dx - _birdW / 2,
                      top: marker.dy - _birdH + _stroke / 2,
                      child: Image.asset(
                        birdAsset!,
                        width: _birdW,
                        height: _birdH,
                        fit: BoxFit.contain,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double fraction;
  final double targetFraction;
  final Color accent;
  final Color track;
  final Color tickColor;
  final bool hasValue;
  final bool showMarkerDot;

  _ArcPainter({
    required this.fraction,
    required this.targetFraction,
    required this.accent,
    required this.track,
    required this.tickColor,
    required this.hasValue,
    this.showMarkerDot = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final radius = math.min(size.width / 2, size.height) - stroke;
    final center = Offset(size.width / 2, size.height - stroke / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    // Upper semicircle: start at 180° (left), sweep 180° clockwise over the top.
    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    if (hasValue) {
      final progressPaint = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, math.pi, math.pi * fraction, false, progressPaint);

      // Marker dot at the current percentage (hidden when a bird perches there).
      if (showMarkerDot) {
        final markerAngle = math.pi + math.pi * fraction;
        final markerPos = Offset(
          center.dx + radius * math.cos(markerAngle),
          center.dy + radius * math.sin(markerAngle),
        );
        canvas.drawCircle(
            markerPos, stroke / 2 + 2, Paint()..color = Colors.white);
        canvas.drawCircle(markerPos, stroke / 2 - 1, Paint()..color = accent);
      }
    }

    // Target tick across the band.
    final tickAngle = math.pi + math.pi * targetFraction;
    final inner = Offset(
      center.dx + (radius - stroke / 2 - 2) * math.cos(tickAngle),
      center.dy + (radius - stroke / 2 - 2) * math.sin(tickAngle),
    );
    final outer = Offset(
      center.dx + (radius + stroke / 2 + 2) * math.cos(tickAngle),
      center.dy + (radius + stroke / 2 + 2) * math.sin(tickAngle),
    );
    canvas.drawLine(
      inner,
      outer,
      Paint()
        ..color = tickColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.fraction != fraction ||
      old.targetFraction != targetFraction ||
      old.accent != accent ||
      old.track != track ||
      old.showMarkerDot != showMarkerDot;
}
