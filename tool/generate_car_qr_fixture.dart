import 'dart:convert';
import 'dart:io';
import 'package:taxi_auto/core/car/car_snapshot.dart';
import 'package:taxi_auto/features/payment/domain/viet_qr.dart';

void main() {
  final payload = VietQr(
    bankBin: '970422',
    accountNumber: '000123456789',
    accountHolder: 'NGUYEN VAN A',
    amount: '25000',
    note: 'Taxi test',
  ).payload;
  final file = File('android/app/src/test/resources/generated_car_qr.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    jsonEncode({'payload': payload, 'matrix': carQrMatrix(payload)}),
  );
}
