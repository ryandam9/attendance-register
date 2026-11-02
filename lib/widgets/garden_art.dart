import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../themes/garden_theme.dart';

/// Decorative artwork only: flowers never encode attendance or target status.
class GardenArt extends StatelessWidget {
  const GardenArt({super.key});
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
        child: CustomPaint(
          painter: _GardenPainter(
            Theme.of(context).brightness == Brightness.dark,
          ),
        ),
      ),
    ),
  );
}

class _GardenPainter extends CustomPainter {
  const _GardenPainter(this.dark);
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
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
    for (final flower in [
      (74.0, 79.0, const Color(0xFFD38A6D)),
      (150.0, 42.0, const Color(0xFFE1BF6C)),
      (227.0, 89.0, const Color(0xFFF9F7E7)),
    ]) {
      final (x, y, color) = flower;
      canvas.drawLine(
        Offset(x, 145),
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
      for (final delta in [
        const Offset(0, -11),
        const Offset(-11, 0),
        const Offset(11, 0),
        const Offset(0, 11),
      ]) {
        canvas.drawCircle(Offset(x, y) + delta, 12, paint..color = color);
      }
      canvas.drawCircle(
        Offset(x, y),
        5,
        paint..color = const Color(0xFF876645),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GardenPainter oldDelegate) => dark != oldDelegate.dark;
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
