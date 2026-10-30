import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../domain/bank.dart';

class SqliteBankRepository implements BankRepository {
  SqliteBankRepository(this.db, this.client, this.loadSeed);

  static final endpoint = Uri.https('api.vietqr.io', '/v2/banks');
  final Database db;
  final http.Client client;
  final Future<String> Function() loadSeed;

  @override
  Future<BankCatalog> load() async {
    final rows = await db.query('banks', orderBy: 'short_name COLLATE NOCASE');
    if (rows.isEmpty) {
      final seed = jsonDecode(await loadSeed()) as Map<String, dynamic>;
      final banks = _parseBanks(seed['banks']);
      final updated = DateTime.parse(seed['fetchedAt'] as String);
      await _store(banks, updated);
      return BankCatalog(banks, updated);
    }
    final metadata = await db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['banks_updated_at'],
    );
    return BankCatalog(
      rows
          .map(
            (r) => Bank(
              bin: r['bin'] as String,
              name: r['name'] as String,
              shortName: r['short_name'] as String,
              code: r['code'] as String,
            ),
          )
          .toList(),
      DateTime.parse(metadata.single['value'] as String),
    );
  }

  @override
  Future<BankCatalog> refresh() async {
    final response = await client
        .get(endpoint)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw const FormatException('Bank API failed.');
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (json['code'] != '00') {
      throw const FormatException('Bank API rejected request.');
    }
    // Validate the complete response before replacing the working offline cache.
    final banks = _parseBanks(json['data']);
    final updated = DateTime.now().toUtc();
    await _store(banks, updated);
    return BankCatalog(banks, updated);
  }

  List<Bank> _parseBanks(Object? raw) {
    if (raw is! List || raw.isEmpty) {
      throw const FormatException('Empty bank list.');
    }
    final bins = <String>{};
    final banks = raw.map((value) {
      if (value is! Map) throw const FormatException('Invalid bank.');
      final bin = value['bin'];
      final name = value['name'];
      final shortName = value['shortName'];
      final code = value['code'];
      if (bin is! String ||
          !RegExp(r'^\d{6}$').hasMatch(bin) ||
          !bins.add(bin) ||
          name is! String ||
          name.trim().isEmpty ||
          shortName is! String ||
          shortName.trim().isEmpty ||
          code is! String ||
          code.trim().isEmpty) {
        throw const FormatException('Invalid bank record.');
      }
      return Bank(bin: bin, name: name, shortName: shortName, code: code);
    }).toList();
    banks.sort(
      (a, b) => a.shortName.toLowerCase().compareTo(b.shortName.toLowerCase()),
    );
    return banks;
  }

  Future<void> _store(List<Bank> banks, DateTime updated) =>
      db.transaction((txn) async {
        await txn.delete('banks');
        final batch = txn.batch();
        for (final bank in banks) {
          batch.insert('banks', {
            'bin': bank.bin,
            'name': bank.name,
            'short_name': bank.shortName,
            'code': bank.code,
          });
        }
        batch.insert('metadata', {
          'key': 'banks_updated_at',
          'value': updated.toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await batch.commit(noResult: true);
      });
}
