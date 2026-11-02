import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
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
        ],
      ),
    ),
  );
}
