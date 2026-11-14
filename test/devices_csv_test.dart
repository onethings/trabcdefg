import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the device-list CSV export/import contract in `devices_screen.dart`
/// after the csv 8 migration: export writes `Csv().encode`, import reads it back
/// with `Csv().decode` after stripping a BOM.
void main() {
  List<List<dynamic>> export(List<List<dynamic>> devices) => [
    ['ID', 'sharedName', 'deviceIdentifier'],
    ...devices,
  ];

  List<List<dynamic>> import(String raw) {
    var content = raw;
    if (content.startsWith('\uFEFF')) content = content.substring(1);
    return Csv().decode(content);
  }

  test('quoted device names survive the export and import round trip', () {
    final rows = export([
      [7, 'Truck, "7"', 'abc123'],
      [8, 'Van 8', 'def456'],
    ]);

    final decoded = import(Csv().encode(rows));

    expect(decoded.first.first.toString().trim().toLowerCase(), 'id');
    expect(decoded, hasLength(3));
    expect(decoded[1][1], 'Truck, "7"');
    expect(decoded[1][2], 'abc123');
    expect(decoded[2][1], 'Van 8');
  });

  test('a BOM written by Excel does not break the header check', () {
    final rows = export([
      [7, 'Truck 7', 'abc123'],
    ]);

    final decoded = import('\uFEFF${Csv().encode(rows)}');

    expect(decoded.first.first.toString().trim().toLowerCase(), 'id');
    expect(decoded[1][1], 'Truck 7');
  });
}
