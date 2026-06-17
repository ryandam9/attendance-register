import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/attendance_provider.dart';
import '../providers/office_provider.dart';
import '../providers/special_day_provider.dart';
import '../providers/ui_state_provider.dart';
import '../services/holiday_service.dart';
import '../services/location_service.dart';
import '../services/wifi_service.dart';
import 'explain_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';

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

  // Wi-Fi re-scan while the app is alive. The OS geofence covers the
  // background case; this gives the connected-Wi-Fi path a periodic chance to
  // mark the day (e.g. GPS off) without the user reopening the app. It stops
  // itself for the day as soon as attendance is recorded.
  static const _wifiScanInterval = Duration(minutes: 15);
  Timer? _wifiTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _wifiTimer?.cancel();
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
      _startWifiTimer();
    } else if (state == AppLifecycleState.paused) {
      // No point scanning while backgrounded — Wi-Fi scans are unreliable for
      // a paused app and it would just burn battery.
      _wifiTimer?.cancel();
    }
  }

  Future<void> _init() async {
    await ref.read(officeProvider.notifier).load();
    _refreshFocusedMonth();
    unawaited(_syncHolidays());
    unawaited(_foregroundCheckIn());
    _startWifiTimer();
  }

  /// (Re)starts the periodic Wi-Fi scan. Safe to call repeatedly — it replaces
  /// any existing timer.
  void _startWifiTimer() {
    _wifiTimer?.cancel();
    _wifiTimer = Timer.periodic(_wifiScanInterval, (_) => _wifiCheckIn());
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
  /// the office records the day on the spot. Tries GPS first, then falls back
  /// to the connected Wi-Fi network. Never prompts for permission.
  Future<void> _foregroundCheckIn() async {
    if (_foregroundCheckRunning) return;
    _foregroundCheckRunning = true;
    try {
      var office = await LocationService.performForegroundCheck();
      // GPS may be off or the user indoors — the Wi-Fi network is the backup.
      office ??= await WifiService.performWifiCheck(notify: false);
      if (office == null || !mounted) return;
      _refreshFocusedMonth();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "You're at ${office.name} — attendance recorded for today.",
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      _foregroundCheckRunning = false;
    }
  }

  /// Periodic Wi-Fi-only check (no permission prompt, no GPS). Shows a system
  /// notification on a fresh record so the user gets the same confirmation the
  /// geofence path gives. Refreshes the calendar if the app is still visible.
  Future<void> _wifiCheckIn() async {
    final office = await WifiService.performWifiCheck(notify: true);
    if (office != null && mounted) _refreshFocusedMonth();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(tabIndexProvider);

    return Scaffold(
      body: PageTransitionSwitcher(
        transitionBuilder: (child, animation, secondaryAnimation) =>
            FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        ),
        child: switch (index) {
          1 => const ExplainScreen(key: ValueKey('tab-insights')),
          2 => const HistoryScreen(key: ValueKey('tab-history')),
          _ => const HomeScreen(key: ValueKey('tab-home')),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
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
