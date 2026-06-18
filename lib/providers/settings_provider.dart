import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_period.dart';
import '../services/database_service.dart';
import '../themes/bird_themes.dart';

/// Persisted app preferences.
class SettingsState {
  /// Default return-to-office target — the share of eligible weekdays the
  /// employer expects in the office. Stat cards turn green at or above it.
  static const defaultRtoTarget = 50;

  final FinancialYearStart financialYearStart;
  final String themeId;
  final ThemeMode themeMode;
  final String userName;
  final int rtoTarget;
  final bool loaded;

  const SettingsState({
    this.financialYearStart = FinancialYearStart.january,
    this.themeId = 'bee_eater',
    this.themeMode = ThemeMode.system,
    this.userName = '',
    this.rtoTarget = defaultRtoTarget,
    this.loaded = false,
  });

  SettingsState copyWith({
    FinancialYearStart? financialYearStart,
    String? themeId,
    ThemeMode? themeMode,
    String? userName,
    int? rtoTarget,
    bool? loaded,
  }) =>
      SettingsState(
        financialYearStart: financialYearStart ?? this.financialYearStart,
        themeId: themeId ?? this.themeId,
        themeMode: themeMode ?? this.themeMode,
        userName: userName ?? this.userName,
        rtoTarget: rtoTarget ?? this.rtoTarget,
        loaded: loaded ?? this.loaded,
      );

  BirdTheme get theme => birdThemeById(themeId);
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _fyStartKey = 'financial_year_start';
  static const _themeKey = 'theme_id';
  static const _themeModeKey = 'theme_mode';
  static const _userNameKey = 'user_name';
  static const _rtoTargetKey = 'rto_target_percent';

  static ThemeMode _themeModeFromName(String? name) => ThemeMode.values
      .firstWhere((m) => m.name == name, orElse: () => ThemeMode.system);

  @override
  SettingsState build() {
    _load();
    return const SettingsState();
  }

  Future<void> _load() async {
    final fyStart = await DatabaseService.instance.getSetting(_fyStartKey);
    final themeId = await DatabaseService.instance.getSetting(_themeKey);
    final themeMode = await DatabaseService.instance.getSetting(_themeModeKey);
    final userName = await DatabaseService.instance.getSetting(_userNameKey);
    final rtoTarget = await DatabaseService.instance.getSetting(_rtoTargetKey);
    state = SettingsState(
      financialYearStart: FinancialYearStart.fromName(fyStart),
      themeId: themeId ?? 'bee_eater',
      themeMode: _themeModeFromName(themeMode),
      userName: userName ?? '',
      rtoTarget: int.tryParse(rtoTarget ?? '') ?? SettingsState.defaultRtoTarget,
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

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode, loaded: true);
    await DatabaseService.instance.setSetting(_themeModeKey, mode.name);
  }

  Future<void> setUserName(String name) async {
    state = state.copyWith(userName: name, loaded: true);
    await DatabaseService.instance.setSetting(_userNameKey, name);
  }

  Future<void> setRtoTarget(int percent) async {
    state = state.copyWith(rtoTarget: percent, loaded: true);
    await DatabaseService.instance.setSetting(_rtoTargetKey, '$percent');
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
