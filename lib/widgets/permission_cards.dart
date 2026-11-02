import 'dart:io';

import 'package:flutter/material.dart';

import 'garden_header.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/location_service.dart';
import '../services/permission_service.dart';

enum _PermStatus { granted, denied }

/// Status cards for the permissions automatic check-in depends on — background
/// location, notifications and (Android) battery-optimisation exemption — each
/// with a Grant button that runs the real runtime request (falling back to the
/// settings page once the OS stops showing the dialog).
///
/// Shared by the Settings screen and the first-run permission setup screen.
/// Statuses refresh on app resume, so they update after a trip to the system
/// settings.
class PermissionsSection extends StatefulWidget {
  final bool showStepNumbers;
  const PermissionsSection({super.key, this.showStepNumbers = false});

  @override
  State<PermissionsSection> createState() => _PermissionsSectionState();
}

class _PermissionsSectionState extends State<PermissionsSection>
    with WidgetsBindingObserver {
  _PermStatus? _location;
  _PermStatus? _notifications;
  _PermStatus? _battery;
  bool _requesting = false;

  /// permission_handler is only wired up on mobile: there's no Linux/Windows
  /// implementation, and on the macOS desktop build the plugin fails to register
  /// (MissingPluginException). Elsewhere the section shows a note instead of
  /// querying (which would otherwise spin forever).
  static final bool _supported = Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_supported) _refresh();
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
    try {
      final loc = await Permission.locationAlways.status;
      if (loc.isGranted) {
        await LocationService.instance.syncGeofences();
      }
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
        _notifications = notif.isGranted
            ? _PermStatus.granted
            : _PermStatus.denied;
        _battery = bat;
      });
    } catch (e) {
      // The plugin can be unavailable even on a "supported" platform (e.g. it
      // fails to register). Fall back to "denied" so the section shows cards the
      // user can act on instead of spinning on the loading indicator forever.
      debugPrint('Permission status check failed: $e');
      if (!mounted) return;
      setState(() {
        _location ??= _PermStatus.denied;
        _notifications ??= _PermStatus.denied;
      });
    }
  }

  /// Runs [request], swallowing concurrent taps, then re-reads every status.
  Future<void> _grant(Future<bool> Function() request) async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      await request();
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Text(
          'Background check-in permissions apply on Android and iOS only.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (_location == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          _PermCard(
            step: widget.showStepNumbers ? 1 : null,
            icon: Icons.my_location_outlined,
            label: 'Background location',
            grantedLabel: 'Always allowed',
            actionLabel: 'Allow location access',
            status: _location!,
            reason:
                'Needed to notice when you arrive. Choose "Allow all the time" '
                'or automatic check-in will not work.',
            onGrant: () => _grant(PermissionService.requestLocationAlways),
          ),
          const SizedBox(height: 8),
          _PermCard(
            step: widget.showStepNumbers ? 2 : null,
            icon: Icons.notifications_outlined,
            label: 'Check-in notifications',
            grantedLabel: 'Enabled',
            actionLabel: 'Enable notifications',
            status: _notifications!,
            reason: 'Know when your visit has been recorded.',
            onGrant: () => _grant(PermissionService.requestNotifications),
          ),
          if (Platform.isAndroid && _battery != null) ...[
            const SizedBox(height: 8),
            _PermCard(
              step: widget.showStepNumbers ? 3 : null,
              icon: Icons.battery_charging_full_outlined,
              label: 'Battery settings',
              grantedLabel: 'Not restricted',
              actionLabel: 'Allow background check-in',
              status: _battery!,
              reason:
                  'Stops Android from pausing background check-in to save '
                  'battery.',
              onGrant: () =>
                  _grant(PermissionService.requestIgnoreBatteryOptimizations),
            ),
          ],
        ],
      ),
    );
  }
}

class _PermCard extends StatelessWidget {
  final int? step;
  final IconData icon;
  final String label;
  final String grantedLabel;
  final String actionLabel;
  final _PermStatus status;
  final String reason;
  final VoidCallback onGrant;

  const _PermCard({
    this.step,
    required this.icon,
    required this.label,
    required this.grantedLabel,
    required this.actionLabel,
    required this.status,
    required this.reason,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    final granted = status == _PermStatus.granted;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                step == null
                    ? GardenIconTile(color: cs.primary, icon: icon)
                    : GardenIconTile(color: cs.primary, label: '$step'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: text.bodyLarge),
                      Text(
                        granted ? grantedLabel : reason,
                        style: text.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (granted) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle,
                    color: cs.primary,
                    semanticLabel: 'Granted',
                  ),
                ],
              ],
            ),
            if (!granted) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: onGrant, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
