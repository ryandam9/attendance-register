import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/attendance_record.dart';
import '../models/office_location.dart';
import '../providers/attendance_provider.dart';
import '../services/database_service.dart';

class ManualAttendanceScreen extends ConsumerStatefulWidget {
  final OfficeLocation office;

  const ManualAttendanceScreen({super.key, required this.office});

  @override
  ConsumerState<ManualAttendanceScreen> createState() =>
      _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState
    extends ConsumerState<ManualAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  final _reasonController = TextEditingController();
  AttendanceRecord? _existingRecord;
  bool _isPresent = false;
  bool _loading = false;

  static final _displayFmt = DateFormat('MMMM d, yyyy');
  static final _keyFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _loadExistingRecord();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingRecord() async {
    setState(() => _loading = true);
    final record = await DatabaseService.instance.getAttendanceForDate(
      _keyFmt.format(_selectedDate),
      widget.office.id!,
    );
    setState(() {
      _existingRecord = record;
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
    setState(() => _loading = true);
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

    setState(() => _loading = false);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _confirmRemove() async {
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
    if (confirmed == true && mounted) {
      await ref.read(attendanceProvider.notifier).deleteRecord(
        _keyFmt.format(_selectedDate),
        widget.office.id!,
      );
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isToday = isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Manual Attendance')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Office card
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

                  // Date picker
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
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              if (isToday)
                                Text(
                                  'Today',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
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
                      onChanged: (v) => setState(() => _isPresent = v),
                    ),
                  ),

                  // Reason field — visible only when marked present
                  if (_isPresent) ...[
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

                  const SizedBox(height: 32),

                  // Save
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),

                  // Remove — only shown when a record exists and toggle is off
                  if (_existingRecord != null && !_isPresent) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _confirmRemove,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove Record'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
