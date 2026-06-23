import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../helpers/day_marking.dart';
import '../helpers/day_type_helper.dart';
import '../models/attendance_record.dart';
import '../models/office_location.dart';
import '../models/special_day.dart';
import '../services/database_service.dart';
import '../widgets/responsive_body.dart';

/// Unified screen for marking a day. For any past date or today the user picks
/// one of Attended / Holiday / Sick Leave, optionally adds a comment, and saves
/// — all on one page. Switching between types is seamless because saving one
/// removes any conflicting entry of the other kind.
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

  static final _displayFmt = DateFormat('MMMM d, yyyy');
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
      lastDate: DateTime.now(),
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
    final isToday = isSameDay(_selectedDate, DateTime.now());

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
        appBar: AppBar(title: const Text('Mark a Day')),
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.business_outlined,
                              color: cs.primary,
                            ),
                            title: Text(widget.office.name),
                            subtitle: Text(
                              widget.office.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Date',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: cs.outline),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _displayFmt.format(_selectedDate),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                    if (isToday)
                                      Text(
                                        'Today',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: cs.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                  ],
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right,
                                  color: cs.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final s in DayStatus.values) ...[
                          if (s != DayStatus.values.first)
                            const SizedBox(height: 8),
                          _StatusOption(
                            label: s.label,
                            description: s.description,
                            icon: s.icon,
                            color: s.colorIn(context),
                            selected: _status == s,
                            onTap: () => setState(() {
                              _status = s;
                              _dirty = true;
                            }),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          'Comment',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Optional — add a note for this day.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText:
                                'e.g. Team meeting, doctor appointment, bank holiday…',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notes_outlined),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _loading ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_hasExisting ? 'Update' : 'Save'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        if (_hasExisting) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _remove,
                            icon: Icon(Icons.delete_outline, color: cs.error),
                            label: Text(
                              'Remove Entry',
                              style: TextStyle(color: cs.error),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: cs.error),
                              minimumSize: const Size.fromHeight(48),
                            ),
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

/// A tappable, radio-style card for picking a [DayStatus]. The accent [color]
/// matches the calendar dot used for that status.
class _StatusOption extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : cs.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? color : cs.outline,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? color : cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
