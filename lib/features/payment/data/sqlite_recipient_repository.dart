import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../domain/recipient_account.dart';

class SqliteRecipientRepository implements RecipientRepository {
  SqliteRecipientRepository(this.db);
  final Database db;

  @override
  Future<List<RecipientAccount>> list() async =>
      (await db.query(
            'recipients',
            orderBy:
                'is_default DESC, account_holder COLLATE NOCASE, bank_name',
          ))
          .map(
            (r) => RecipientAccount(
              id: r['id'] as String,
              bankBin: r['bank_bin'] as String,
              bankName: r['bank_name'] as String,
              accountNumber: r['account_number'] as String,
              accountHolder: r['account_holder'] as String,
              defaultNote: r['default_note'] as String,
              isDefault: r['is_default'] == 1,
              footerLogo: r['footer_logo'] as Uint8List?,
              centerLogo: r['center_logo'] as Uint8List?,
            ),
          )
          .toList();

  @override
  Future<void> save(RecipientAccount account) async {
    final payment = account.payment();
    if (account.id.isEmpty ||
        account.accountHolder.trim().isEmpty ||
        account.bankName.trim().isEmpty ||
        account.accountHolder.length > 100 ||
        account.defaultNote.length > 200 ||
        (account.footerLogo?.length ?? 0) > 2 * 1024 * 1024 ||
        (account.centerLogo?.length ?? 0) > 2 * 1024 * 1024) {
      throw ArgumentError('Invalid recipient details.');
    }
    await db.transaction((txn) async {
      final duplicate = await txn.query(
        'recipients',
        where: 'bank_bin = ? AND account_number = ? AND id != ?',
        whereArgs: [account.bankBin, payment.accountNumber, account.id],
      );
      if (duplicate.isNotEmpty) throw DuplicateRecipientException();
      if (account.isDefault) await txn.update('recipients', {'is_default': 0});
      await txn.insert('recipients', {
        'id': account.id,
        'bank_bin': account.bankBin,
        'bank_name': account.bankName,
        'account_number': payment.accountNumber,
        'account_holder': account.accountHolder.trim(),
        'default_note': account.defaultNote.trim(),
        'is_default': account.isDefault ? 1 : 0,
        'footer_logo': account.footerLogo,
        'center_logo': account.centerLogo,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _ensureDefault(txn);
    });
  }

  Future<void> _ensureDefault(Transaction txn) async {
    final current = await txn.query(
      'recipients',
      where: 'is_default = 1',
      limit: 1,
    );
    if (current.isNotEmpty) return;
    final first = await txn.query('recipients', orderBy: 'rowid', limit: 1);
    if (first.isNotEmpty) {
      await txn.update(
        'recipients',
        {'is_default': 1},
        where: 'id = ?',
        whereArgs: [first.single['id']],
      );
    }
  }

  @override
  Future<void> setDefault(String id) => db.transaction((txn) async {
    final row = await txn.query('recipients', where: 'id = ?', whereArgs: [id]);
    if (row.isEmpty) throw ArgumentError('Recipient no longer exists.');
    await txn.update('recipients', {'is_default': 0});
    await txn.update(
      'recipients',
      {'is_default': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  @override
  Future<void> delete(String id) => db.transaction((txn) async {
    await txn.delete('recipients', where: 'id = ?', whereArgs: [id]);
    await _ensureDefault(txn);
  });
}
