import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../helpers/day_type_helper.dart';
import '../helpers/export_history.dart';
import '../helpers/layout.dart';
import '../models/special_day.dart';
import '../providers/office_provider.dart';
import '../services/database_service.dart';
import '../widgets/desktop_page.dart';
import '../widgets/no_office_placeholder.dart';
import '../widgets/quick_mark_sheet.dart';
import '../widgets/responsive_body.dart';

/// A single, status-agnostic row in the history list. Attendance records and
/// special days are merged into this shape so they can share one sorted list.
class _HistoryItem {
  final DateTime date;
  final DayStatus status;
  final String? comment;

  const _HistoryItem({required this.date, required this.status, this.comment});
}

enum _HistoryFilter { all, office, workFromHome, leaveAndHoliday }

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
  bool _exporting = false;
  _HistoryItem? _selected; // desktop master-detail selection
  _HistoryFilter _filter = _HistoryFilter.all;
  String _query = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_HistoryItem> get _visibleItems {
    final query = _query.trim().toLowerCase();
    return _items
        .where((item) {
          final matchesFilter = switch (_filter) {
            _HistoryFilter.all => true,
            _HistoryFilter.office => item.status == DayStatus.attended,
            _HistoryFilter.workFromHome =>
              item.status == DayStatus.workFromHome,
            _HistoryFilter.leaveAndHoliday =>
              item.status != DayStatus.attended &&
                  item.status != DayStatus.workFromHome,
          };
          if (!matchesFilter) return false;
          if (query.isEmpty) return true;
          return item.status.label.toLowerCase().contains(query) ||
              (item.comment?.toLowerCase().contains(query) ?? false) ||
              _dateFmt.format(item.date).toLowerCase().contains(query);
        })
        .toList(growable: false);
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

  Future<void> _exportHistory() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await exportHistoryAsExcel(context);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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

    final visibleItems = _visibleItems;

    Widget results({required bool desktop}) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_items.isEmpty) return const _EmptyHistory();
      if (visibleItems.isEmpty) {
        return const _EmptyHistory(
          title: 'No matching days',
          message: 'Try another filter or search term.',
        );
      }
      if (!desktop) {
        return RefreshIndicator(
          onRefresh: _load,
          child: _list(items: visibleItems, onTap: _openEntry),
        );
      }

      final selected = visibleItems.contains(_selected)
          ? _selected!
          : visibleItems.first;
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: _list(items: visibleItems, onTap: _openEntry),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: _list(
                    items: visibleItems,
                    onTap: (item) => setState(() => _selected = item),
                    selectedDate: selected.date,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(width: 340, child: _detailPanel(selected)),
            ],
          );
        },
      );
    }

    Widget animatedResults({required bool desktop}) {
      final child = KeyedSubtree(
        key: ValueKey(
          _loading
              ? 'history-loading'
              : 'history-${_filter.name}-${visibleItems.isEmpty}',
        ),
        child: results(desktop: desktop),
      );
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return PageTransitionSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (child, animation, secondaryAnimation) =>
            FadeThroughTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            ),
        child: child,
      );
    }

    // Desktop: master-detail — a table-style list on the left, the selected
    // day's details on the right.
    if (isDesktopWidth(context)) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: DesktopPage(
          title: 'History',
          subtitle: _items.isEmpty
              ? 'Every recorded day'
              : '${visibleItems.length} of ${_items.length} recorded days',
          actions: [_desktopExportButton()],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_loading && _items.isNotEmpty) ...[
                _controls(),
                const SizedBox(height: 16),
              ],
              Expanded(child: animatedResults(desktop: true)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: isDesktopPlatform
            ? [
                IconButton(
                  tooltip: 'Export complete history',
                  onPressed: _exporting ? null : _exportHistory,
                  icon: _exporting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.file_download_outlined),
                ),
              ]
            : null,
      ),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_loading && _items.isNotEmpty) _controls(),
            Expanded(child: animatedResults(desktop: false)),
          ],
        ),
      ),
    );
  }

  Widget _desktopExportButton() {
    return FilledButton.icon(
      onPressed: _exporting ? null : _exportHistory,
      icon: _exporting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : const Icon(Icons.file_download_outlined),
      label: Text(_exporting ? 'Preparing…' : 'Export'),
    );
  }

  Widget _controls() {
    final labels = {
      _HistoryFilter.all: 'All',
      _HistoryFilter.office: 'Office',
      _HistoryFilter.workFromHome: 'WFH',
      _HistoryFilter.leaveAndHoliday: 'Leave & holidays',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search dates, statuses or notes',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in _HistoryFilter.values) ...[
                  FilterChip(
                    label: Text(labels[filter]!),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                  if (filter != _HistoryFilter.values.last)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list({
    required List<_HistoryItem> items,
    required ValueChanged<_HistoryItem> onTap,
    DateTime? selectedDate,
  }) {
    final cs = Theme.of(context).colorScheme;
    final monthFmt = DateFormat('MMMM yyyy');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final showMonth =
            i == 0 ||
            item.date.year != items[i - 1].date.year ||
            item.date.month != items[i - 1].date.month;
        final color = item.status.colorIn(context);
        final isToday =
            _keyFmt.format(item.date) == _keyFmt.format(DateTime.now());
        final selected =
            selectedDate != null &&
            _keyFmt.format(item.date) == _keyFmt.format(selectedDate);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showMonth)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  monthFmt.format(item.date),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ListTile(
              selected: selected,
              selectedTileColor: cs.primaryContainer.withValues(alpha: 0.35),
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(item.status.icon, color: color),
              ),
              title: Text(
                _dateFmt.format(item.date),
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              subtitle: (item.comment != null && item.comment!.isNotEmpty)
                  ? Text(
                      item.comment!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 112),
                child: _StatusChip(label: item.status.label, color: color),
              ),
              onTap: () => onTap(item),
            ),
            if (i != items.length - 1) const Divider(height: 1, indent: 72),
          ],
        );
      },
    );
  }

  Widget _detailPanel(_HistoryItem item) {
    final cs = Theme.of(context).colorScheme;
    final color = item.status.colorIn(context);
    final hasNote = item.comment != null && item.comment!.isNotEmpty;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(item.status.icon, color: color, size: 30),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _dateFmt.format(item.date),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: _StatusChip(label: item.status.label, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              'Note',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              hasNote ? item.comment! : 'No note for this day.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: hasNote ? null : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () => _openEntry(item),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Edit / Remove'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
  final String title;
  final String message;
  const _EmptyHistory({
    this.title = 'No History Yet',
    this.message =
        'Days you mark as attended, holiday, leave or work from home will appear here.',
  });

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
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
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
