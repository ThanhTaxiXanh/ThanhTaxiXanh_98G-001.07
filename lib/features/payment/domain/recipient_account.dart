import 'dart:typed_data';

import 'viet_qr.dart';

class RecipientAccount {
  const RecipientAccount({
    required this.id,
    required this.bankBin,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    this.defaultNote = '',
    this.isDefault = false,
    this.footerLogo,
    this.centerLogo,
  });

  final String id;
  final String bankBin;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final String defaultNote;
  final bool isDefault;
  final Uint8List? footerLogo;
  final Uint8List? centerLogo;

  String get label {
    final tail = accountNumber.length > 4
        ? '…${accountNumber.substring(accountNumber.length - 4)}'
        : accountNumber;
    return '${isDefault ? '★ ' : ''}$accountHolder · $bankName · $tail';
  }

  VietQr payment({String amount = '', String? note}) => VietQr(
    bankBin: bankBin,
    bankName: bankName,
    accountNumber: accountNumber,
    accountHolder: accountHolder,
    amount: amount,
    note: note ?? defaultNote,
  );
}

class DuplicateRecipientException implements Exception {}

abstract interface class RecipientRepository {
  Future<List<RecipientAccount>> list();
  Future<void> save(RecipientAccount account);
  Future<void> setDefault(String id);
  Future<void> delete(String id);
}
