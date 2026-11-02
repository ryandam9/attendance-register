import 'package:flutter/material.dart';

import '../widgets/garden_header.dart';
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
      appBar: AppBar(),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GardenHeader(
                    eyebrow: 'Let it happen naturally',
                    title: 'Arrive. We’ll take it from here.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Allow location access to record office visits '
                    'automatically, even when the app is closed. You can '
                    'change each permission later in Settings.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const PermissionsSection(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Continue to Home'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Set up later · Manual marking always works',
                      textAlign: TextAlign.center,
                    ),
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
