import 'package:flutter/material.dart';

/// A small rounded label, such as "Today", "Planned" or an office name.
///
/// [muted] gives a quieter outlined look, for states still waiting on the
/// user (e.g. "Not recorded").
class GardenTag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool muted;
  const GardenTag(this.label, {super.key, this.icon, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = muted ? cs.onSurfaceVariant : cs.onPrimaryContainer;
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600);
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 8, 5, 10, 5),
      decoration: BoxDecoration(
        color: muted ? null : cs.primaryContainer,
        border: muted ? Border.all(color: cs.outlineVariant) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: icon == null
          ? Text(label, style: style)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 4),
                Flexible(child: Text(label, style: style)),
              ],
            ),
    );
  }
}
