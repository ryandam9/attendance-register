import 'package:flutter/material.dart';

import '../widgets/permission_cards.dart';
import '../widgets/responsive_body.dart';

/// Shown right after the first office is registered: walks the user through
/// granting the permissions automatic check-in needs (background location,
/// notifications, and battery-optimisation exemption on Android). Without this
/// step the app would silently never auto-record attendance — nothing else in
/// the natural setup flow requests these.
class PermissionSetupScreen extends StatelessWidget {
  const PermissionSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Enable Auto Check-In')),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Your office location is confirmed. Complete these steps to '
                'record attendance when you arrive. Each permission can also '
                'be changed later in Settings.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            const PermissionsSection(showStepNumbers: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_forward),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    label: const Text('Continue to dashboard'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Set up permissions later'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
