import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../themes/bird_themes.dart';

class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(settingsProvider).themeId;
    final notifier = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Theme')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Choose a colour theme inspired by Australian birds.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          for (final theme in birdThemes)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.primary,
                radius: 14,
                child: currentId == theme.id
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: theme.primary.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                      )
                    : null,
              ),
              title: Text(theme.name),
              trailing: currentId == theme.id
                  ? Icon(Icons.radio_button_checked, color: cs.primary)
                  : const Icon(Icons.radio_button_unchecked),
              onTap: () => notifier.setThemeId(theme.id),
            ),
        ],
      ),
    );
  }
}
