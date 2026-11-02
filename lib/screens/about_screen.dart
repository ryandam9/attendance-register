import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../build_info.dart';
import '../helpers/layout.dart';
import '../widgets/desktop_page.dart';
import '../widgets/garden_art.dart';
import '../widgets/garden_header.dart';
import '../widgets/garden_tag.dart';
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
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const _Hero(),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'What it does',
          child: Column(
            children: [
              for (var i = 0; i < _features.length; i++) ...[
                if (i > 0) const Divider(height: 22),
                _FeatureRow(
                  icon: _features[i].$1,
                  title: _features[i].$2,
                  description: _features[i].$3,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SectionCard(title: 'Build', child: _BuildInfo()),
        const SizedBox(height: 16),
        const _FooterCard(),
      ],
    );

    if (isDesktopWidth(context)) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        body: DesktopPage(
          title: 'About',
          maxContentWidth: 680,
          onBack: isDesktopPlatform ? null : () => Navigator.maybePop(context),
          actions: [
            if (isDesktopPlatform)
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.maybePop(context),
              ),
          ],
          child: body,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isDesktopPlatform,
        title: const Text('About'),
        actions: [
          if (isDesktopPlatform)
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.maybePop(context),
            ),
        ],
      ),
      body: ResponsiveBody(child: body),
    );
  }
}

/// App identity: garden header, artwork, a one-line summary and version.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GardenHeader(
          eyebrow: 'Attendance Register',
          title: 'Room for your workday.',
        ),
        const SizedBox(height: 20),
        const GardenArt(),
        const SizedBox(height: 16),
        Text(
          'A personal record of office days, home days and time away — '
          'recorded automatically by location or by hand.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        const GardenTag('Version ${BuildInfo.version}'),
      ],
    );
  }
}

/// A card with a plain title and a body.
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GardenIconTile(color: cs.primary, icon: icon),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BuildInfo extends StatelessWidget {
  const _BuildInfo();

  @override
  Widget build(BuildContext context) {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
    return Column(
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
      padding: const EdgeInsets.symmetric(vertical: 7),
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
              style:
                  (mono
                          ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                            )
                          : Theme.of(context).textTheme.bodyMedium)
                      ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterCard extends StatelessWidget {
  const _FooterCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.5);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Licensed under the Apache License 2.0', style: style),
          Text('Copyright 2026 ryandam9', style: style),
          Text('github.com/ryandam9/attendance-register', style: style),
          const SizedBox(height: 8),
          Text(
            'Built with AI assistance. Attendance calculations are documented '
            'in Insights so every result can be reviewed.',
            style: style,
          ),
        ],
      ),
    );
  }
}
