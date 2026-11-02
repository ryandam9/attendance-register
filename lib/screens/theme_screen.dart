import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../themes/app_font.dart';
import '../widgets/garden_art.dart';
import '../widgets/responsive_body.dart';

class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Appearance')),
    body: ResponsiveBody(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Morning or moonlight.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const Text('The same peaceful garden, wherever your day takes you.'),
          const SizedBox(height: 24),
          const GardenArt(),
          const SizedBox(height: 24),
          Text('Mode', style: Theme.of(context).textTheme.titleMedium),
          RadioGroup<ThemeMode>(
            groupValue: ref.watch(settingsProvider).themeMode,
            onChanged: (value) {
              if (value != null) {
                ref.read(settingsProvider.notifier).setThemeMode(value);
              }
            },
            child: Column(
              children: ThemeMode.values
                  .map(
                    (mode) => RadioListTile<ThemeMode>(
                      title: Text(switch (mode) {
                        ThemeMode.system => 'System',
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                      }),
                      subtitle: mode == ThemeMode.system
                          ? const Text('Follow your device appearance')
                          : null,
                      value: mode,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Font', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Each option is shown in its own typeface.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          RadioGroup<AppFont>(
            groupValue: ref.watch(settingsProvider).font,
            onChanged: (value) {
              if (value != null) {
                ref.read(settingsProvider.notifier).setFont(value);
              }
            },
            child: Column(
              children: [
                for (final font in AppFont.values)
                  RadioListTile<AppFont>(
                    value: font,
                    title: Text(
                      font == AppFont.fallback
                          ? '${font.label} (default)'
                          : font.label,
                      style: TextStyle(
                        fontFamily: font.headingFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${font.description} · 70% of 10 days',
                      style: TextStyle(fontFamily: font.body),
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
