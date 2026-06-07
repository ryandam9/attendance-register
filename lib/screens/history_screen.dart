import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app_colors.dart';
import '../models/office_location.dart';
import '../models/special_day.dart';
import '../providers/attendance_provider.dart';
import '../providers/special_day_provider.dart';
import '../services/database_service.dart';
import 'day_entry_screen.dart';

/// A single, status-agnostic row in the history list. Attendance records and
/// special days are merged into this shape so they can share one sorted list.
class _HistoryItem {
  final DateTime date;
  final DayStatus status;
  final String? comment;

  const _HistoryItem({required this.date, required this.status, this.comment});

  Color get color => switch (status) {
    DayStatus.attended => AppColors.attendance,
    DayStatus.holiday => AppColors.holiday,
    DayStatus.sickLeave => AppColors.sickLeave,
    DayStatus.annualLeave => AppColors.annualLeave,
    DayStatus.carersLeave => AppColors.carersLeave,
    DayStatus.notAttended => AppColors.notAttended,
  };

  IconData get icon => switch (status) {
    DayStatus.attended => Icons.check_circle_outline,
    DayStatus.holiday => Icons.beach_access_outlined,
    DayStatus.sickLeave => Icons.sick_outlined,
    DayStatus.annualLeave => Icons.luggage_outlined,
    DayStatus.carersLeave => Icons.volunteer_activism_outlined,
    DayStatus.notAttended => Icons.cancel_outlined,
  };

  String get label => switch (status) {
    DayStatus.attended => 'Attended',
    DayStatus.holiday => 'Public Holiday',
    DayStatus.sickLeave => 'Sick Leave',
    DayStatus.annualLeave => 'Annual Leave',
    DayStatus.carersLeave => "Carer's Leave",
    DayStatus.notAttended => 'Not Attended',
  };
}

/// Full chronological history of every recorded day (attendance, holiday, sick
/// leave and not-attended), newest first. Tapping a row opens the day-entry
/// screen so the entry can be edited or removed.
class HistoryScreen extends ConsumerStatefulWidget {
  final OfficeLocation office;

  const HistoryScreen({super.key, required this.office});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static final _dateFmt = DateFormat('EEE, MMM d, yyyy');
  static final _keyFmt = DateFormat('yyyy-MM-dd');

  List<_HistoryItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final records = await DatabaseService.instance.getAllAttendanceRecords(
      widget.office.id!,
    );
    final specialDays = await DatabaseService.instance.getAllSpecialDays();

    final items = <_HistoryItem>[
      for (final r in records)
        _HistoryItem(
          date: DateTime.parse(r.date),
          status: DayStatus.attended,
          comment: r.reason,
        ),
      for (final s in specialDays)
        _HistoryItem(
          date: DateTime.parse(s.date),
          status: switch (s.type) {
            DayType.holiday => DayStatus.holiday,
            DayType.sickLeave => DayStatus.sickLeave,
            DayType.annualLeave => DayStatus.annualLeave,
            DayType.carersLeave => DayStatus.carersLeave,
            DayType.notAttended => DayStatus.notAttended,
          },
          comment: s.note,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openEntry(_HistoryItem item) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DayEntryScreen(office: widget.office, initialDate: item.date),
      ),
    );
    if (changed == true && mounted) {
      // Stats elsewhere are keyed off the provider; refresh it for the affected
      // month so the dashboard stays in sync, then reload this list.
      await ref.read(attendanceProvider.notifier).loadForMonth(
        widget.office.id!,
        item.date.year,
        item.date.month,
      );
      await ref
          .read(specialDayProvider.notifier)
          .loadForMonth(item.date.year, item.date.month);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const _EmptyHistory()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final isToday = _keyFmt.format(item.date) ==
                          _keyFmt.format(DateTime.now());
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.color.withValues(alpha: 0.15),
                          child: Icon(item.icon, color: item.color),
                        ),
                        title: Text(
                          _dateFmt.format(item.date),
                          style: TextStyle(
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        subtitle: (item.comment != null &&
                                item.comment!.isNotEmpty)
                            ? Text(item.comment!)
                            : null,
                        trailing: _StatusChip(
                          label: item.label,
                          color: item.color,
                        ),
                        onTap: () => _openEntry(item),
                      );
                    },
                  ),
                ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 72,
              color: cs.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No History Yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Days you mark as attended, holiday, sick leave or not attended '
              'will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
