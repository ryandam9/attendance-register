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
              'Your office is saved! To record attendance automatically when '
              'you arrive, the app needs a few permissions. You can grant or '
              'change them later in Settings.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const PermissionsSection(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      )),
    );
  }
}
