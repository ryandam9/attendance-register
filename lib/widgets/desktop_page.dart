import 'package:flutter/material.dart';

/// Consistent desktop "page" chrome used by the content screens when the app is
/// in its wide layout: a title (with optional subtitle and trailing actions)
/// above a body that fills the remaining space. Mirrors the toolbar + content
/// area of the reference dashboard.
class DesktopPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  /// When set, a back arrow is shown before the title — for pushed pages (e.g.
  /// About) that aren't reachable via the sidebar tabs.
  final VoidCallback? onBack;

  /// Optional cap so very wide windows don't stretch text-heavy content edge to
  /// edge. Null fills the available width.
  final double? maxContentWidth;

  const DesktopPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget body = child;
    if (maxContentWidth != null) {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth!),
          child: child,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                  onPressed: onBack,
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: body),
        ],
      ),
    );
  }
}
