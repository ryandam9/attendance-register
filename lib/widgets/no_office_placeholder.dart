import 'package:flutter/material.dart';

/// Shown on the Insights and History tabs before an office is registered.
class NoOfficePlaceholder extends StatelessWidget {
  const NoOfficePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined,
                size: 64, color: cs.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'No Office Registered',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add an office on the Home tab to start tracking.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
