import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../app_colors.dart';
import '../models/attendance_record.dart';
import '../models/office_location.dart';
import '../models/special_day.dart';
import '../providers/attendance_provider.dart';
import '../services/database_service.dart';

class ManualAttendanceScreen extends ConsumerStatefulWidget {
  final OfficeLocation office;
  final DateTime? initialDate;

  const ManualAttendanceScreen({super.key, required this.office, this.initialDate});

  @override
  ConsumerState<ManualAttendanceScreen> createState() =>
      _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState
    extends ConsumerState<ManualAttendanceScreen> {
  late DateTime _selectedDate;
  final _reasonController = TextEditingController();
  AttendanceRecord? _existingRecord;
  SpecialDay? _existingSpecialDay;
  bool _isPresent = false;
  bool _loading = false;

  static final _displayFmt = DateFormat('MMMM d, yyyy');
  static final _keyFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadExistingRecord();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingRecord() async {
    setState(() => _loading = true);
    final dateStr = _keyFmt.format(_selectedDate);
    final record = await DatabaseService.instance.getAttendanceForDate(
      dateStr,
      widget.office.id!,
    );
    final special = await DatabaseService.instance.getSpecialDayForDate(dateStr);
    setState(() {
      _existingRecord = record;
      _existingSpecialDay = special;
      _isPresent = record != null;
      _reasonController.text = record?.reason ?? '';
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select attendance date',
    );
    if (picked != null && !isSameDay(picked, _selectedDate)) {
      setState(() => _selectedDate = picked);
      await _loadExistingRecord();
    }
  }

  Future<void> _save() async {
    if (_isPresent && _existingSpecialDay != null) {
      final typeLabel = _existingSpecialDay!.type == DayType.holiday
          ? 'a public holiday'
          : 'a sick leave day';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This date is already marked as $typeLabel. '
            'Remove that entry first before marking attendance.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_isPresent && _existingRecord != null) {
      final dateLabel = _displayFmt.format(_selectedDate);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Attendance'),
          content: Text('Remove the attendance record for $dateLabel?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _loading = true);
    try {
      final dateStr = _keyFmt.format(_selectedDate);
      final reason = _reasonController.text.trim();

      if (_isPresent) {
        await ref.read(attendanceProvider.notifier).saveRecord(
          widget.office.id!,
          dateStr,
          reason: reason.isEmpty ? null : reason,
        );
      } else if (_existingRecord != null) {
        await ref.read(attendanceProvider.notifier).deleteRecord(
          dateStr,
          widget.office.id!,
        );
      }

      if (mounted) {
        setState(() => _loading = false);
        Navigator.pop(context, true);
      }
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isToday = isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Manual Attendance')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _loading
            ? const Center(key: ValueKey('loading'), child: CircularProgressIndicator())
            : SingleChildScrollView(
                key: const ValueKey('content'),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Office card
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.business_outlined, color: cs.primary),
                        title: Text(widget.office.name),
                        subtitle: Text(
                          widget.office.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Date picker
                    Text('Date', style: Theme.of(context).textTheme.titleMedium),
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
                            Icon(Icons.calendar_today_outlined, color: cs.primary),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayFmt.format(_selectedDate),
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                if (isToday)
                                  Text(
                                    'Today',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Special day conflict warning
                    if (_existingSpecialDay != null) ...[
                      Card(
                        color: cs.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.warning_outlined, color: cs.onErrorContainer),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This date is already marked as a '
                                  '${_existingSpecialDay!.type == DayType.holiday ? 'public holiday' : 'sick leave day'}. '
                                  'Remove that entry first.',
                                  style: TextStyle(color: cs.onErrorContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Presence toggle
                    Text(
                      'Attendance Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: cs.outline),
                      ),
                      child: SwitchListTile(
                        title: const Text('Mark as Present'),
                        subtitle: Text(
                          _isPresent
                              ? 'Marked as present for this day'
                              : 'Not marked as present',
                        ),
                        value: _isPresent,
                        onChanged: _existingSpecialDay != null
                            ? null
                            : (v) => setState(() => _isPresent = v),
                      ),
                    ),

                    // Reason field — animated show/hide when toggle changes.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _isPresent
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 20),
                                Text(
                                  'Reason',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Optional — describe why you are recording this manually.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _reasonController,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'e.g. Regular office day, Team meeting, Missed auto check-in…',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.notes_outlined),
                                    alignLabelWithHint: true,
                                  ),
                                  maxLines: 3,
                                  textCapitalization: TextCapitalization.sentences,
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 24),

                    // Status banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _existingRecord != null
                            ? AppColors.attendance.withValues(alpha: 0.12)
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _existingRecord != null
                                ? Icons.check_circle_outline
                                : Icons.highlight_off_outlined,
                            color: _existingRecord != null
                                ? AppColors.attendance
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _existingRecord != null
                                ? 'Attendance recorded for this day'
                                : 'Attendance not recorded for this day',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _existingRecord != null
                                  ? AppColors.attendance
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Save
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
