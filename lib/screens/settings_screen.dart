import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/office_location.dart';
import '../providers/attendance_provider.dart';
import '../providers/office_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/special_day_provider.dart';
import '../services/app_settings_service.dart';
import '../services/database_service.dart';
import '../services/holiday_service.dart';
import '../themes/bird_themes.dart';
import 'setup_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officeState = ref.watch(officeProvider);
    final notifier = ref.read(officeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionLabel('Offices'),
          ...officeState.offices.map(
            (o) => _OfficeTile(
              office: o,
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SetupScreen(office: o)),
              ).then((_) => notifier.load()),
              onDelete: () => _confirmDelete(context, notifier, o),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: const Text('Add Another Office'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SetupScreen()),
            ).then((_) => notifier.load()),
          ),

          const Divider(height: 32),

          const _SectionLabel('Permissions'),
          const _PermissionsSection(),

          const Divider(height: 32),

          const Divider(height: 32),

          const _SectionLabel('Theme'),
          const _ThemePicker(),

          const Divider(height: 32),

          const _SectionLabel('How It Works'),
          const ListTile(
            leading: Icon(Icons.schedule_outlined),
            title: Text('Automatic Check-In'),
            subtitle: Text(
              'The app checks your GPS position every 15 minutes. '
              'When you are within the detection radius of a registered office, '
              'your attendance is automatically recorded once per day.',
            ),
            isThreeLine: true,
          ),
          const ListTile(
            leading: Icon(Icons.battery_saver_outlined),
            title: Text('Battery Tip'),
            subtitle: Text(
              'For reliable background tracking:\n'
              '• Grant "Always Allow" location permission\n'
              '• Disable battery optimisation for this app\n'
              '• On Android 12+ allow "Exact Alarm" permission',
            ),
            isThreeLine: true,
          ),
          const ListTile(
            leading: Icon(Icons.touch_app_outlined),
            title: Text('Manual Check-In'),
            subtitle: Text(
              'You can also tap "Manual Check-In" on the home screen to record today\'s attendance manually.',
            ),
            isThreeLine: true,
          ),

          const Divider(height: 32),

          const _SectionLabel('Public Holidays'),
          const ListTile(
            leading: Icon(Icons.beach_access_outlined),
            title: Text('Automatic Holidays'),
            subtitle: Text(
              'Public holidays for your office\'s region are highlighted '
              'automatically. Anything you mark or remove yourself always takes '
              'priority and is never overwritten.',
            ),
            isThreeLine: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () => _syncHolidays(context, ref),
              icon: const Icon(Icons.refresh),
              label: const Text('Sync Public Holidays Now'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),

          const Divider(height: 32),

          const _SectionLabel('Developer'),
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
        ],
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

// ── Permissions section ───────────────────────────────────────────────────────

enum _PermStatus { granted, denied }

class _PermissionsSection extends StatefulWidget {
  const _PermissionsSection();

  @override
  State<_PermissionsSection> createState() => _PermissionsSectionState();
}

class _PermissionsSectionState extends State<_PermissionsSection>
    with WidgetsBindingObserver {
  _PermStatus? _location;
  _PermStatus? _notifications;
  _PermStatus? _battery; // Android only

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final loc = await Permission.locationAlways.status;
    final notif = await Permission.notification.status;
    _PermStatus? bat;
    if (Platform.isAndroid) {
      bat = (await Permission.ignoreBatteryOptimizations.isGranted)
          ? _PermStatus.granted
          : _PermStatus.denied;
    }
    if (!mounted) return;
    setState(() {
      _location = loc.isGranted ? _PermStatus.granted : _PermStatus.denied;
      _notifications = notif.isGranted ? _PermStatus.granted : _PermStatus.denied;
      _battery = bat;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_location == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        _PermRow(
          label: 'Location — Always Allow',
          status: _location!,
          reason:
              'The app checks your GPS every 15 minutes while running in the '
              'background. Without "Always Allow" automatic check-in will not work.',
          onOpenSettings: AppSettingsService.openLocation,
        ),
        _PermRow(
          label: 'Notifications',
          status: _notifications!,
          reason: 'Needed to alert you when attendance is automatically recorded.',
          onOpenSettings: AppSettingsService.openNotifications,
        ),
        if (Platform.isAndroid && _battery != null)
          _PermRow(
            label: 'Battery Optimisation — Disabled',
            status: _battery!,
            reason:
                'Prevents Android from killing the background scan. Without this '
                'the 15-minute location check may stop firing.',
            onOpenSettings: AppSettingsService.openBatteryOptimization,
          ),
      ],
    );
  }
}

class _PermRow extends StatelessWidget {
  final String label;
  final _PermStatus status;
  final String reason;
  final VoidCallback onOpenSettings;

  const _PermRow({
    required this.label,
    required this.status,
    required this.reason,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final granted = status == _PermStatus.granted;
    final iconColor =
        granted ? Colors.green : Theme.of(context).colorScheme.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                granted ? Icons.check_circle : Icons.cancel,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!granted)
                TextButton(
                  onPressed: onOpenSettings,
                  child: const Text('Open Settings'),
                ),
            ],
          ),
          if (!granted)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: Text(
                reason,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Theme picker ─────────────────────────────────────────────────────────────

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(settingsProvider).themeId;
    final notifier = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Choose a colour theme inspired by Australian birds.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        for (final theme in birdThemes)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.primary,
              radius: 14,
              child: currentId == theme.id
                  ? Icon(Icons.check, size: 16, color: theme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                  : null,
            ),
            title: Text(theme.name),
            trailing: currentId == theme.id
                ? Icon(Icons.radio_button_checked, color: cs.primary)
                : const Icon(Icons.radio_button_unchecked),
            onTap: () => notifier.setThemeId(theme.id),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
