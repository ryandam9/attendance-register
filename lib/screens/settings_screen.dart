import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/layout.dart';
import '../helpers/route_helper.dart';
import '../models/office_location.dart';
import '../providers/attendance_provider.dart';
import '../providers/office_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/special_day_provider.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/holiday_service.dart';
import '../widgets/desktop_page.dart';
import '../widgets/permission_cards.dart';
import '../widgets/responsive_body.dart';
import 'setup_screen.dart';
import 'theme_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officeState = ref.watch(officeProvider);
    final notifier = ref.read(officeProvider.notifier);

    final content = ListView(
      children: [
          const _SectionLabel('Profile'),
          const _NameSection(),
          const Divider(height: 32),
          const _SectionLabel('Attendance Target'),
          const _TargetSection(),
          const Divider(height: 32),
          const _SectionLabel('Offices'),
          ...officeState.offices.map(
            (o) => _OfficeTile(
              office: o,
              onEdit: () => Navigator.push(
                context,
                appRoute(SetupScreen(office: o)),
              ).then((_) => notifier.load()),
              onDelete: () => _confirmDelete(context, notifier, o),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: const Text('Add Another Office'),
            onTap: () => Navigator.push(
              context,
              appRoute(const SetupScreen()),
            ).then((_) => notifier.load()),
          ),

          const Divider(height: 32),

          const _SectionLabel('Permissions'),
          const PermissionsSection(),

          const Divider(height: 32),

          const _SectionLabel('Appearance'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme & Dark Mode'),
            subtitle: const Text('Bird palettes, Material You, light/dark'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              appRoute(const ThemeScreen()),
            ),
          ),

          const Divider(height: 32),

          // Reference material lives behind expansion tiles so the screen
          // stays short — most visits are for the actionable sections above.
          const _SectionLabel('How It Works'),
          const ExpansionTile(
            leading: Icon(Icons.schedule_outlined),
            title: Text('Automatic Check-In'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The OS monitors virtual geofence boundaries around your '
                'offices. When you enter an office boundary, the OS wakes the '
                'app in the background to record your attendance automatically '
                'once per day. Opening the app while at the office records it '
                'too.\n\n'
                'You can also tap "Check-In for Today" on the home screen to '
                'record today\'s attendance manually.',
              ),
            ],
          ),
          const ExpansionTile(
            leading: Icon(Icons.battery_saver_outlined),
            title: Text('Battery Tip'),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'For reliable background tracking:\n'
                '• Grant "Always Allow" location permission\n'
                '• Disable battery optimisation to keep geofence callbacks reliable',
              ),
            ],
          ),
          ExpansionTile(
            leading: const Icon(Icons.beach_access_outlined),
            title: const Text('Public Holidays'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Public holidays for your office\'s region are highlighted '
                'automatically. Anything you mark or remove yourself always '
                'takes priority and is never overwritten.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _syncHolidays(context, ref),
                icon: const Icon(Icons.refresh),
                label: const Text('Sync Public Holidays Now'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),

          const Divider(height: 32),

          const _SectionLabel('Data'),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export All Data (CSV)'),
            subtitle: const Text(
              'Copies every recorded day — attendance, leave and holidays — to '
              'the clipboard. Paste into a file or spreadsheet to back it up.',
            ),
            isThreeLine: true,
            onTap: () => _exportData(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: OutlinedButton.icon(
              onPressed: () => _confirmDeleteAll(context, ref),
              icon: Icon(
                Icons.delete_sweep_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              label: Text(
                'Delete All Records',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).colorScheme.error),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),

          const Divider(height: 32),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(
              'Disclaimer: This app was fully designed and built by AI '
              '(Claude Opus 4.8) and may not represent the statistics accurately.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
    );

    if (isDesktopWidth(context)) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: DesktopPage(
          title: 'Settings',
          maxContentWidth: 820,
          child: content,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ResponsiveBody(child: content),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ExportService.buildCsv();
    if (result.rows == 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nothing to export yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: result.csv));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${result.rows} day${result.rows == 1 ? '' : 's'} to the clipboard.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _syncHolidays(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Syncing public holidays…')),
    );
    final inserted = await HolidayService.instance.sync();
    if (inserted > 0) ref.invalidate(specialDayProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          inserted > 0
              ? 'Added $inserted public holiday${inserted == 1 ? '' : 's'}.'
              : 'No new public holidays to add.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Records?'),
        content: const Text(
          'This will permanently delete all attendance records and special days '
          '(holidays/sick leave). Office locations are kept.\n\n'
          'This cannot be undone.',
        ),
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
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseService.instance.deleteAllRecords();
    ref.invalidate(attendanceProvider);
    ref.invalidate(specialDayProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All records deleted.')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OfficeNotifier notifier,
    OfficeLocation office,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Office?'),
        content: Text(
          'Delete "${office.name}"?\n\n'
          'All attendance records for this office will also be removed.',
        ),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await notifier.deleteOffice(office.id!);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _NameSection extends ConsumerStatefulWidget {
  const _NameSection();

  @override
  ConsumerState<_NameSection> createState() => _NameSectionState();
}

class _NameSectionState extends ConsumerState<_NameSection> {
  late final TextEditingController _ctrl;
  late final SettingsNotifier _settings;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(settingsProvider.notifier);
    _ctrl = TextEditingController(text: ref.read(settingsProvider).userName);
  }

  @override
  void dispose() {
    // Flush a pending debounced save so backing out right after typing doesn't
    // lose the name.
    if (_debounce?.isActive ?? false) _save(_ctrl.text);
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _save(String value) => _settings.setUserName(value.trim());

  // Persist as the user types (debounced) rather than only on the keyboard's
  // submit action — most people type and navigate back without ever
  // submitting, which used to discard the name.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _save(value));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          labelText: 'Your Name',
          hintText: 'Used in attendance notifications',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person_outline),
        ),
        textCapitalization: TextCapitalization.words,
        onChanged: _onChanged,
        onSubmitted: (v) {
          _debounce?.cancel();
          _save(v);
        },
      ),
    );
  }
}

/// Slider for the return-to-office target: the percentage at which the
/// dashboard's stat badges and progress bars turn from red to green.
class _TargetSection extends ConsumerStatefulWidget {
  const _TargetSection();

  @override
  ConsumerState<_TargetSection> createState() => _TargetSectionState();
}

class _TargetSectionState extends ConsumerState<_TargetSection> {
  // Local value while dragging; persisted on drag end so the database isn't
  // written on every tick.
  int? _dragValue;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(settingsProvider).rtoTarget;
    final value = _dragValue ?? saved;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Return-to-office target',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Chip(label: Text('$value%')),
            ],
          ),
          Text(
            'The share of eligible weekdays you aim to be at the office. '
            'Dashboard stats show green at or above this.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          Slider(
            value: value.toDouble(),
            min: 10,
            max: 100,
            divisions: 18,
            label: '$value%',
            onChanged: (v) => setState(() => _dragValue = v.round()),
            onChangeEnd: (v) {
              ref.read(settingsProvider.notifier).setRtoTarget(v.round());
              setState(() => _dragValue = null);
            },
          ),
        ],
      ),
    );
  }
}

class _OfficeTile extends StatelessWidget {
  final OfficeLocation office;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OfficeTile({
    required this.office,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.business_outlined),
      title: Text(office.name),
      subtitle: Text(
        '${office.address}  •  ${office.radius.toInt()} m radius',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            color: Theme.of(context).colorScheme.error,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
