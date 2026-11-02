import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ephemeral UI state that must survive tab switches. The tab shell rebuilds
/// each tab from scratch when it's selected (so data is always fresh), which
/// would otherwise reset the calendar to "today" every time.

class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int index) => state = index;
}

/// 0 = Home, 1 = Insights (Explain), 2 = History.
final tabIndexProvider = NotifierProvider<TabIndexNotifier, int>(
  TabIndexNotifier.new,
);

class CalendarFocusNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  void set(DateTime day) => state = day;
}

/// The month the home calendar is focused on.
final calendarFocusProvider = NotifierProvider<CalendarFocusNotifier, DateTime>(
  CalendarFocusNotifier.new,
);
