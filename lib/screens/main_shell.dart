import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/layout.dart';
import '../helpers/route_helper.dart';
import '../models/office_location.dart';
import '../providers/attendance_provider.dart';
import '../providers/office_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/special_day_provider.dart';
import '../providers/ui_state_provider.dart';
import '../services/holiday_service.dart';
import '../services/location_service.dart';
import '../themes/bird_art.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/check_in_celebration.dart';
import 'explain_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'mark_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

/// App scaffold: bottom navigation over Home / Insights / History with a
/// fade-through transition between tabs. Each tab is rebuilt when selected so
/// its data is always fresh; state that must survive switches (calendar focus,
/// etc.) lives in ui_state_provider.
///
/// Also owns the app-level lifecycle work that must run regardless of which
/// tab is visible: loading offices at startup, syncing public holidays, and
/// the foreground auto check-in on launch/resume.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  bool _foregroundCheckRunning = false;
  bool _sidebarExtended = true;

  static const _destinations = [
    SidebarDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    SidebarDestination(
      icon: Icons.edit_calendar_outlined,
      selectedIcon: Icons.edit_calendar,
      label: 'Mark',
    ),
    SidebarDestination(
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights,
      label: 'Insights',
    ),
    SidebarDestination(
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      label: 'History',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background geofence triggers write to the database from another isolate,
    // so the in-memory providers go stale while the app is backgrounded.
    if (state == AppLifecycleState.resumed) {
      _refreshFocusedMonth();
      unawaited(_foregroundCheckIn());
    }
  }

  Future<void> _init() async {
    await ref.read(officeProvider.notifier).load();
    _refreshFocusedMonth();
    unawaited(_syncHolidays());
    unawaited(_foregroundCheckIn());
  }

  /// Reloads attendance + special days for the month the calendar is focused
  /// on (the providers feed every tab).
  void _refreshFocusedMonth() {
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    final focused = ref.read(calendarFocusProvider);
    ref
        .read(attendanceProvider.notifier)
        .loadForMonth(office.id!, focused.year, focused.month);
    ref
        .read(specialDayProvider.notifier)
        .loadForMonth(focused.year, focused.month);
  }

  Future<void> _syncHolidays() async {
    final inserted = await HolidayService.instance.sync();
    if (inserted > 0 && mounted) _refreshFocusedMonth();
  }

  /// Safety net for missed geofence events: opening the app while standing in
  /// the office records the day on the spot. Never prompts for permission.
  Future<void> _foregroundCheckIn() async {
    if (_foregroundCheckRunning) return;
    _foregroundCheckRunning = true;
    try {
      final result = await LocationService.performForegroundCheck();
      if (!mounted) return;
      switch (result.status) {
        case ForegroundCheckStatus.recorded:
          _refreshFocusedMonth();
          unawaited(
            showCheckInCelebration(
              context,
              officeName: result.office!.name,
              date: DateTime.now(),
            ),
          );
        case ForegroundCheckStatus.noOfficeLocation:
          // Actionable: the office has no coordinates to match against.
          _checkInSnack(
            'Auto check-in needs your office location. Add it on the office, '
            'then reopen the app while you\'re there.',
            actionLabel: 'Set location',
            onAction: _editOfficeLocation,
          );
        case ForegroundCheckStatus.permissionDenied:
          // Actionable: send the user to the OS location settings.
          _checkInSnack(
            'Location access is off, so auto check-in can\'t run. Turn on '
            'Location Services for this app.',
            actionLabel: 'Open Settings',
            onAction: LocationService.openLocationSettings,
          );
        case ForegroundCheckStatus.tooFar:
          // Read a position, but you're just outside the office radius — say so
          // (a silent miss looks like a bug) and offer to record anyway.
          final office = result.office!;
          final acc = result.accuracyMeters;
          final accNote = (acc != null && acc.isFinite && acc > 150)
              ? ' Your location was only accurate to ±${acc.round()} m.'
              : '';
          _checkInSnack(
            'You\'re about ${_formatDistance(result.distanceMeters!)} from '
            '${office.name} — too far to auto check-in.$accNote',
            actionLabel: 'Check in anyway',
            onAction: () => _checkInAt(office),
          );
        case ForegroundCheckStatus.none:
          break; // not at an office / already recorded — stay quiet
      }
    } finally {
      _foregroundCheckRunning = false;
    }
  }

  void _checkInSnack(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }

  static String _formatDistance(double metres) {
    if (metres >= 1000) {
      return '${(metres / 1000).toStringAsFixed(metres >= 10000 ? 0 : 1)} km';
    }
    return '${metres.round()} m';
  }

  /// Records today's attendance at [office] manually — used by the near-miss
  /// "Check in anyway" action when the user is just outside the radius.
  Future<void> _checkInAt(OfficeLocation office) async {
    final focused = ref.read(calendarFocusProvider);
    final result = await ref
        .read(attendanceProvider.notifier)
        .manualCheckIn(office.id!, focusedMonth: focused);
    if (!mounted) return;
    if (result == CheckInResult.recorded) {
      _refreshFocusedMonth();
      unawaited(
        showCheckInCelebration(
          context,
          officeName: office.name,
          date: DateTime.now(),
        ),
      );
    } else if (result == CheckInResult.specialDayConflict) {
      _checkInSnack('Today is already marked as a holiday or leave.');
    } else {
      _checkInSnack('Today is already recorded for ${office.name}.');
    }
  }

  /// Opens the editor for an office that has no saved location (or the first
  /// office), so the user can add coordinates and enable auto check-in.
  Future<void> _editOfficeLocation() async {
    final offices = ref.read(officeProvider).offices;
    if (offices.isEmpty) return;
    final target = offices.firstWhere(
      (o) => !o.hasLocation,
      orElse: () => offices.first,
    );
    await Navigator.push(context, appRoute(SetupScreen(office: target)));
    if (!mounted) return;
    await ref.read(officeProvider.notifier).load();
    if (mounted) _refreshFocusedMonth();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(tabIndexProvider);

    final content = PageTransitionSwitcher(
      transitionBuilder: (child, animation, secondaryAnimation) =>
          FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          ),
      child: switch (index) {
        1 => const MarkScreen(key: ValueKey('tab-mark')),
        2 => const ExplainScreen(key: ValueKey('tab-insights')),
        3 => const HistoryScreen(key: ValueKey('tab-history')),
        4 => const SettingsScreen(key: ValueKey('tab-settings')),
        _ => const HomeScreen(key: ValueKey('tab-home')),
      },
    );

    // Desktop / wide windows: left navigation sidebar + content that fills the
    // remaining space (no bottom navigation).
    if (isDesktopWidth(context)) {
      final office = ref.watch(officeProvider).selectedOffice;
      final birdAsset = birdAssetForTheme(
        ref.watch(settingsProvider.select((s) => s.themeId)),
      );
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: Row(
          children: [
            AppSidebar(
              destinations: _destinations,
              selectedIndex: index < _destinations.length ? index : null,
              onSelect: (i) => ref.read(tabIndexProvider.notifier).set(i),
              settingsSelected: index == 4,
              onSettings: () => ref.read(tabIndexProvider.notifier).set(4),
              extended: _sidebarExtended,
              onToggleExtended: () =>
                  setState(() => _sidebarExtended = !_sidebarExtended),
              appTitle: 'Attendance Register',
              officeName: office?.name,
              birdAsset: birdAsset,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    // Phones: bottom navigation. Settings (index 4) is only reachable from the
    // desktop sidebar, so clamp the highlighted tab into range here.
    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index.clamp(0, 3),
        onDestinationSelected: (i) {
          unawaited(HapticFeedback.selectionClick());
          ref.read(tabIndexProvider.notifier).set(i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_calendar_outlined),
            selectedIcon: Icon(Icons.edit_calendar),
            label: 'Mark',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
