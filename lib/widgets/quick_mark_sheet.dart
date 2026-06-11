import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../helpers/day_marking.dart';
import '../helpers/day_type_helper.dart';
import '../helpers/route_helper.dart';
import '../models/attendance_record.dart';
import '../models/office_location.dart';
import '../models/special_day.dart';
import '../screens/day_entry_screen.dart';
import '../services/database_service.dart';

enum _SheetResult { saved, removed, openFull }

/// One-tap day marking: tapping a calendar day opens this bottom sheet with
/// the seven statuses as chips and an optional comment — covering most edits
/// without the full-screen push. "All options" escalates to [DayEntryScreen].
///
/// Returns true when something changed (saved, removed, or edited via the
/// full screen) so the caller knows to refresh.
Future<bool> showQuickMarkSheet(
  BuildContext context, {
  required OfficeLocation office,
  required DateTime date,
}) async {
  final dateKey = DateFormat('yyyy-MM-dd').format(date);
  final existingRecord =
      await DatabaseService.instance.getAttendanceForDate(dateKey, office.id!);
  final existingSpecial =
      await DatabaseService.instance.getSpecialDayForDate(dateKey);
  if (!context.mounted) return false;

  final result = await showModalBottomSheet<_SheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _QuickMarkSheet(
      office: office,
      date: date,
      dateKey: dateKey,
      existingRecord: existingRecord,
      existingSpecial: existingSpecial,
    ),
  );

  if (result == _SheetResult.openFull && context.mounted) {
    final changed = await Navigator.push<bool>(
      context,
      appRoute(DayEntryScreen(office: office, initialDate: date)),
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
    final isToday = isSameDay(widget.date, DateTime.now());

    return Padding(
      // Keep the sheet above the keyboard when the comment field is focused.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMMM d').format(widget.date),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (isToday)
                Chip(
                  label: const Text('Today'),
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(color: cs.primary),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in DayStatus.values)
                ChoiceChip(
                  avatar: CircleAvatar(
                    radius: 5,
                    backgroundColor: s.colorIn(context),
                  ),
                  label: Text(s.label),
                  selected: _status == s,
                  selectedColor: s.colorIn(context).withValues(alpha: 0.18),
                  onSelected: (_) {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() => _status = s);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            decoration: const InputDecoration(
              hintText: 'Comment (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes_outlined),
              isDense: true,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_hasExisting)
                IconButton(
                  tooltip: 'Remove entry',
                  icon: Icon(Icons.delete_outline, color: cs.error),
                  onPressed: _saving ? null : _remove,
                ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.pop(context, _SheetResult.openFull),
                child: const Text('All options…'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(_hasExisting ? 'Update' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
