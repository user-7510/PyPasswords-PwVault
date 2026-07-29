import 'dart:io';

import 'package:csv/csv.dart';

import '../models/record.dart';

class CsvImportResult {
  final List<PasswordRecord> records;
  final int importedCount;
  CsvImportResult({required this.records, required this.importedCount});
}

class CsvService {
  static List<String> _splitNotes(String value) {
    if (value.trim().isEmpty) return [];
    return value
        .split(RegExp('[;；]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static Future<CsvImportResult> importFromFile(File file) async {
    final content = await file.readAsString(encoding: SystemEncoding());
    final rows = const CsvToListConverter(eol: '\n').convert(content, shouldParseNumbers: false);
    if (rows.isEmpty) {
      return CsvImportResult(records: [], importedCount: 0);
    }
    final header = rows.first.map((e) => e.toString().trim()).toList();
    final noteColumnIndexes = <int>[];
    for (var i = 0; i < header.length; i++) {
      if (header[i].contains('備註')) noteColumnIndexes.add(i);
    }
    String cell(List<dynamic> row, String columnName) {
      final idx = header.indexOf(columnName);
      if (idx < 0 || idx >= row.length) return '';
      return row[idx].toString().trim();
    }

    final records = <PasswordRecord>[];
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((c) => c.toString().trim().isEmpty)) continue;
      final notes = <String>[];
      for (final idx in noteColumnIndexes) {
        if (idx < row.length) {
          notes.addAll(_splitNotes(row[idx].toString()));
        }
      }
      records.add(PasswordRecord(
        id: PasswordRecord.generateId(),
        accountType: cell(row, '帳戶類型'),
        accountName: cell(row, '帳號名稱'),
        password: cell(row, '密碼'),
        linkedAccount: cell(row, '連結帳戶'),
        name: cell(row, '姓名'),
        notes: notes,
      ));
    }
    return CsvImportResult(records: records, importedCount: records.length);
  }
}
