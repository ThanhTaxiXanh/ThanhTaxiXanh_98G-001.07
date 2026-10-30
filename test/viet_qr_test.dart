import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_auto/features/payment/domain/viet_qr.dart';

Map<String, String> parseTlv(String payload) {
  final fields = <String, String>{};
  var offset = 0;
  while (offset < payload.length) {
    final tag = payload.substring(offset, offset + 2);
    final length = int.parse(payload.substring(offset + 2, offset + 4));
    final end = offset + 4 + length;
    expect(end, lessThanOrEqualTo(payload.length));
    expect(fields.containsKey(tag), isFalse);
    fields[tag] = payload.substring(offset + 4, end);
    offset = end;
  }
  return fields;
}

void main() {
  test('CRC matches the standard CCITT-FALSE check vector', () {
    expect(VietQr.crc16('123456789'), '29B1');
  });

  test('payload matches original JavaScript fixtures byte for byte', () {
    // Fixtures came from the inspected TLV/CRC section of the user's shortcut;
    // their CRCs were also checked with Python binascii.crc_hqx(init=0xffff).
    final fixtures =
        jsonDecode(File('test/fixtures/viet_qr_source.json').readAsStringSync())
            as List;
    for (final fixture in fixtures.cast<Map<String, dynamic>>()) {
      final qr = VietQr(
        bankBin: fixture['bankBin'] as String,
        accountNumber: fixture['accountNumber'] as String,
        amount: fixture['amount'] as String,
        note: fixture['note'] as String,
      );
      expect(qr.payload, fixture['payload']);
      final fields = parseTlv(qr.payload);
      expect(fields['00'], '01');
      expect(fields['01'], qr.amount.isEmpty ? '11' : '12');
      expect(fields['53'], '704');
      expect(fields['58'], 'VN');
      expect(fields['54'], qr.amount.isEmpty ? isNull : qr.amount);
      final provider = parseTlv(fields['38']!);
      expect(provider['00'], 'A000000727');
      expect(provider['02'], 'QRIBFTTA');
      expect(parseTlv(provider['01']!), {
        '00': qr.bankBin,
        '01': qr.accountNumber,
      });
      if (qr.note.isNotEmpty) expect(parseTlv(fields['62']!)['08'], qr.note);
    }
  });

  test('normalizes Vietnamese text and limits note to 50 ASCII bytes', () {
    final qr = VietQr(
      bankBin: '970422',
      accountNumber: '001234',
      accountHolder: 'Đỗ Đức',
      note: 'Tha\u0300nh toa\u0301n Đỗ Đức!',
    );
    expect(qr.accountHolder, 'DO DUC');
    expect(qr.note, 'Thanh toan Do Duc');
    final long = VietQr(
      bankBin: '970422',
      accountNumber: '001234',
      note: List.filled(100, 'ế').join(),
    );
    expect(long.note, List.filled(50, 'e').join());
    expect(parseTlv(long.payload)['62'], startsWith('0850'));
  });

  test('zero follows the shortcut open-amount behavior', () {
    final qr = VietQr(
      bankBin: '970422',
      accountNumber: '001234',
      amount: '000',
    );
    expect(qr.amount, isEmpty);
    final fields = parseTlv(qr.payload);
    expect(fields['01'], '11');
    expect(fields.containsKey('54'), isFalse);
  });

  test('rejects malformed bank/account and unsafe amounts', () {
    expect(
      () => VietQr(bankBin: '123', accountNumber: '001'),
      throwsArgumentError,
    );
    for (final account in ['', '123-456', List.filled(20, '1').join()]) {
      expect(
        () => VietQr(bankBin: '970422', accountNumber: account),
        throwsArgumentError,
      );
    }
    for (final amount in [
      '-100',
      '100 USD',
      'NaN',
      '10000000000000',
      '1.5',
      '1,23',
      ',',
    ]) {
      expect(
        () => VietQr(bankBin: '970422', accountNumber: '001', amount: amount),
        throwsArgumentError,
      );
    }
  });
}
