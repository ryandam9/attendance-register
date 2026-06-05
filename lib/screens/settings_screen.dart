import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/office_location.dart';
import '../providers/office_provider.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<OfficeProvider>(
        builder: (context, provider, _) => ListView(
          children: [
            _SectionLabel('Offices'),
            ...provider.offices.map(
              (o) => _OfficeTile(
                office: o,
                onEdit: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SetupScreen(office: o)),
                ).then((_) => provider.load()),
                onDelete: () => _confirmDelete(context, provider, o),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Add Another Office'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SetupScreen()),
              ).then((_) => provider.load()),
            ),

            const Divider(height: 32),

            _SectionLabel('How It Works'),
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
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OfficeProvider provider,
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
    if (ok == true) await provider.deleteOffice(office.id!);
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
