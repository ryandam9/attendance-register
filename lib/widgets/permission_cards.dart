import 'dart:io';

import 'package:flutter/material.dart';
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
  const PermissionsSection({super.key});

  @override
  State<PermissionsSection> createState() => _PermissionsSectionState();
}

class _PermissionsSectionState extends State<PermissionsSection>
    with WidgetsBindingObserver {
  _PermStatus? _location;
  _PermStatus? _notifications;
  _PermStatus? _battery;
  bool _requesting = false;

  /// permission_handler has no Linux/Windows implementation, so the permission
  /// cards only apply on mobile and macOS. Elsewhere the section shows a note.
  static final bool _supported =
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

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
      // Plugin unavailable on this platform — leave statuses unset; build()
      // shows the unsupported note.
      debugPrint('Permission status check failed: $e');
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
          'Background check-in permissions apply on mobile and macOS only.',
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
            icon: Icons.location_on,
            label: 'Location — Always Allow',
            status: _location!,
            reason:
                'The OS monitors virtual geofence boundaries around your offices '
                'and alerts the app when you enter. Without "Always Allow" automatic check-in will not work.',
            onGrant: () => _grant(PermissionService.requestLocationAlways),
          ),
          const SizedBox(height: 8),
          _PermCard(
            icon: Icons.notifications,
            label: 'Notifications',
            status: _notifications!,
            reason:
                'Needed to alert you when attendance is automatically recorded.',
            onGrant: () => _grant(PermissionService.requestNotifications),
          ),
          if (Platform.isAndroid && _battery != null) ...[
            const SizedBox(height: 8),
            _PermCard(
              icon: Icons.battery_charging_full,
              label: 'Battery Optimisation — Disabled',
              status: _battery!,
              reason:
                  'Prevents Android from aggressively terminating background event-driven '
                  'geofence services, ensuring automatic check-in triggers reliably.',
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
  final IconData icon;
  final String label;
  final _PermStatus status;
  final String reason;
  final VoidCallback onGrant;

  const _PermCard({
    required this.icon,
    required this.label,
    required this.status,
    required this.reason,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    final granted = status == _PermStatus.granted;
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: granted
                        ? Colors.green.withValues(alpha: 0.12)
                        : cs.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        granted
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        size: 14,
                        color: granted ? Colors.green : cs.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        granted ? 'Granted' : 'Denied',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: granted ? Colors.green : cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!granted) ...[
              const SizedBox(height: 12),
              Text(
                reason,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onGrant,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Grant Permission'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
