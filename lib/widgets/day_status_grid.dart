import 'package:flutter/material.dart';

import '../helpers/day_type_helper.dart';
import '../models/special_day.dart';

/// The seven day statuses as a two-column grid of soft tiles, shared by the
/// quick-mark sheet and the full day editor. Falls back to one column when
/// there isn't room for two (narrow screens, large text).
class DayStatusGrid extends StatelessWidget {
  final DayStatus selected;

  /// Null disables every tile (e.g. a read-only weekend entry).
  final ValueChanged<DayStatus>? onChanged;

  const DayStatusGrid({super.key, required this.selected, this.onChanged});

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = constraints.maxWidth / scale >= 280 ? 2 : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in DayStatus.values)
              SizedBox(
                width: width,
                child: _StatusTile(
                  status: s,
                  selected: s == selected,
                  onTap: onChanged == null ? null : () => onChanged!(s),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatusTile extends StatelessWidget {
  final DayStatus status;
  final bool selected;
  final VoidCallback? onTap;

  const _StatusTile({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final radius = BorderRadius.circular(14);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Opacity(
                opacity: enabled || selected ? 1 : 0.5,
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.check_circle : status.icon,
                      size: 20,
                      // The status colour links each tile to its calendar dot.
                      color: selected ? cs.primary : status.colorIn(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        status.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
