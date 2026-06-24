import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../build_info.dart';
import '../helpers/layout.dart';
import '../providers/settings_provider.dart';
import '../themes/bird_art.dart';
import '../widgets/desktop_page.dart';
import '../widgets/responsive_body.dart';

/// What the app is, what it does, and exactly which build/commit is running.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const _features = <(IconData, String, String)>[
    (
      Icons.my_location,
      'Automatic check-in',
      'Records your office days by geofencing (Android & iOS), or when you open '
          'the app at the office (macOS).',
    ),
    (
      Icons.edit_calendar_outlined,
      'Mark any day',
      'Attended, work-from-home, leave or public holiday — from the calendar or '
          'a one-tap quick sheet.',
    ),
    (
      Icons.insights_outlined,
      'Targets & insights',
      'Track your return-to-office percentage against a target, with trends and '
          'a work-style breakdown.',
    ),
    (
      Icons.beach_access_outlined,
      'Public holidays',
      "Synced for your office's region and highlighted automatically; your own "
          'edits always win.',
    ),
    (
      Icons.lock_outline,
      'Private by design',
      'All your data stays on your device — there is no account and no server.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birdAsset = birdAssetForTheme(
      ref.watch(settingsProvider.select((s) => s.themeId)),
    );
    final body = ListView(
      padding: EdgeInsets.zero,
      children: [
        _header(context, birdAsset),
        const SizedBox(height: 24),
        _sectionTitle(context, 'What it does'),
        const SizedBox(height: 8),
        for (final (icon, title, desc) in _features)
          _FeatureRow(icon: icon, title: title, description: desc),
        const SizedBox(height: 20),
        _sectionTitle(context, 'Build'),
        const SizedBox(height: 8),
        _buildCard(context),
        const SizedBox(height: 16),
        _footer(context),
        const SizedBox(height: 8),
      ],
    );

    if (isDesktopWidth(context)) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: DesktopPage(title: 'About', maxContentWidth: 680, child: body),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ResponsiveBody(child: body),
    );
  }

  Widget _header(BuildContext context, String? birdAsset) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 40,
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          child: birdAsset != null
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(birdAsset, fit: BoxFit.contain),
                )
              : const Icon(Icons.event_available, size: 36),
        ),
        const SizedBox(height: 14),
        Text(
          'Attendance Register',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Version ${BuildInfo.version}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Text(
          'A private office-attendance tracker: record your return-to-office '
          'days automatically by location or by hand, and see how you track '
          'against your target.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            const _InfoRow(label: 'Version', value: BuildInfo.version),
            _InfoRow(
              label: 'Commit',
              value: BuildInfo.isStamped ? BuildInfo.commit : 'local build',
              mono: true,
            ),
            if (BuildInfo.buildTime.isNotEmpty)
              const _InfoRow(label: 'Built', value: BuildInfo.buildTime),
            _InfoRow(label: 'Platform', value: platform),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Licensed under the Apache License 2.0 · Copyright 2026 ryandam9',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'github.com/ryandam9/attendance-register',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Bird colour palettes inspired by shandiya/feathers.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _InfoRow({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    )
                  : Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
