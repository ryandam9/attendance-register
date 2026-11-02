import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../themes/garden_theme.dart';

/// Decorative artwork only: flowers never encode attendance or target status.
///
/// The flowers sway gently on their stems, each a little out of step with the
/// others, like a light breeze. The motion pauses when the garden is off
/// screen (via [TickerMode]) and stays still when the system asks for reduced
/// motion.
class GardenArt extends StatefulWidget {
  const GardenArt({super.key});

  /// One full sway, out and back.
  static const swayPeriod = Duration(seconds: 6);

  @override
  State<GardenArt> createState() => _GardenArtState();
}

class _GardenArtState extends State<GardenArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breeze = AnimationController(
    vsync: this,
    duration: GardenArt.swayPeriod,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breeze.stop();
    } else if (!_breeze.isAnimating) {
      _breeze.repeat();
    }
  }

  @override
  void dispose() {
    _breeze.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 150,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(76),
          bottom: Radius.circular(20),
        ),
        // Repaints only the canvas each frame; nothing else rebuilds.
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _GardenPainter(
              dark: Theme.of(context).brightness == Brightness.dark,
              breeze: _breeze,
            ),
          ),
        ),
      ),
    ),
  );
}

class _GardenPainter extends CustomPainter {
  _GardenPainter({required this.dark, required this.breeze})
    : super(repaint: breeze);
  final bool dark;
  final Animation<double> breeze;

  /// Sway in radians at [phase] (0–1 offset into the cycle): about 3° each
  /// way, with a smaller second wave so the motion never looks mechanical.
  static double _sway(double t, double phase) {
    final a = 2 * math.pi * (t + phase);
    return 0.05 * math.sin(a) + 0.015 * math.sin(2 * a + 1.3);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = breeze.value;
    canvas.save();
    canvas.scale(size.width / 300, size.height / 160);
    final paint = Paint();
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 300, 160),
      paint..color = Color(dark ? 0xFF282B27 : 0xFFDCE5D4),
    );
    canvas.drawCircle(
      const Offset(238, 30),
      18,
      paint..color = Color(dark ? 0xFF839477 : 0xFFEDF0C9),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-45, 120, 400, 100),
      paint..color = Color(dark ? 0xFF424A3D : 0xFFBBCDA9),
    );
    for (final (x, y, color, phase) in [
      (74.0, 79.0, const Color(0xFFD38A6D), 0.0),
      (150.0, 42.0, const Color(0xFFE1BF6C), 0.37),
      (227.0, 89.0, const Color(0xFFF9F7E7), 0.71),
    ]) {
      const groundY = 145.0;
      final sway = _sway(t, phase);
      canvas.save();
      // Pivot the whole plant at the base of its stem.
      canvas.translate(x, groundY);
      canvas.rotate(sway);
      canvas.translate(-x, -groundY);
      canvas.drawLine(
        Offset(x, groundY),
        Offset(x, y),
        paint
          ..color = const Color(0xFF78965F)
          ..strokeWidth = 3,
      );
      for (final side in [-1.0, 1.0]) {
        final leaf = Path()
          ..moveTo(x, y + 46)
          ..quadraticBezierTo(x + side * 36, y + 49, x + side * 34, y + 18)
          ..quadraticBezierTo(x + side * 4, y + 18, x, y + 46);
        canvas.drawPath(leaf, paint..color = const Color(0xFF78965F));
      }
      // The head nods a little further than the stem leans.
      canvas.translate(x, y);
      canvas.rotate(sway * 1.6);
      for (final delta in const [
        Offset(0, -11),
        Offset(-11, 0),
        Offset(11, 0),
        Offset(0, 11),
      ]) {
        canvas.drawCircle(delta, 12, paint..color = color);
      }
      canvas.drawCircle(Offset.zero, 5, paint..color = const Color(0xFF876645));
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GardenPainter oldDelegate) =>
      dark != oldDelegate.dark || breeze != oldDelegate.breeze;
}

@Preview(name: 'Garden · morning', size: Size(360, 190))
Widget gardenLightPreview() => MaterialApp(
  theme: gardenTheme(Brightness.light),
  home: const Scaffold(
    body: Padding(padding: EdgeInsets.all(20), child: GardenArt()),
  ),
);

@Preview(name: 'Garden · moonlight', size: Size(360, 190))
Widget gardenDarkPreview() => MaterialApp(
  theme: gardenTheme(Brightness.dark),
  home: const Scaffold(
    body: Padding(padding: EdgeInsets.all(20), child: GardenArt()),
  ),
);
