import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/office_location.dart';
import '../services/database_service.dart';

class OfficeState {
  final List<OfficeLocation> offices;
  final OfficeLocation? selectedOffice;
  final bool loading;

  const OfficeState({
    this.offices = const [],
    this.selectedOffice,
    this.loading = false,
  });

  bool get hasOffice => offices.isNotEmpty;
}

class OfficeNotifier extends StateNotifier<OfficeState> {
  OfficeNotifier() : super(const OfficeState());

  Future<void> load() async {
    state = OfficeState(offices: state.offices, selectedOffice: state.selectedOffice, loading: true);
    final offices = await DatabaseService.instance.getOfficeLocations();
    final currentId = state.selectedOffice?.id;
    final selected = offices.isEmpty
        ? null
        : offices.firstWhere((o) => o.id == currentId, orElse: () => offices.first);
    state = OfficeState(offices: offices, selectedOffice: selected);
  }

  void selectOffice(OfficeLocation office) {
    state = OfficeState(offices: state.offices, selectedOffice: office);
  }

  Future<void> addOffice(OfficeLocation office) async {
    final id = await DatabaseService.instance.insertOfficeLocation(office);
    final saved = office.copyWith(id: id);
    final offices = [...state.offices, saved];
    state = OfficeState(
      offices: offices,
      selectedOffice: state.selectedOffice ?? saved,
    );
  }

  Future<void> updateOffice(OfficeLocation office) async {
    await DatabaseService.instance.updateOfficeLocation(office);
    final offices = [for (final o in state.offices) o.id == office.id ? office : o];
    final selected = state.selectedOffice?.id == office.id ? office : state.selectedOffice;
    state = OfficeState(offices: offices, selectedOffice: selected);
  }

  Future<void> deleteOffice(int id) async {
    await DatabaseService.instance.deleteOfficeLocation(id);
    final offices = state.offices.where((o) => o.id != id).toList();
    final selected = state.selectedOffice?.id == id
        ? (offices.isNotEmpty ? offices.first : null)
        : state.selectedOffice;
    state = OfficeState(offices: offices, selectedOffice: selected);
  }
}

final officeProvider = StateNotifierProvider<OfficeNotifier, OfficeState>(
  (_) => OfficeNotifier(),
);
