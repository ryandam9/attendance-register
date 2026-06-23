import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_colors.dart';
import '../providers/settings_provider.dart';
import '../themes/bird_art.dart';
import '../themes/bird_themes.dart';
import '../widgets/responsive_body.dart';

class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ResponsiveBody(
        child: ListView(
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

          // Live preview of the active theme so the choice is never a guess.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Preview',
                style: Theme.of(context).textTheme.labelLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ThemePreviewCard(
              theme: settings.themeId == dynamicThemeId
                  ? null
                  : settings.theme,
              birdAsset: birdAssetForTheme(settings.themeId),
            ),
          ),

          const Divider(height: 24),
          // Material You — the device's wallpaper palette (Android 12+).
          ListTile(
            leading: Icon(Icons.wallpaper_outlined, color: cs.primary),
            title: const Text('Match my wallpaper'),
            subtitle: const Text(
              'Material You — uses your device\'s colour palette (Android 12+; '
              'falls back to Rainbow Bee-eater elsewhere).',
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
              leading: _ThemeLeading(theme: theme),
              title: Text(theme.name),
              subtitle: Text(theme.description),
              trailing: settings.themeId == theme.id
                  ? Icon(Icons.radio_button_checked, color: cs.primary)
                  : const Icon(Icons.radio_button_unchecked),
              onTap: () => notifier.setThemeId(theme.id),
            ),
          const SizedBox(height: 16),
        ],
      )),
    );
  }
}

/// Row leading: the theme's bird illustration when one exists, otherwise the
/// overlapping colour swatches.
class _ThemeLeading extends StatelessWidget {
  final BirdTheme theme;
  const _ThemeLeading({required this.theme});

  @override
  Widget build(BuildContext context) {
    final asset = birdAssetForTheme(theme.id);
    if (asset == null) return _SwatchRow(theme: theme);
    return SizedBox(
      width: 52,
      child: Center(
        child: Image.asset(asset, width: 52, height: 40, fit: BoxFit.contain),
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

/// A small mock of the key UI surfaces (app bar, primary button, info message,
/// status chip) rendered in a [theme]'s colours — or the live Material You
/// scheme when [theme] is null.
class _ThemePreviewCard extends StatelessWidget {
  final BirdTheme? theme;
  final String? birdAsset;
  const _ThemePreviewCard({required this.theme, this.birdAsset});

  static Color _on(Color background) =>
      background.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = theme?.primary ?? cs.primary;
    final secondary = theme?.secondary ?? cs.secondary;
    final tertiary = theme?.tertiary ?? cs.tertiary;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Faux app bar (with the theme's bird, when available).
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.menu, size: 18, color: _on(primary)),
                  const SizedBox(width: 8),
                  Text(
                    'App bar',
                    style: TextStyle(
                      color: _on(primary),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (birdAsset != null)
                    Image.asset(birdAsset!, width: 40, height: 26, fit: BoxFit.contain),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Primary button.
            Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: secondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Primary button',
                style: TextStyle(
                  color: _on(secondary),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Info message + status chip.
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: tertiary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tertiary.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: tertiary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Info message',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.attendance.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Attended',
                    style: TextStyle(
                      color: AppColors.attendance,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
