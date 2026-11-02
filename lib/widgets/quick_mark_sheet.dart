import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../helpers/day_marking.dart';
import '../helpers/day_type_helper.dart';
import '../helpers/layout.dart';
import '../helpers/route_helper.dart';
import '../models/attendance_record.dart';
import '../models/office_location.dart';
import '../models/special_day.dart';
import '../screens/day_entry_screen.dart';
import '../services/database_service.dart';
import 'day_status_grid.dart';
import 'garden_tag.dart';

enum _SheetResult { saved, removed, openFull }

/// One-tap day marking: tapping a calendar day opens this bottom sheet with
/// the seven statuses as chips and an optional comment — covering most edits
/// without the full editor. "All options" escalates to [DayEntryScreen] as a
/// desktop dialog or a full-screen mobile page.
///
/// Weekends cannot be marked: an empty weekend day is turned away with a
/// snackbar, and one that already holds an entry (recorded before the rule, or
/// an imported public holiday) opens read-only so the entry can only be
/// removed.
///
/// Returns true when something changed (saved, removed, or edited via the
/// full editor) so the caller knows to refresh.
Future<bool> showQuickMarkSheet(
  BuildContext context, {
  required OfficeLocation office,
  required DateTime date,
}) async {
  final dateKey = DateFormat('yyyy-MM-dd').format(date);
  final existingRecord = await DatabaseService.instance.getAttendanceForDate(
    dateKey,
    office.id!,
  );
  final existingSpecial = await DatabaseService.instance.getSpecialDayForDate(
    dateKey,
  );
  if (!context.mounted) return false;

  if (isWeekendDay(date) && existingRecord == null && existingSpecial == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(weekendNotMarkableMessage),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }

  final sheet = _QuickMarkSheet(
    office: office,
    date: date,
    dateKey: dateKey,
    existingRecord: existingRecord,
    existingSpecial: existingSpecial,
  );

  final _SheetResult? result;
  if (isDesktopWidth(context)) {
    // A bottom-docked sheet sits awkwardly at the foot of a tall desktop
    // window; show a centred dialog instead.
    result = await showDialog<_SheetResult>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: sheet,
            ),
          ),
        ),
      ),
    );
  } else {
    result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      // Scrolls when large text makes the sheet taller than the screen.
      builder: (_) => SingleChildScrollView(child: sheet),
    );
  }

  if (result == _SheetResult.openFull && context.mounted) {
    final changed = await openAdaptivePage<bool>(
      context,
      DayEntryScreen(office: office, initialDate: date),
      desktopSize: const Size(640, 760),
    );
    return changed == true;
  }
  return result == _SheetResult.saved || result == _SheetResult.removed;
}

class _QuickMarkSheet extends ConsumerStatefulWidget {
  final OfficeLocation office;
  final DateTime date;
  final String dateKey;
  final AttendanceRecord? existingRecord;
  final SpecialDay? existingSpecial;

  const _QuickMarkSheet({
    required this.office,
    required this.date,
    required this.dateKey,
    required this.existingRecord,
    required this.existingSpecial,
  });

  @override
  ConsumerState<_QuickMarkSheet> createState() => _QuickMarkSheetState();
}

class _QuickMarkSheetState extends ConsumerState<_QuickMarkSheet> {
  late DayStatus _status;
  late final TextEditingController _comment;
  bool _saving = false;

  bool get _hasExisting =>
      widget.existingRecord != null || widget.existingSpecial != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingRecord != null) {
      _status = DayStatus.attended;
      _comment = TextEditingController(text: widget.existingRecord!.reason);
    } else if (widget.existingSpecial != null) {
      _status = widget.existingSpecial!.type.dayStatus;
      _comment = TextEditingController(text: widget.existingSpecial!.note);
    } else {
      _status = DayStatus.attended;
      _comment = TextEditingController();
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final note = _comment.text.trim();
      await saveDayStatus(
        ref,
        office: widget.office,
        dateKey: widget.dateKey,
        status: _status,
        note: note.isEmpty ? null : note,
        existingSpecial: widget.existingSpecial,
      );
      unawaited(HapticFeedback.lightImpact());
      if (mounted) Navigator.pop(context, _SheetResult.saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Entry'),
        content: Text(
          'Remove the entry for ${DateFormat('MMMM d, yyyy').format(widget.date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await removeDayEntry(
      ref,
      office: widget.office,
      dateKey: widget.dateKey,
      existingSpecial: widget.existingSpecial,
    );
    unawaited(HapticFeedback.lightImpact());
    if (mounted) Navigator.pop(context, _SheetResult.removed);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isToday = isSameDay(widget.date, DateTime.now());
    final isPlanned = isPlannedDay(widget.date);
    // Only reachable with an existing entry (see showQuickMarkSheet), which
    // may be removed but not changed.
    final isWeekend = isWeekendDay(widget.date);

    return Padding(
      // Keep the sheet above the keyboard when the note field is focused.
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.office.name.toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 1.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isToday || isPlanned)
                GardenTag(isToday ? 'Today' : 'Planned'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (widget.date.year == DateTime.now().year
                    ? DateFormat('EEEE, d MMMM')
                    : DateFormat('EEEE, d MMMM yyyy'))
                .format(widget.date),
            style: text.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            isWeekend
                ? '$weekendNotMarkableMessage This entry can only be removed.'
                : isPlanned
                ? 'What have you planned for this day?'
                : 'Where did your day take you?',
            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          DayStatusGrid(
            selected: _status,
            onChanged: isWeekend
                ? null
                : (s) {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() => _status = s);
                  },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _comment,
            enabled: !isWeekend,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'Add a little context…',
              isDense: true,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          if (!isWeekend) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_hasExisting ? 'Update' : 'Save'),
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            children: [
              if (!isWeekend)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(context, _SheetResult.openFull),
                  child: const Text('All options…'),
                ),
              if (_hasExisting)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                  onPressed: _saving ? null : _remove,
                  child: const Text('Remove entry'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
