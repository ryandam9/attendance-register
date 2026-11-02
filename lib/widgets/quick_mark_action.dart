import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/layout.dart';
import '../providers/attendance_provider.dart';
import '../providers/explain_provider.dart';
import '../providers/office_provider.dart';
import '../providers/special_day_provider.dart';
import '../providers/ui_state_provider.dart';
import 'quick_mark_sheet.dart';

/// Opens the quick editor for today, then refreshes everything that shows
/// today's status. Returns whether anything changed.
Future<bool> quickMarkToday(BuildContext context, WidgetRef ref) async {
  final office = ref.read(officeProvider).selectedOffice;
  if (office == null) return false;
  final changed = await showQuickMarkSheet(
    context,
    office: office,
    date: DateTime.now(),
  );
  if (!changed || !context.mounted) return changed;
  final focused = ref.read(calendarFocusProvider);
  ref
      .read(attendanceProvider.notifier)
      .loadForMonth(office.id!, focused.year, focused.month);
  ref
      .read(specialDayProvider.notifier)
      .loadForMonth(focused.year, focused.month);
  ref.invalidate(breakdownProvider);
  ref.invalidate(weeklyTrendProvider);
  return true;
}

/// A small "Mark today" button for the title bar of phone screens, so the
/// shortcut doesn't take a floating button and its reserved space.
class QuickMarkAction extends ConsumerWidget {
  /// Called after today was changed, e.g. to reload a list on the screen.
  final VoidCallback? onChanged;
  const QuickMarkAction({super.key, this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasOffice = ref.watch(officeProvider).selectedOffice != null;
    // Tablets already have this action at the top of the navigation rail.
    if (isMediumWidth(context)) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Mark today',
      onPressed: !hasOffice
          ? null
          : () async {
              if (await quickMarkToday(context, ref)) onChanged?.call();
            },
      icon: const Icon(Icons.edit_calendar_outlined),
    );
  }
}
