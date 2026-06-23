import 'package:flutter/material.dart';

/// One navigation entry in [AppSidebar].
class SidebarDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const SidebarDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// The desktop left navigation sidebar. Shows the app identity, a list of
/// primary destinations with an active "pill", a pinned Settings entry, the
/// current office, and a collapse toggle that switches between the labelled
/// (extended) and icon-only (collapsed) widths.
class AppSidebar extends StatelessWidget {
  static const double extendedWidth = 248;
  static const double collapsedWidth = 76;

  final List<SidebarDestination> destinations;

  /// Index of the selected destination, or null when Settings is selected.
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  final bool settingsSelected;
  final VoidCallback onSettings;

  final bool extended;
  final VoidCallback onToggleExtended;

  final String appTitle;
  final String? officeName;
  final String? birdAsset;

  const AppSidebar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.settingsSelected,
    required this.onSettings,
    required this.extended,
    required this.onToggleExtended,
    required this.appTitle,
    this.officeName,
    this.birdAsset,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: extended ? extendedWidth : collapsedWidth,
      color: cs.surface,
      // While the width animates between collapsed/expanded, lay the content out
      // at its destination width and clip the rest — otherwise the extended rows
      // (icon + label) are momentarily squeezed below their natural width and
      // overflow.
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: extended ? extendedWidth : collapsedWidth,
          maxWidth: extended ? extendedWidth : collapsedWidth,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context),
                const SizedBox(height: 8),
                for (var i = 0; i < destinations.length; i++)
                  _SidebarTile(
                    icon: destinations[i].icon,
                    selectedIcon: destinations[i].selectedIcon,
                    label: destinations[i].label,
                    selected: !settingsSelected && selectedIndex == i,
                    extended: extended,
                    onTap: () => onSelect(i),
                  ),
                const Spacer(),
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 8),
                _SidebarTile(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: 'Settings',
                  selected: settingsSelected,
                  extended: extended,
                  onTap: onSettings,
                ),
                const SizedBox(height: 8),
                if (officeName != null) _officeCard(context),
                _collapseToggle(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
      child: birdAsset != null
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(birdAsset!, fit: BoxFit.contain),
            )
          : const Icon(Icons.event_available, size: 20),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(extended ? 16 : 0, 14, extended ? 12 : 0, 6),
      child: Row(
        mainAxisAlignment: extended
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          avatar,
          if (extended) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                appTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _officeCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!extended) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Tooltip(
          message: officeName!,
          child: Icon(Icons.business_outlined, color: cs.onSurfaceVariant),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.business_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    officeName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Active office',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collapseToggle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggleExtended,
        child: Container(
          height: 44,
          alignment: extended ? Alignment.centerLeft : Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 0),
          child: Row(
            mainAxisAlignment: extended
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                extended ? Icons.chevron_left : Icons.chevron_right,
                color: cs.onSurfaceVariant,
                size: 22,
              ),
              if (extended) ...[
                const SizedBox(width: 12),
                Text(
                  'Collapse',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    final iconColor = selected ? cs.primary : cs.onSurfaceVariant;
    final iconWidget = Icon(
      selected ? selectedIcon : icon,
      size: 22,
      color: iconColor,
    );

    final child = extended
        ? Row(
            children: [
              iconWidget,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          )
        : iconWidget;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 8, vertical: 3),
      child: Material(
        color: selected
            ? cs.primaryContainer.withValues(alpha: 0.6)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Tooltip(
            message: extended ? '' : label,
            child: Container(
              height: 46,
              alignment: extended ? Alignment.centerLeft : Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 0),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
