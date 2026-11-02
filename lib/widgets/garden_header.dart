import 'package:flutter/material.dart';

/// The garden page opener: a small spaced-out eyebrow above a large heading,
/// e.g. "YOUR WORK JOURNAL" / "Days, remembered."
class GardenHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  const GardenHeader({super.key, required this.eyebrow, required this.title});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: text.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: text.headlineLarge),
      ],
    );
  }
}

/// A rounded square holding an icon or short text (a day number), tinted
/// with [color]. Leads list rows in Insights and History.
class GardenIconTile extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String? label;
  const GardenIconTile({super.key, required this.color, this.icon, this.label})
    : assert(icon != null || label != null);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(13),
      ),
      child: icon != null
          ? Icon(icon, size: 20, color: color)
          : Text(
              label!,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
    );
  }
}
