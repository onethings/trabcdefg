import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel_plus/excel_plus.dart' as excel_lib;
import 'package:flutter_test/flutter_test.dart';

/// Guards the device-list Excel export: `excel_plus` writes the workbook through
/// archive 4, so a dependency bump that corrupts the zip has to fail here.
void main() {
  List<int> encodeWorkbook(List<List<String>> rows) {
    final workbook = excel_lib.Excel.createExcel();
    final sheet = workbook[workbook.getDefaultSheet()!];
    for (final row in rows) {
      sheet.appendRow(row.map(excel_lib.TextCellValue.new).toList());
    }
    final bytes = workbook.encode();
    expect(bytes, isNotNull, reason: 'encode() returned null');
    return bytes!;
  }

  test('device export encodes a zip an independent reader can open', () {
    final bytes = encodeWorkbook([
      ['ID', 'sharedName', 'deviceIdentifier'],
      ['7', 'Truck 7', 'abc123'],
    ]);

    expect(bytes.take(4).toList(), [0x50, 0x4b, 0x03, 0x04], reason: 'xlsx starts as a zip');

    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final names = archive.files.map((file) => file.name).toSet();
    expect(
      names,
      containsAll([
        '[Content_Types].xml',
        'xl/workbook.xml',
        'xl/worksheets/sheet1.xml',
      ]),
    );

    final text = archive.files
        .where((file) => file.isFile)
        .map((file) => utf8.decode(file.content, allowMalformed: true))
        .join();
    expect(text, contains('Truck 7'));
    expect(text, contains('abc123'));
  });
}
