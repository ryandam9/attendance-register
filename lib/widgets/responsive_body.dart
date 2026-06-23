import 'package:flutter/widgets.dart';

/// Centers and width-limits a screen's body so the mobile-first layout doesn't
/// stretch edge-to-edge on wide windows (desktop/tablet/macOS). The Scaffold
/// background still fills the window — only the content is constrained.
///
/// App bars and the bottom navigation are intentionally left full-width; wrap
/// only the scrolling/content area of a screen with this.
class ResponsiveBody extends StatelessWidget {
  final Widget child;

  /// Phone-friendly content width. Above this, the content centers instead of
  /// growing. 640 keeps forms, the calendar and cards comfortably proportioned.
  final double maxWidth;

  const ResponsiveBody({super.key, required this.child, this.maxWidth = 640});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
