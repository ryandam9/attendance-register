import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../helpers/day_marking.dart';
import '../helpers/day_type_helper.dart';
import '../helpers/layout.dart';
import '../models/attendance_record.dart';
import '../models/office_location.dart';
import '../models/special_day.dart';
import '../services/database_service.dart';
import '../widgets/day_status_grid.dart';
import '../widgets/garden_tag.dart';
import '../widgets/responsive_body.dart';

/// Unified screen for marking a day. For any weekday — past, today, or a
/// future one being planned — the user picks one of Attended / Holiday / Sick Leave /
/// … , optionally adds a comment, and saves, all on one page. Switching
/// between types is seamless because saving one removes any conflicting entry
/// of the other kind.
class DayEntryScreen extends ConsumerStatefulWidget {
  final OfficeLocation office;
  final DateTime? initialDate;
  final DayStatus? initialStatus;

  const DayEntryScreen({
    super.key,
    required this.office,
    this.initialDate,
    this.initialStatus,
  });

  @override
  ConsumerState<DayEntryScreen> createState() => _DayEntryScreenState();
}

class _DayEntryScreenState extends ConsumerState<DayEntryScreen> {
  late DateTime _selectedDate;
  DayStatus _status = DayStatus.attended;
  final _commentController = TextEditingController();
  AttendanceRecord? _existingRecord;
  SpecialDay? _existingSpecialDay;
  bool _loading = false;
  bool _dirty = false;

  static final _displayFmt = DateFormat('EEEE, d MMMM yyyy');
  static final _keyFmt = DateFormat('yyyy-MM-dd');

  bool get _hasExisting =>
      _existingRecord != null || _existingSpecialDay != null;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _status = widget.initialStatus ?? DayStatus.attended;
    _commentController.addListener(_onCommentChanged);
    _loadExisting();
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    super.dispose();
  }

  void _onCommentChanged() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    final dateStr = _keyFmt.format(_selectedDate);
    final record = await DatabaseService.instance.getAttendanceForDate(
      dateStr,
      widget.office.id!,
    );
    final special = await DatabaseService.instance.getSpecialDayForDate(
      dateStr,
    );
    if (!mounted) return;
    setState(() {
      _existingRecord = record;
      _existingSpecialDay = special;
      if (record != null) {
        _status = DayStatus.attended;
        _commentController.text = record.reason ?? '';
      } else if (special != null) {
        _status = special.type.dayStatus;
        _commentController.text = special.note ?? '';
      } else {
        _status = widget.initialStatus ?? DayStatus.attended;
        _commentController.clear();
      }
      _dirty = false;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      // Future dates are allowed so leave that is already booked can be
      // entered ahead of time. Matches the home calendar's own range.
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
      // Weekends cannot be marked. The current date stays selectable because
      // the picker asserts that its initialDate passes this predicate.
      selectableDayPredicate: (d) =>
          !isWeekendDay(d) || isSameDay(d, _selectedDate),
      helpText: 'Select a date',
    );
    if (picked != null && !isSameDay(picked, _selectedDate)) {
      setState(() => _selectedDate = picked);
      await _loadExisting();
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final comment = _commentController.text.trim();
      await saveDayStatus(
        ref,
        office: widget.office,
        dateKey: _keyFmt.format(_selectedDate),
        status: _status,
        note: comment.isEmpty ? null : comment,
        existingSpecial: _existingSpecialDay,
      );
      unawaited(HapticFeedback.lightImpact());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _remove() async {
    final dateLabel = _displayFmt.format(_selectedDate);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Entry'),
        content: Text('Remove the entry for $dateLabel?'),
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

    setState(() => _loading = true);
    try {
      await removeDayEntry(
        ref,
        office: widget.office,
        dateKey: _keyFmt.format(_selectedDate),
        existingSpecial: _existingSpecialDay,
      );
      unawaited(HapticFeedback.lightImpact());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isToday = isSameDay(_selectedDate, DateTime.now());
    final isPlanned = isPlannedDay(_selectedDate);
    final isWeekend = isWeekendDay(_selectedDate);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final discard = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Discard Changes?'),
              content: const Text('You have unsaved changes. Discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep Editing'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          if (discard == true && context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !isDesktopPlatform,
          actions: [
            if (isDesktopPlatform)
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.maybePop(context),
              ),
          ],
        ),
        body: ResponsiveBody(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _loading
                ? const Center(
                    key: ValueKey('loading'),
                    child: CircularProgressIndicator(),
                  )
                : SingleChildScrollView(
                    key: const ValueKey('content'),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'MAKE IT YOURS',
                          style: text.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Mark a day.', style: text.headlineLarge),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: GardenTag(widget.office.name),
                        ),
                        const SizedBox(height: 20),
                        _DateField(
                          date: _displayFmt.format(_selectedDate),
                          caption: isWeekend
                              ? weekendNotMarkableMessage
                              : isToday
                              ? 'Today'
                              : isPlanned
                              ? 'Planned ahead'
                              : null,
                          captionIsError: isWeekend,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 24),
                        Text('Day type', style: text.titleMedium),
                        const SizedBox(height: 10),
                        DayStatusGrid(
                          selected: _status,
                          onChanged: (s) => setState(() {
                            _status = s;
                            _dirty = true;
                          }),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                            hintText: 'Team planning, a doctor’s visit…',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _loading || isWeekend ? null : _save,
                          child: Text(_hasExisting ? 'Update' : 'Save'),
                        ),
                        if (_hasExisting) ...[
                          const SizedBox(height: 4),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: cs.error,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: _remove,
                            child: const Text('Remove this entry'),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The tappable date row: the full date, an optional caption beneath it
/// (Today, Planned ahead, or the weekend warning) and a calendar icon.
class _DateField extends StatelessWidget {
  final String date;
  final String? caption;
  final bool captionIsError;
  final VoidCallback onTap;

  const _DateField({
    required this.date,
    required this.caption,
    required this.captionIsError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(16);
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DATE',
                      style: text.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(date, style: text.bodyLarge),
                    if (caption != null)
                      Text(
                        caption!,
                        style: text.bodySmall?.copyWith(
                          color: captionIsError ? cs.error : cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.calendar_month_outlined, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}
