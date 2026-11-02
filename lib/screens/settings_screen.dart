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
import '../widgets/garden_header.dart';
import '../widgets/permission_cards.dart';
import '../widgets/responsive_body.dart';
import 'about_screen.dart';
import 'setup_screen.dart';
import 'theme_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isDesktopWidth(context)) return const _DesktopSettings();
    return const _MobileSettings();
  }
}

/// Automatic check-in is geofencing-based and only works on Android/iOS.
bool get _isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// Platform-specific explanation of automatic check-in.
String get _autoCheckInBody {
  if (_isMobile) {
    return 'The OS monitors virtual geofence boundaries around your '
        'offices. When you enter an office boundary, the OS wakes the '
        'app in the background to record your attendance automatically '
        'once per day. Opening the app while at the office records it '
        'too.\n\n'
        'You can also tap "Check in at the office" on the home screen to '
        'record today\'s attendance manually.';
  }
  if (_isMacOS) {
    return 'Background geofencing isn\'t available on macOS, so attendance '
        'isn\'t recorded automatically while the app is closed.\n\n'
        'Tap "Check in at the office" on the home screen when you\'re at the '
        'office, or mark any day from the calendar.';
  }
  return 'Automatic, location-based check-in is only available on Android '
      'and iOS.\n\n'
      'On this platform, tap "Check in at the office" on the home screen, or '
      'mark any day from the calendar.';
}

/// The contents of each settings section, built against the caller's context
/// so the desktop page and each mobile detail page share the same controls.
class _Sections {
  final List<Widget> reporting;
  final List<Widget> offices;
  final List<Widget> permissions;
  final List<Widget> appearance;
  final List<Widget>? autoCheckIn;
  final List<Widget> howItWorks;
  final List<Widget> holidays;
  final List<Widget> data;
  final List<Widget> about;

  const _Sections({
    required this.reporting,
    required this.offices,
    required this.permissions,
    required this.appearance,
    required this.autoCheckIn,
    required this.howItWorks,
    required this.holidays,
    required this.data,
    required this.about,
  });
}

