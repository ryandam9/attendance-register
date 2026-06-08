import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_period.dart';
import '../services/database_service.dart';
import '../themes/bird_themes.dart';

/// Persisted app preferences.
class SettingsState {
  final FinancialYearStart financialYearStart;
  final String themeId;
  final bool loaded;

  const SettingsState({
    this.financialYearStart = FinancialYearStart.january,
    this.themeId = 'default',
    this.loaded = false,
  });

  SettingsState copyWith({
    FinancialYearStart? financialYearStart,
    String? themeId,
    bool? loaded,
  }) =>
      SettingsState(
        financialYearStart: financialYearStart ?? this.financialYearStart,
        themeId: themeId ?? this.themeId,
        loaded: loaded ?? this.loaded,
      );

  BirdTheme get theme => birdThemeById(themeId);
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _fyStartKey = 'financial_year_start';
  static const _themeKey = 'theme_id';

  @override
  SettingsState build() {
    _load();
    return const SettingsState();
  }

  Future<void> _load() async {
    final fyStart = await DatabaseService.instance.getSetting(_fyStartKey);
    final themeId = await DatabaseService.instance.getSetting(_themeKey);
    state = SettingsState(
      financialYearStart: FinancialYearStart.fromName(fyStart),
      themeId: themeId ?? 'default',
      loaded: true,
    );
  }

  Future<void> setFinancialYearStart(FinancialYearStart value) async {
    state = state.copyWith(financialYearStart: value, loaded: true);
    await DatabaseService.instance.setSetting(_fyStartKey, value.name);
  }

  Future<void> setThemeId(String id) async {
    state = state.copyWith(themeId: id, loaded: true);
    await DatabaseService.instance.setSetting(_themeKey, id);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
