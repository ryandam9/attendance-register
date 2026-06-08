import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_period.dart';
import '../services/database_service.dart';

/// Persisted app preferences. Currently just the financial-year start used by
/// the Explain report, stored in the `app_settings` key/value table so it
/// survives restarts.
class SettingsState {
  final FinancialYearStart financialYearStart;
  final bool loaded;

  const SettingsState({
    this.financialYearStart = FinancialYearStart.january,
    this.loaded = false,
  });

  SettingsState copyWith({FinancialYearStart? financialYearStart, bool? loaded}) =>
      SettingsState(
        financialYearStart: financialYearStart ?? this.financialYearStart,
        loaded: loaded ?? this.loaded,
      );
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _fyStartKey = 'financial_year_start';

  @override
  SettingsState build() {
    // Kick off the async load; until it returns we serve the default.
    _load();
    return const SettingsState();
  }

  Future<void> _load() async {
    final stored = await DatabaseService.instance.getSetting(_fyStartKey);
    state = SettingsState(
      financialYearStart: FinancialYearStart.fromName(stored),
      loaded: true,
    );
  }

  Future<void> setFinancialYearStart(FinancialYearStart value) async {
    state = state.copyWith(financialYearStart: value, loaded: true);
    await DatabaseService.instance.setSetting(_fyStartKey, value.name);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
