import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/widgets.dart';

/// Responsive breakpoints used by the app shell and content screens.
///
/// Medium windows get a compact navigation rail while retaining the readable
/// single-column page layouts. Full desktop chrome is reserved for windows
/// that can actually fit a sidebar and useful content beside it.
const double kMediumBreakpoint = 700;
const double kDesktopBreakpoint = 1024;
const double kExpandedDesktopBreakpoint = 1180;

/// True for apps running on a desktop operating system. This is intentionally
/// platform-based rather than width-based: a compact macOS window should still
/// use desktop modal semantics instead of Android-style page pushes.
bool get isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

bool get isMobilePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool isMediumWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= kMediumBreakpoint && width < kDesktopBreakpoint;
}

/// True when the current window is wide enough for the desktop layout.
bool isDesktopWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

bool isExpandedDesktopWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kExpandedDesktopBreakpoint;