_Sections _buildSections(BuildContext context, WidgetRef ref) {
  final officeState = ref.watch(officeProvider);
  final notifier = ref.read(officeProvider.notifier);
  final isMobile = _isMobile;
  final isMacOS = _isMacOS;
  final ignoreDismissed = ref.watch(
    settingsProvider.select((s) => s.autoCheckInIgnoreDismissed),
  );
  final autoCheckInBody = _autoCheckInBody;

  const reporting = <Widget>[_TargetSection(), _FinancialYearSection()];
  final offices = <Widget>[
    ...officeState.offices.map(
      (o) => _OfficeTile(
        office: o,
        onEdit: () => openAdaptivePage(
          context,
          SetupScreen(office: o),
        ).then((_) => notifier.load()),
        onDelete: () => _confirmDelete(context, notifier, o),
      ),
    ),
    ListTile(
      leading: const Icon(Icons.add_location_alt_outlined),
      title: Text(
        officeState.offices.isEmpty ? 'Add Office' : 'Add Another Office',
      ),
      onTap: () => openAdaptivePage(
        context,
        const SetupScreen(),
      ).then((_) => notifier.load()),
    ),
  ];
  const permissions = <Widget>[PermissionsSection()];
  final appearance = <Widget>[
    ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Theme & Dark Mode'),
      subtitle: const Text('Garden theme · Light, dark, or system'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => openAdaptivePage(
        context,
        const ThemeScreen(),
        desktopSize: const Size(920, 820),
        desktopBarrierDismissible: true,
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text(
        'A calm garden theme, with light and dark appearances. '
        '',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  ];
  final syncButton = OutlinedButton.icon(
    onPressed: () => _syncHolidays(context, ref),
    icon: const Icon(Icons.refresh),
    label: const Text('Sync Public Holidays Now'),
    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
  );
  final howItWorks = <Widget>[
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
        syncButton,
      ],
    ),
  ];
  final holidays = <Widget>[
    const _Paragraph(
      'Public holidays are added for your office\'s region. Change the '
      'region by editing your office.',
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: syncButton,
    ),
    const _NoteCard(
      title: 'Your edits come first',
      body:
          'Days you mark or remove yourself are kept when public holidays '
          'are synced. Holiday and leave entries are reflected in your '
          'attendance breakdown.',
    ),
  ];
  // Only meaningful where auto check-in actually runs (geofencing on mobile,
  // app-open check on macOS).
  final autoCheckIn = (isMobile || isMacOS)
      ? <Widget>[
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
        ]
      : null;

  final data = <Widget>[
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
    const _Subheading('Start fresh'),
    const _Paragraph(
      'Delete every attendance record, leave day and holiday. Offices are '
      'kept. You will be asked to confirm.',
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
  ];
  final about = <Widget>[
    ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('About Attendance Register'),
      subtitle: Text(
        'Version ${BuildInfo.version} · '
        '${BuildInfo.isStamped ? BuildInfo.commit : 'local build'}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => openAdaptivePage(
        context,
        const AboutScreen(),
        desktopSize: const Size(720, 800),
        desktopBarrierDismissible: true,
      ),
    ),
  ];
  return _Sections(
    reporting: reporting,
    offices: offices,
    permissions: permissions,
    appearance: appearance,
    autoCheckIn: autoCheckIn,
    howItWorks: howItWorks,
    holidays: holidays,
    data: data,
    about: about,
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
  final result = await HolidayService.instance.sync();
  if (result.inserted > 0) ref.invalidate(specialDayProvider);
  messenger.showSnackBar(
    SnackBar(
      content: Text(_syncMessage(result)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Says why nothing was added. "No new public holidays" reads as "you are up
/// to date" even when the sync could never have matched anything — an office
/// with no country and state rules out every row in the list.
String _syncMessage(HolidaySyncResult result) {
  final n = result.inserted;
  switch (result.outcome) {
    case HolidaySyncOutcome.added:
      return 'Added $n public holiday${n == 1 ? '' : 's'}.';
    case HolidaySyncOutcome.unchanged:
      return 'No new public holidays to add.';
    case HolidaySyncOutcome.noOffices:
      return 'Add an office first — public holidays are matched on its '
          'country and state.';
    case HolidaySyncOutcome.noRegion:
      return 'No office has a region set, so no holiday can match. Pick one '
          'on the office, then sync again.';
    case HolidaySyncOutcome.unavailable:
      return 'Could not fetch the public holiday list. Check your '
          'connection and try again.';
  }
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
          // Stacked choices rather than a segmented button: the long month
          // ranges cannot sit side by side on a phone with large text.
          for (final option in FinancialYearStart.values)
            Semantics(
              selected: option == value,
              inMutuallyExclusiveGroup: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .setFinancialYearStart(option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        option == value
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: option == value
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(option.label)),
                    ],
                  ),
                ),
              ),
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
              Expanded(
                child: Text(
                  'Return-to-office target',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: 8),
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

// ── Desktop: every section on one two-column page ────────────────────────────

class _DesktopSettings extends ConsumerWidget {
  const _DesktopSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = _buildSections(context, ref);
    Widget block(String label, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [_SectionLabel(label), ...children],
    );
    Widget column(List<Widget> blocks) => ListView(
      padding: EdgeInsets.zero,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const Divider(height: 32),
          blocks[i],
        ],
      ],
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      body: DesktopPage(
        title: 'Settings',
        maxContentWidth: 1100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: column([
                block('Reporting', s.reporting),
                block('Offices', s.offices),
                block('Appearance', s.appearance),
              ]),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: column([
                block('Automatic Check-In', s.permissions),
                if (s.autoCheckIn != null)
                  block('Auto Check-In', s.autoCheckIn!),
                block('How It Works', s.howItWorks),
                block('Data & Privacy', s.data),
                block('Help & About', s.about),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mobile: a short menu, each row opening a focused page ────────────────────

class _MobileSettings extends ConsumerWidget {
  const _MobileSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final offices = ref.watch(officeProvider).offices;
    final settings = ref.watch(settingsProvider);
    final mode = switch (settings.themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'Match system',
    };

    final rows = <Widget>[
      _NavRow(
        icon: Icons.business_outlined,
        title: 'Offices',
        subtitle: offices.isEmpty
            ? 'Add your office'
            : '${offices.map((o) => o.name).join(', ')} · Add or edit',
        page: _SettingsPage(
          eyebrow: 'Where you work',
          title: 'Your offices.',
          intro:
              'Each office has a location and radius used for automatic '
              'check-in.',
          children: (s) => s.offices,
        ),
      ),
      _NavRow(
        icon: Icons.track_changes_outlined,
        title: 'Reporting',
        subtitle:
            '${settings.rtoTarget}% target · '
            '${settings.financialYearStart.label}',
        page: _SettingsPage(
          eyebrow: 'Your own pace',
          title: 'Set your target.',
          intro: 'Choose the office attendance percentage you want to track.',
          children: (s) => [
            ...s.reporting,
            const _Paragraph('Changes save automatically.'),
          ],
        ),
      ),
      _NavRow(
        icon: Icons.my_location_outlined,
        title: 'Automatic check-in',
        subtitle: _isMobile
            ? 'Location, notifications and battery'
            : 'How check-in works here',
        page: _SettingsPage(
          eyebrow: 'Less to remember',
          title: 'Arrive and settle in.',
          children: (s) => [
            ...s.permissions,
            if (s.autoCheckIn != null) ...[
              const _Subheading('After you remove a day'),
              ...s.autoCheckIn!,
            ],
            _NoteCard(
              title: 'How automatic check-in works',
              body: _autoCheckInBody,
            ),
            if (_isMobile)
              const _NoteCard(
                title: 'For reliable background tracking',
                body:
                    'Allow location access "all the time", and turn off '
                    'battery optimisation for this app.',
              ),
          ],
        ),
      ),
      _NavRow(
        icon: Icons.palette_outlined,
        title: 'Appearance',
        subtitle: '$mode · ${settings.font.label}',
        page: const ThemeScreen(),
      ),
      _NavRow(
        icon: Icons.beach_access_outlined,
        title: 'Public holidays',
        subtitle: 'Sync for your office’s region',
        page: _SettingsPage(
          eyebrow: 'Space for life',
          title: 'Days to step away.',
          children: (s) => s.holidays,
        ),
      ),
      _NavRow(
        icon: Icons.ios_share_outlined,
        title: 'Data & privacy',
        subtitle: 'Export Excel, copy CSV, delete records',
        page: _SettingsPage(
          eyebrow: 'Yours to keep',
          title: 'Take your days with you.',
          intro: 'Everything stays on this device until you export it.',
          children: (s) => s.data,
        ),
      ),
      _NavRow(
        icon: Icons.info_outline,
        title: 'About',
        subtitle:
            'Version ${BuildInfo.version} · '
            '${BuildInfo.isStamped ? BuildInfo.commit : 'local build'}',
        page: const AboutScreen(),
        last: true,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: GardenHeader(
                eyebrow: 'A space that fits you',
                title: 'Make yourself at home.',
              ),
            ),
            const SizedBox(height: 20),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(children: rows),
            ),
            const SizedBox(height: 24),
            Text(
              'A little presence. A little growth.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// A focused settings page: garden header, an optional intro line, then one
/// section's controls. Rebuilds live, so edits show immediately.
class _SettingsPage extends ConsumerWidget {
  final String eyebrow;
  final String title;
  final String? intro;
  final List<Widget> Function(_Sections sections) children;

  const _SettingsPage({
    required this.eyebrow,
    required this.title,
    required this.children,
    this.intro,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GardenHeader(eyebrow: eyebrow, title: title),
                  if (intro != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      intro!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...children(_buildSections(context, ref)),
          ],
        ),
      ),
    );
  }
}

/// A Settings menu row that grows into its page with Material's container
/// transform, and shrinks back into the row on return.
class _NavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
  final bool last;

  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget row(VoidCallback open) => InkWell(
      onTap: open,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            GardenIconTile(color: cs.primary, icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.bodyLarge),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
    // With reduced motion, a plain push. (OpenContainer cannot run with a
    // zero duration.)
    if (MediaQuery.disableAnimationsOf(context)) {
      return row(() => Navigator.of(context).push(appRoute<void>(page)));
    }
    return OpenContainer<void>(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 420),
      closedElevation: 0,
      openElevation: 0,
      closedShape: const RoundedRectangleBorder(),
      closedColor: cs.surfaceContainerLow,
      openColor: Theme.of(context).scaffoldBackgroundColor,
      middleColor: Theme.of(context).scaffoldBackgroundColor,
      openBuilder: (context, _) => page,
      closedBuilder: (context, open) => row(open),
    );
  }
}

class _Subheading extends StatelessWidget {
  final String text;
  const _Subheading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Paragraph extends StatelessWidget {
  final String text;
  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// A soft card holding a short explanation.
class _NoteCard extends StatelessWidget {
  final String title;
  final String body;
  const _NoteCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleSmall),
            const SizedBox(height: 6),
            Text(body, style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}
