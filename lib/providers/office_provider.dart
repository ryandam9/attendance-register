import 'package:flutter/foundation.dart';

import '../models/office_location.dart';
import '../services/database_service.dart';

class OfficeProvider extends ChangeNotifier {
  List<OfficeLocation> _offices = [];
  OfficeLocation? _selected;
  bool _loading = false;

  List<OfficeLocation> get offices => List.unmodifiable(_offices);
  OfficeLocation? get selectedOffice => _selected;
  bool get loading => _loading;
  bool get hasOffice => _offices.isNotEmpty;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _offices = await DatabaseService.instance.getOfficeLocations();
    // Preserve selection across reloads; fall back to first office.
    _selected = _offices.isEmpty
        ? null
        : _offices.firstWhere(
            (o) => o.id == _selected?.id,
            orElse: () => _offices.first,
          );
    _loading = false;
    notifyListeners();
  }

  void selectOffice(OfficeLocation office) {
    _selected = office;
    notifyListeners();
  }

  Future<void> addOffice(OfficeLocation office) async {
    final id = await DatabaseService.instance.insertOfficeLocation(office);
    final saved = office.copyWith(id: id);
    _offices.add(saved);
    _selected ??= saved;
    notifyListeners();
  }

  Future<void> updateOffice(OfficeLocation office) async {
    await DatabaseService.instance.updateOfficeLocation(office);
    final idx = _offices.indexWhere((o) => o.id == office.id);
    if (idx >= 0) _offices[idx] = office;
    if (_selected?.id == office.id) _selected = office;
    notifyListeners();
  }

  Future<void> deleteOffice(int id) async {
    await DatabaseService.instance.deleteOfficeLocation(id);
    _offices.removeWhere((o) => o.id == id);
    if (_selected?.id == id) {
      _selected = _offices.isNotEmpty ? _offices.first : null;
    }
    notifyListeners();
  }
}
