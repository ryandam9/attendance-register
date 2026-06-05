import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/office_location.dart';
import '../providers/attendance_provider.dart';
import '../providers/office_provider.dart';
import 'manual_attendance_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await ref.read(officeProvider.notifier).load();
    _refreshAttendance();
  }

  void _refreshAttendance() {
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    ref.read(attendanceProvider.notifier).loadForMonth(
      office.id!,
      _focusedDay.year,
      _focusedDay.month,
    );
  }

  void _onPageChanged(DateTime day) {
    setState(() => _focusedDay = day);
    final office = ref.read(officeProvider).selectedOffice;
    if (office == null) return;
    ref.read(attendanceProvider.notifier).loadForMonth(
      office.id!,
      day.year,
      day.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final officeState = ref.watch(officeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Office Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => _init()),
          ),
        ],
      ),
      body: () {
        if (officeState.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!officeState.hasOffice) {
          return _EmptyState(
            onAdd: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SetupScreen()),
            ).then((_) => _init()),
          );
        }
        return _Dashboard(
          offices: officeState.offices,
          selected: officeState.selectedOffice!,
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          onOfficeChanged: (o) {
            ref.read(officeProvider.notifier).selectOffice(o);
            _refreshAttendance();
          },
          onFormatChanged: (f) => setState(() => _calendarFormat = f),
          onPageChanged: _onPageChanged,
          onManualCheckIn: () async {
            final officeId = ref.read(officeProvider).selectedOffice!.id!;
            await ref.read(attendanceProvider.notifier).manualCheckIn(officeId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Attendance recorded for today!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        );
      }(),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, size: 80, color: cs.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 24),
            Text(
              'No Office Registered',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Add your office address to start tracking your return-to-office days automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add Office'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard ─────────────────────────────────────────────────────────────────

class _Dashboard extends ConsumerWidget {
  final List<OfficeLocation> offices;
  final OfficeLocation selected;
  final DateTime focusedDay;
  final CalendarFormat calendarFormat;
  final ValueChanged<OfficeLocation> onOfficeChanged;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final ValueChanged<DateTime> onPageChanged;
  final VoidCallback onManualCheckIn;

  const _Dashboard({
    required this.offices,
    required this.selected,
    required this.focusedDay,
    required this.calendarFormat,
    required this.onOfficeChanged,
    required this.onFormatChanged,
    required this.onPageChanged,
    required this.onManualCheckIn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ap = ref.watch(attendanceProvider);
    final attended = ap.attendanceDates;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Office picker — only shown when more than one office exists.
        if (offices.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DropdownButtonFormField<OfficeLocation>(
              value: selected,
              decoration: const InputDecoration(
                labelText: 'Office',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: offices
                  .map((o) => DropdownMenuItem(value: o, child: Text(o.name)))
                  .toList(),
              onChanged: (o) {
                if (o != null) onOfficeChanged(o);
              },
            ),
          ),

        // Stats row
        _StatsRow(
          month: focusedDay,
          monthly: ap.monthlyCount,
          yearly: ap.yearlyCount,
        ),

        // Calendar
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          child: TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: focusedDay,
            calendarFormat: calendarFormat,
            onFormatChanged: onFormatChanged,
            onPageChanged: onPageChanged,
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, _) {
                if (attended.any((d) => isSameDay(d, day))) {
                  return _AttendanceDot(day: day);
                }
                return null;
              },
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Office info chip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(selected.name),
              subtitle: Text(
                selected.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Chip(label: Text('${selected.radius.toInt()} m')),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Manual check-in
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: onManualCheckIn,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Manual Check-In for Today'),
          ),
        ),
      ],
    );
  }
}

// ── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final DateTime month;
  final int monthly;
  final int yearly;

  const _StatsRow({
    required this.month,
    required this.monthly,
    required this.yearly,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: '${DateFormat.MMMM().format(month)} days',
              value: '$monthly',
              color: cs.primaryContainer,
              onColor: cs.onPrimaryContainer,
              icon: Icons.calendar_month_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: '${month.year} total',
              value: '$yearly',
              color: cs.secondaryContainer,
              onColor: cs.onSecondaryContainer,
              icon: Icons.star_outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color onColor;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.onColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: onColor),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: onColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Calendar day marker ───────────────────────────────────────────────────────

class _AttendanceDot extends StatelessWidget {
  final DateTime day;
  const _AttendanceDot({required this.day});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: cs.onPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
