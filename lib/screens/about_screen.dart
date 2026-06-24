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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _Hero(birdAsset: birdAsset),
        const SizedBox(height: 18),
        _SectionCard(
          icon: Icons.auto_awesome_outlined,
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
        const _SectionCard(
          icon: Icons.tag_outlined,
          title: 'Build',
          child: _BuildInfo(),
        ),
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
          onBack: () => Navigator.maybePop(context),
          child: body,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ResponsiveBody(child: body),
    );
  }
}

/// Gradient hero header: app identity on a coloured, rounded, bordered panel.
class _Hero extends StatelessWidget {
  final String? birdAsset;
  const _Hero({required this.birdAsset});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onHero = cs.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.55)!],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(12),
            child: birdAsset != null
                ? Image.asset(birdAsset!, fit: BoxFit.contain)
                : Icon(Icons.event_available, size: 40, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Attendance Register',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: onHero,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: onHero.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Version ${BuildInfo.version}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: onHero,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'A private office-attendance tracker: record your return-to-office '
            'days automatically by location or by hand, and see how you track '
            'against your target.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: onHero.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded, bordered card with an icon + title header and a body.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
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
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: cs.primary),
        ),
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
          Text(
            'Bird colour palettes inspired by shandiya/feathers.',
            style: style,
          ),
        ],
      ),
    );
  }
}
