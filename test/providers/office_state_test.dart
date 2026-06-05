import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_register/models/office_location.dart';
import 'package:attendance_register/providers/office_provider.dart';

void main() {
  group('OfficeState', () {
    const hq = OfficeLocation(
      id: 1,
      name: 'HQ',
      address: '1 Main St',
      latitude: 37.77,
      longitude: -122.42,
    );

    const branch = OfficeLocation(
      id: 2,
      name: 'Branch',
      address: '2 Side St',
      latitude: 37.80,
      longitude: -122.45,
    );

    test('hasOffice is false when the offices list is empty', () {
      const state = OfficeState();
      expect(state.hasOffice, isFalse);
    });

    test('hasOffice is true when at least one office exists', () {
      const state = OfficeState(offices: [hq]);
      expect(state.hasOffice, isTrue);
    });

    test('hasOffice is true with multiple offices', () {
      const state = OfficeState(offices: [hq, branch]);
      expect(state.hasOffice, isTrue);
    });

    test('selectedOffice is null by default', () {
      const state = OfficeState();
      expect(state.selectedOffice, isNull);
    });

    test('selectedOffice holds the provided office', () {
      const state = OfficeState(offices: [hq], selectedOffice: hq);
      expect(state.selectedOffice?.id, 1);
      expect(state.selectedOffice?.name, 'HQ');
    });

    test('loading defaults to false', () {
      const state = OfficeState();
      expect(state.loading, isFalse);
    });

    test('loading can be set to true', () {
      const state = OfficeState(loading: true);
      expect(state.loading, isTrue);
    });

    test('offices list is accessible', () {
      const state = OfficeState(offices: [hq, branch]);
      expect(state.offices, hasLength(2));
      expect(state.offices.map((o) => o.name), containsAll(['HQ', 'Branch']));
    });
  });
}
