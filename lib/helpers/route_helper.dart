import 'package:flutter/material.dart';

import 'layout.dart';

/// Standard route for pushed screens. Uses MaterialPageRoute so the theme's
/// PageTransitionsTheme applies — including Android's predictive-back preview,
/// which a custom PageRouteBuilder would silently opt out of.
Route<T> appRoute<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => page);

/// Opens a secondary task using platform-appropriate navigation.
///
/// Phones and tablets receive a normal full-screen route with predictive-back
/// support. Desktop operating systems receive a bounded modal window so the
/// app sidebar and current workspace remain visible behind the task.
Future<T?> openAdaptivePage<T>(
  BuildContext context,
  Widget page, {
  Size desktopSize = const Size(720, 800),
  bool desktopBarrierDismissible = false,
}) {
  if (!isDesktopPlatform) {
    return Navigator.push<T>(context, appRoute<T>(page));
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: desktopBarrierDismissible,
    useSafeArea: true,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: desktopSize.width,
        height: desktopSize.height,
        child: page,
      ),
    ),
  );
}
