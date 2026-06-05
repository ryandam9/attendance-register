import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../app_colors.dart';
import '../models/special_day.dart';
import '../providers/special_day_provider.dart';
import '../services/database_service.dart';

class SpecialDayScreen extends ConsumerStatefulWidget {
  final int officeId;
  final DateTime? initialDate;
  final DayType? initialType;

  const SpecialDayScreen({
    super.key,
    required this.officeId,
    this.initialDate,
    this.initialType,
  });

  @override
  ConsumerState<SpecialDayScreen> createState() => _SpecialDayScreenState();
}

class _SpecialDayScreenState extends ConsumerState<SpecialDayScreen> {
  late DateTime _selectedDate;
  DayType _dayType = DayType.holiday;
  final _noteController = TextEditingController();
  bool _loading = false;
  SpecialDay? _existing;
  bool _dateHasAttendance = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _dayType = widget.initialType ?? DayType.holiday;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDate());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDate() async {
    setState(() => _loading = true);
    final dateStr = _fmt(_selectedDate);
    final special =
        await DatabaseService.instance.getSpecialDayForDate(dateStr);
    final hasAttendance = await DatabaseService.instance.hasAttendanceForDate(
      dateStr,
      widget.officeId,
    );
    setState(() {
      _existing = special;
      _dateHasAttendance = hasAttendance;
      if (special != null) {
        _dayType = special.type;
        _noteController.text = special.note ?? '';
      } else {
        _dayType = widget.initialType ?? DayType.holiday;
        _noteController.clear();
      }
      _loading = false;
    });
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && !isSameDay(picked, _selectedDate)) {
      setState(() => _selectedDate = picked);
      await _loadDate();
    }
  }

  Future<void> _save() async {
    if (_dateHasAttendance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This date already has an attendance record. '
            'Remove it first before marking as holiday or sick leave.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final day = SpecialDay(
        id: _existing?.id,
        date: _fmt(_selectedDate),
        type: _dayType,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      await ref.read(specialDayProvider.notifier).saveDay(day);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Entry'),
        content: const Text('Remove this holiday / sick-leave entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await ref.read(specialDayProvider.notifier).deleteDay(_fmt(_selectedDate));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateLabel = isSameDay(_selectedDate, DateTime.now())
        ? 'Today — ${DateFormat('MMMM d, yyyy').format(_selectedDate)}'
        : DateFormat('MMMM d, yyyy').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Holiday / Sick Leave')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Date picker card
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Date'),
                    subtitle: Text(dateLabel),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickDate,
                  ),
                ),

                const SizedBox(height: 16),

                // Attendance conflict warning
                if (_dateHasAttendance)
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
                              'Attendance is already recorded for this date. '
                              'Remove the attendance record first.',
                              style: TextStyle(color: cs.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_dateHasAttendance) const SizedBox(height: 16),

                // Day type selector
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Type',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<DayType>(
                          segments: const [
                            ButtonSegment(
                              value: DayType.holiday,
                              label: Text('Public Holiday'),
                              icon: Icon(Icons.beach_access_outlined),
                            ),
                            ButtonSegment(
                              value: DayType.sickLeave,
                              label: Text('Sick Leave'),
                              icon: Icon(Icons.sick_outlined),
                            ),
                          ],
                          selected: {_dayType},
                          onSelectionChanged: (s) =>
                              setState(() => _dayType = s.first),
                        ),
                        const SizedBox(height: 4),
                        // Color preview chip
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              Chip(
                                backgroundColor: _dayType == DayType.holiday
                                    ? AppColors.holiday
                                    : AppColors.sickLeave,
                                label: Text(
                                  _dayType == DayType.holiday
                                      ? 'Shown in blue'
                                      : 'Shown in orange',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Note field
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        prefixIcon: Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: _dateHasAttendance ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_existing == null ? 'Save' : 'Update'),
                ),

                if (_existing != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline, color: cs.error),
                    label: Text('Remove', style: TextStyle(color: cs.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.error),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

