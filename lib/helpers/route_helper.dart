import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'layout.dart';

/// Standard route for pushed screens. Uses MaterialPageRoute so the theme's
/// PageTransitionsTheme applies — including Android's predictive-back preview,
/// which a custom PageRouteBuilder would silently opt out of.
Route<T> appRoute<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => page);

/// The next step of a multi-step flow (e.g. office setup → permissions):
/// Material's shared-axis transition, sliding forward along the x-axis.
/// Reserved for steps, since a custom route forgoes Android's predictive-back
/// preview that [appRoute] keeps for ordinary screens.
Route<T> stepRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 400),
  reverseTransitionDuration: const Duration(milliseconds: 400),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      MediaQuery.disableAnimationsOf(context)
      ? child
      : SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          child: child,
        ),
);

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
