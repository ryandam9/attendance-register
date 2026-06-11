import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../helpers/day_type_helper.dart';
import '../models/special_day.dart';
import '../providers/office_provider.dart';
import '../services/database_service.dart';
import '../widgets/no_office_placeholder.dart';
import '../widgets/quick_mark_sheet.dart';

/// A single, status-agnostic row in the history list. Attendance records and
/// special days are merged into this shape so they can share one sorted list.
class _HistoryItem {
  final DateTime date;
  final DayStatus status;
  final String? comment;

  const _HistoryItem({required this.date, required this.status, this.comment});
}

/// The History tab: full chronological history of every recorded day
/// (attendance, leave, holidays, WFH), newest first. Tapping a row opens the
/// quick-mark sheet so the entry can be edited or removed.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

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
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);

    final records = await DatabaseService.instance.getAllAttendanceRecords(
      office.id!,
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
          status: s.type.dayStatus,
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
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    final changed = await showQuickMarkSheet(
      context,
      office: office,
      date: item.date,
    );
    if (changed && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final office = ref.watch(officeProvider).selectedOffice;
    if (office == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: const NoOfficePlaceholder(),
      );
    }

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
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final color = item.status.colorIn(context);
                      final isToday = _keyFmt.format(item.date) ==
                          _keyFmt.format(DateTime.now());
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(item.status.icon, color: color),
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
                          label: item.status.label,
                          color: color,
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
              'Days you mark as attended, holiday, sick leave or misc leave '
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
