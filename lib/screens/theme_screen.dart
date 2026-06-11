import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../themes/bird_themes.dart';

class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => notifier.setThemeMode(s.first),
            ),
          ),
          const Divider(height: 24),
          // Material You — the device's wallpaper palette (Android 12+).
          ListTile(
            leading: Icon(Icons.wallpaper_outlined, color: cs.primary),
            title: const Text('Match my wallpaper'),
            subtitle: const Text(
              'Material You — uses your device\'s colour palette (Android 12+; '
              'falls back to Default elsewhere).',
            ),
            trailing: settings.themeId == dynamicThemeId
                ? Icon(Icons.radio_button_checked, color: cs.primary)
                : const Icon(Icons.radio_button_unchecked),
            onTap: () => notifier.setThemeId(dynamicThemeId),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Or choose a colour theme inspired by Australian birds.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          for (final theme in birdThemes)
            ListTile(
              leading: _SwatchRow(theme: theme),
              title: Text(theme.name),
              subtitle: _ThemePreview(theme: theme),
              trailing: settings.themeId == theme.id
                  ? Icon(Icons.radio_button_checked, color: cs.primary)
                  : const Icon(Icons.radio_button_unchecked),
              onTap: () => notifier.setThemeId(theme.id),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// The theme's three colours as overlapping circles, so the choice is no
/// longer a guess from a single swatch.
class _SwatchRow extends StatelessWidget {
  final BirdTheme theme;
  const _SwatchRow({required this.theme});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    Widget dot(Color color) => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: surface, width: 2),
      ),
    );
    return SizedBox(
      width: 50,
      height: 24,
      child: Stack(
        children: [
          Positioned(left: 28, child: dot(theme.tertiary)),
          Positioned(left: 14, child: dot(theme.secondary)),
          Positioned(left: 0, child: dot(theme.primary)),
        ],
      ),
    );
  }
}

/// A miniature "stat bar" rendered in the theme's own colours — a live hint of
/// how the dashboard will look before committing to the theme.
class _ThemePreview extends StatelessWidget {
  final BirdTheme theme;
  const _ThemePreview({required this.theme});

  @override
  Widget build(BuildContext context) {
    Widget bar(Color color, double width) => Container(
      width: width,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          bar(theme.primary, 48),
          const SizedBox(width: 4),
          bar(theme.secondary, 28),
          const SizedBox(width: 4),
          bar(theme.tertiary, 16),
        ],
      ),
    );
  }
}
