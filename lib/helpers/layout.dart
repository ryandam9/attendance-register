import 'package:flutter/widgets.dart';

/// Width at and above which the app switches from the phone layout (bottom
/// navigation, single-column screens) to the desktop layout (left navigation
/// sidebar, multi-pane screens that fill the window). 840 is Material 3's
/// medium/expanded boundary and comfortably fits the sidebar + content.
const double kDesktopBreakpoint = 840;

/// True when the current window is wide enough for the desktop layout.
bool isDesktopWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
