import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_period.dart';
import '../services/database_service.dart';
import '../themes/bird_themes.dart';

/// Persisted app preferences.
class SettingsState {
  final FinancialYearStart financialYearStart;
  final String themeId;
  final String userName;
  final bool loaded;

  const SettingsState({
    this.financialYearStart = FinancialYearStart.january,
    this.themeId = 'default',
    this.userName = '',
    this.loaded = false,
  });

  SettingsState copyWith({
    FinancialYearStart? financialYearStart,
    String? themeId,
    String? userName,
    bool? loaded,
  }) =>
      SettingsState(
        financialYearStart: financialYearStart ?? this.financialYearStart,
        themeId: themeId ?? this.themeId,
        userName: userName ?? this.userName,
        loaded: loaded ?? this.loaded,
      );

  BirdTheme get theme => birdThemeById(themeId);
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _fyStartKey = 'financial_year_start';
  static const _themeKey = 'theme_id';
  static const _userNameKey = 'user_name';

  @override
  SettingsState build() {
    _load();
    return const SettingsState();
  }

  Future<void> _load() async {
    final fyStart = await DatabaseService.instance.getSetting(_fyStartKey);
    final themeId = await DatabaseService.instance.getSetting(_themeKey);
    final userName = await DatabaseService.instance.getSetting(_userNameKey);
    state = SettingsState(
      financialYearStart: FinancialYearStart.fromName(fyStart),
      themeId: themeId ?? 'default',
      userName: userName ?? '',
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

  Future<void> setUserName(String name) async {
    state = state.copyWith(userName: name, loaded: true);
    await DatabaseService.instance.setSetting(_userNameKey, name);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
