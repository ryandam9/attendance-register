import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../build_info.dart';
import '../helpers/layout.dart';
import '../helpers/route_helper.dart';
import '../models/office_location.dart';
import '../models/report_period.dart';
import '../providers/attendance_provider.dart';
import '../providers/office_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/special_day_provider.dart';
import '../services/database_service.dart';
import '../services/export_saver.dart';
import '../services/export_service.dart';
import '../services/holiday_service.dart';
import '../widgets/desktop_page.dart';
import '../widgets/permission_cards.dart';
import '../widgets/responsive_body.dart';
import 'about_screen.dart';
import 'setup_screen.dart';
import 'theme_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officeState = ref.watch(officeProvider);
    final notifier = ref.read(officeProvider.notifier);

    // Automatic check-in is geofencing-based and only works on Android/iOS, so
    // the "How It Works" copy is platform-specific.
    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final isMacOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    final ignoreDismissed = ref.watch(
      settingsProvider.select((s) => s.autoCheckInIgnoreDismissed),
    );
    final String autoCheckInBody;
    if (isMobile) {
      autoCheckInBody =
          'The OS monitors virtual geofence boundaries around your '
          'offices. When you enter an office boundary, the OS wakes the '
          'app in the background to record your attendance automatically '
          'once per day. Opening the app while at the office records it '
          'too.\n\n'
          'You can also tap "Check in for today" on the home screen to '
          'record today\'s attendance manually.';
    } else if (isMacOS) {
      autoCheckInBody =
          'Background geofencing isn\'t available on macOS, so attendance '
          'isn\'t recorded automatically while the app is closed.\n\n'
          'Tap "Check in for today" on the home screen when you\'re at the '
          'office, or mark any day from the calendar.';
    } else {
      autoCheckInBody =
          'Automatic, location-based check-in is only available on Android '
          'and iOS.\n\n'
          'On this platform, tap "Check in for today" on the home screen, or '
          'mark any day from the calendar.';
    }

    // Each settings section as a self-contained block (label + content) so it
    // can be laid out as one column (phone) or two columns (desktop).
    Widget block(String label, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [_SectionLabel(label), ...children],
    );

    final reporting = block('Reporting', const [
      _TargetSection(),
      _FinancialYearSection(),
    ]);
    final offices = block('Offices', [
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
        title: Text(
          officeState.offices.isEmpty ? 'Add Office' : 'Add Another Office',
        ),
        onTap: () => Navigator.push(
          context,
          appRoute(const SetupScreen()),
        ).then((_) => notifier.load()),
      ),
    ]);
    final permissions = block('Automatic Check-In', const [
      PermissionsSection(),
    ]);
    final appearance = block('Appearance', [
      ListTile(
        leading: const Icon(Icons.palette_outlined),
        title: const Text('Theme & Dark Mode'),
        subtitle: const Text('Bird palettes, Material You, light/dark'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, appRoute(const ThemeScreen())),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Text(
          'Bird colour palettes inspired by shandiya/feathers '
          '(github.com/shandiya/feathers), reinterpreted with a different style.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ]);
    final howItWorks = block('How It Works', [
      ExpansionTile(
        leading: const Icon(Icons.schedule_outlined),
        title: const Text('Automatic Check-In'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(autoCheckInBody)],
      ),
      // Battery optimisation only matters for Android's background geofencing.
      if (isMobile)
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
    ]);
    // Only meaningful where auto check-in actually runs (geofencing on mobile,
    // app-open check on macOS).
    final autoCheckIn = (isMobile || isMacOS)
        ? block('Auto Check-In', [
            SwitchListTile(
              secondary: const Icon(Icons.restore_outlined),
              title: const Text('Re-record deleted days'),
              subtitle: const Text(
                'Normally, deleting a day keeps auto check-in from adding it '
                'back. Turn this on to let it record that day again next time '
                'you\'re at the office.',
              ),
              isThreeLine: true,
              value: ignoreDismissed,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .setAutoCheckInIgnoreDismissed(v),
            ),
          ])
        : null;

    final data = block('Data & Privacy', [
      _ExcelExportTile(onExport: () => _exportExcel(context)),
      ListTile(
        leading: const Icon(Icons.file_download_outlined),
        title: const Text('Copy All Data (CSV)'),
        subtitle: const Text(
          'Copies every recorded day to the clipboard. Paste into a file or '
          'spreadsheet to back it up.',
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
    ]);
    final about = block('Help & About', [
      ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('About Attendance Register'),
        subtitle: Text(
          'Version ${BuildInfo.version} · '
          '${BuildInfo.isStamped ? BuildInfo.commit : 'local build'}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, appRoute(const AboutScreen())),
      ),
    ]);
    // A column of blocks separated by dividers.
    Widget column(List<Widget> blocks) => ListView(
      padding: EdgeInsets.zero,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const Divider(height: 32),
          blocks[i],
        ],
      ],
    );

    if (isDesktopWidth(context)) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: DesktopPage(
          title: 'Settings',
          maxContentWidth: 1100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: column([reporting, offices, appearance])),
              const SizedBox(width: 32),
              Expanded(
                child: column([
                  permissions,
                  ?autoCheckIn,
                  howItWorks,
                  data,
                  about,
                ]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ResponsiveBody(
        child: column([
          reporting,
          offices,
          permissions,
          appearance,
          ?autoCheckIn,
          howItWorks,
          data,
          about,
        ]),
      ),
    );
  }

  Future<void> _exportExcel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ExportService.buildXlsx();
    if (result.rows == 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nothing to export yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final now = DateTime.now();
    final stamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final saved = await ExportSaver.saveXlsx(
      result.bytes,
      suggestedName: 'attendance-register-complete-history-$stamp.xlsx',
    );
    final entries =
        '${result.rows} history ${result.rows == 1 ? 'entry' : 'entries'}';
    switch (saved.outcome) {
      case SaveOutcome.saved:
        messenger.showSnackBar(
          SnackBar(
            content: Text('Saved $entries to ${saved.path}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case SaveOutcome.shared:
        messenger.showSnackBar(
          SnackBar(
            content: Text('Exported $entries.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case SaveOutcome.cancelled:
        break;
      case SaveOutcome.error:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not save the file.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All records deleted.')));
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

class _ExcelExportTile extends StatefulWidget {
  final Future<void> Function() onExport;
  const _ExcelExportTile({required this.onExport});

  @override
  State<_ExcelExportTile> createState() => _ExcelExportTileState();
}

class _ExcelExportTileState extends State<_ExcelExportTile> {
  bool _exporting = false;

  Future<void> _runExport() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await widget.onExport();
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ListTile(
      leading: PageTransitionSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        transitionBuilder: (child, animation, secondaryAnimation) =>
            FadeThroughTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            ),
        child: _exporting
            ? const SizedBox(
                key: ValueKey('export-progress'),
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(
                Icons.table_view_outlined,
                key: ValueKey('export-excel'),
              ),
      ),
      title: Text(
        _exporting ? 'Preparing complete history…' : 'Export History',
      ),
      subtitle: const Text(
        'Creates a styled Excel workbook with a summary and every attendance, '
        'leave, holiday and work-from-home entry.',
      ),
      isThreeLine: true,
      enabled: !_exporting,
      onTap: _runExport,
    );
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

/// Slider for the return-to-office target: the percentage at which the
/// dashboard's stat badges and progress bars turn from red to green.
class _TargetSection extends ConsumerStatefulWidget {
  const _TargetSection();

  @override
  ConsumerState<_TargetSection> createState() => _TargetSectionState();
}

class _FinancialYearSection extends ConsumerWidget {
  const _FinancialYearSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingsProvider).financialYearStart;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reporting year', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 2),
          Text(
            'Used when Insights is set to Year.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          SegmentedButton<FinancialYearStart>(
            segments: [
              for (final option in FinancialYearStart.values)
                ButtonSegment(value: option, label: Text(option.label)),
            ],
            selected: {value},
            onSelectionChanged: (selection) => ref
                .read(settingsProvider.notifier)
                .setFinancialYearStart(selection.first),
          ),
        ],
      ),
    );
  }
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;
    final hasAddress = office.address.trim().isNotEmpty;
    // What location is registered — so the user can tell whether auto check-in
    // can work: the address, else the coordinates, else "no location".
    final locationText = hasAddress
        ? office.address
        : office.hasLocation
        ? 'Coordinates: ${office.latitude.toStringAsFixed(5)}, ${office.longitude.toStringAsFixed(5)}'
        : 'No location set — manual check-in only';
    final detailText = office.hasLocation
        ? '${office.radius.toInt()} m radius · auto check-in enabled'
        : 'Edit and add a location to enable automatic check-in';

    return ListTile(
      leading: Icon(
        office.hasLocation
            ? Icons.business_outlined
            : Icons.location_off_outlined,
        color: office.hasLocation ? null : cs.onSurfaceVariant,
      ),
      title: Text(office.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(locationText, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(
            detailText,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: office.hasLocation ? cs.onSurfaceVariant : cs.error,
            ),
          ),
        ],
      ),
      isThreeLine: true,
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
