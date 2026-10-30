import 'dart:convert';

import 'package:diacritic/diacritic.dart';

/// Account-transfer VietQR, ported from the supplied JavaScript shortcut.
class VietQr {
  factory VietQr({
    required String bankBin,
    required String accountNumber,
    String bankName = '',
    String accountHolder = '',
    String amount = '',
    String note = '',
  }) {
    final account = accountNumber.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(bankBin)) {
      throw ArgumentError.value(bankBin, 'bankBin', 'Expected six digits.');
    }
    if (!RegExp(r'^[A-Za-z0-9]{1,19}$').hasMatch(account)) {
      throw ArgumentError('Account must have 1–19 ASCII letters or digits.');
    }
    // VND has no fractional part. These separators are thousands separators.
    // Unlike the shortcut, reject negatives/text instead of changing their value.
    final cleanAmount = amount.trim();
    if (cleanAmount.isNotEmpty &&
        !RegExp(
          r'^(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,3}(?:\.[0-9]{3})+|[0-9]{1,3}(?: [0-9]{3})+)$',
        ).hasMatch(cleanAmount)) {
      throw ArgumentError('Expected a non-negative whole VND amount.');
    }
    final digits = amount
        .replaceAll(RegExp(r'\D'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    if (digits.length > 13) throw ArgumentError('Amount exceeds 13 digits.');
    var cleanNote = _unaccent(
      note,
    ).replaceAll(RegExp(r'[^A-Za-z0-9 -]'), '').replaceAll(RegExp(' +'), ' ');
    if (cleanNote.length > 50) cleanNote = cleanNote.substring(0, 50);
    return VietQr._(
      bankBin,
      account,
      bankName,
      _unaccent(accountHolder).toUpperCase(),
      digits,
      cleanNote.trim(),
    );
  }

  const VietQr._(
    this.bankBin,
    this.accountNumber,
    this.bankName,
    this.accountHolder,
    this.amount,
    this.note,
  );

  final String bankBin;
  final String accountNumber;
  final String bankName;
  final String accountHolder;

  /// Empty means the payer enters the amount (also used for zero in the source).
  final String amount;
  final String note;

  static String _unaccent(String text) =>
      removeDiacritics(text).replaceAll(RegExp(r'[\u0300-\u036f]'), '');

  String get payload {
    final beneficiary = _tlv('00', bankBin) + _tlv('01', accountNumber);
    final provider =
        _tlv('00', 'A000000727') +
        _tlv('01', beneficiary) +
        _tlv('02', 'QRIBFTTA');
    final body = [
      _tlv('00', '01'),
      _tlv('01', amount.isEmpty ? '11' : '12'),
      _tlv('38', provider),
      _tlv('53', '704'),
      if (amount.isNotEmpty) _tlv('54', amount),
      _tlv('58', 'VN'),
      if (note.isNotEmpty) _tlv('62', _tlv('08', note)),
      '6304',
    ].join();
    return '$body${crc16(body)}';
  }

  static String _tlv(String tag, String value) {
    final length = utf8.encode(value).length;
    if (length > 99) throw ArgumentError('TLV value exceeds 99 bytes.');
    return '$tag${length.toString().padLeft(2, '0')}$value';
  }

  /// CRC-16/CCITT-FALSE: poly 0x1021, init 0xFFFF, no reflection or final XOR.
  static String crc16(String value) {
    var crc = 0xffff;
    for (final byte in utf8.encode(value)) {
      crc ^= byte << 8;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1;
        crc &= 0xffff;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
