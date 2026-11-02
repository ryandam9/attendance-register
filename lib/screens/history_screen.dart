import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../helpers/day_marking.dart';
import '../helpers/day_type_helper.dart';
import '../helpers/export_history.dart';
import '../helpers/layout.dart';
import '../models/special_day.dart';
import '../providers/office_provider.dart';
import '../providers/ui_state_provider.dart';
import '../services/database_service.dart';
import '../widgets/desktop_page.dart';
import '../widgets/garden_art.dart';
import '../widgets/garden_header.dart';
import '../widgets/no_office_placeholder.dart';
import '../widgets/quick_mark_action.dart';
import '../widgets/quick_mark_sheet.dart';
import '../widgets/responsive_body.dart';

/// A single, status-agnostic row in the history list. Attendance records and
/// special days are merged into this shape so they can share one sorted list.
class _HistoryItem {
  final DateTime date;
  final DayStatus status;
  final String? comment;

  /// When an office day was recorded, if that happened on the day itself.
  /// Days marked afterwards only know when they were entered, so they have
  /// no time.
  final DateTime? time;

  const _HistoryItem({
    required this.date,
    required this.status,
    this.comment,
    this.time,
  });
}

enum _HistoryFilter { all, office, workFromHome, leaveAndHoliday }

/// The History tab: every recorded day (attendance, leave, holidays, WFH) in
/// one chronological list, newest first — which puts days entered ahead of time
/// (booked leave, imported public holidays) above today, marked "Planned".
/// Tapping a row opens the quick-mark sheet so the entry can be edited or
/// removed.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static final _dateFmt = DateFormat('EEEE, d MMMM yyyy');
  static final _keyFmt = DateFormat('yyyy-MM-dd');
  static final _timeFmt = DateFormat('h:mm a');

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
          time: _keyFmt.format(r.timestamp) == r.date ? r.timestamp : null,
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
      if (_items.isEmpty) {
        return SingleChildScrollView(
          child: _EmptyHistory(
            onMarkToday: _markToday,
            onOpenCalendar: _openCalendar,
          ),
        );
      }
      if (visibleItems.isEmpty) return const _NoMatches();

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
        actions: [
          QuickMarkAction(onChanged: _load),
          if (isDesktopPlatform)
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
        ],
      ),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _mobileList(visibleItems),
        ),
      ),
    );
  }

  Widget _mobileList(List<_HistoryItem> items) {
    final empty = !_loading && _items.isEmpty;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GardenHeader(
            eyebrow: 'Your work journal',
            title: empty ? 'A fresh beginning.' : 'Days, remembered.',
          ),
          if (!_loading && _items.isNotEmpty) ...[
            const SizedBox(height: 16),
            _controls(),
          ],
        ],
      ),
    );
    final Widget? placeholder = _loading
        ? const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        : empty
        ? _EmptyHistory(onMarkToday: _markToday, onOpenCalendar: _openCalendar)
        : items.isEmpty
        ? const _NoMatches()
        : null;
    // Rows plus a closing hint beneath them.
    final count = placeholder != null ? 2 : items.length + 2;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: count,
      itemBuilder: (context, i) {
        if (i == 0) return header;
        if (placeholder != null) return placeholder;
        if (i == count - 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              'Tap an entry to view its note or make a correction.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return _row(items, i - 1, onTap: _openEntry);
      },
    );
  }

  Future<void> _markToday() async {
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    final changed = await showQuickMarkSheet(
      context,
      office: office,
      date: DateTime.now(),
    );
    if (changed && mounted) await _load();
  }

  void _openCalendar() => ref.read(tabIndexProvider.notifier).set(0);

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
      _HistoryFilter.workFromHome: 'Home',
      _HistoryFilter.leaveAndHoliday: 'Leave & holidays',
    };
    return Column(
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
    );
  }

  Widget _list({
    required List<_HistoryItem> items,
    required ValueChanged<_HistoryItem> onTap,
    DateTime? selectedDate,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) =>
          _row(items, i, onTap: onTap, selectedDate: selectedDate),
    );
  }

  /// One journal row — day number tile, "Friday · Office", the note — with
  /// a month eyebrow above the first row of each month.
  Widget _row(
    List<_HistoryItem> items,
    int i, {
    required ValueChanged<_HistoryItem> onTap,
    DateTime? selectedDate,
  }) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final item = items[i];
    final showMonth =
        i == 0 ||
        item.date.year != items[i - 1].date.year ||
        item.date.month != items[i - 1].date.month;
    final lastInMonth =
        i == items.length - 1 ||
        item.date.year != items[i + 1].date.year ||
        item.date.month != items[i + 1].date.month;
    final isToday = _keyFmt.format(item.date) == _keyFmt.format(DateTime.now());
    // Days entered ahead of time sort above today (newest first), so they
    // are labelled to keep them apart from days that actually happened.
    final isPlanned = isPlannedDay(item.date);
    final selected =
        selectedDate != null &&
        _keyFmt.format(item.date) == _keyFmt.format(selectedDate);
    final hasNote = item.comment != null && item.comment!.isNotEmpty;
    final title = [
      DateFormat('EEEE').format(item.date),
      if (isToday) 'Today' else if (isPlanned) 'Planned',
    ].join(' · ');
    final color = item.status.colorIn(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showMonth)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
            child: Text(
              DateFormat('MMMM yyyy').format(item.date).toUpperCase(),
              style: text.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1.4,
              ),
            ),
          ),
        Material(
          color: selected
              ? cs.primaryContainer.withValues(alpha: 0.5)
              : Colors.transparent,
          child: InkWell(
            onTap: () => onTap(item),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                border: lastInMonth
                    ? null
                    : Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  GardenIconTile(
                    color: color,
                    label: DateFormat('dd').format(item.date),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: text.bodyLarge?.copyWith(
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _StatusChip(
                              label: item.status.label,
                              color: color,
                              icon: item.status.icon,
                            ),
                            if (item.time case final time?)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _timeFmt.format(time),
                                    style: text.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (hasNote) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.comment!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ],
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
            if (item.time case final time?) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Checked in at ${_timeFmt.format(time)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
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

/// A day's status as a small tinted tag, e.g. "Attended" or "Work from
/// home", in the same colour as the calendar.
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _StatusChip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 8, 4, 10, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final VoidCallback onMarkToday;
  final VoidCallback onOpenCalendar;
  const _EmptyHistory({
    required this.onMarkToday,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GardenArt(),
          const SizedBox(height: 20),
          Text('Your story starts with a day.', style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'No entries yet for this office. Record today or choose an '
            'earlier day from your calendar.',
            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onMarkToday, child: const Text('Mark today')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onOpenCalendar,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: const Text('Open calendar'),
          ),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No matching days', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Try another filter or search term.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
