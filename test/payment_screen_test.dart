import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_auto/features/payment/domain/viet_qr.dart';
import 'package:taxi_auto/features/payment/domain/recipient_account.dart';

import 'support/test_app.dart';
import 'package:taxi_auto/features/payment/presentation/payment_screen.dart';
import 'package:taxi_auto/features/payment/presentation/viet_qr_card.dart';

void main() {
  testWidgets(
    'saved recipient needs only amount and note, with clear amount support',
    (tester) async {
      final recipients = MemoryRecipients([
        const RecipientAccount(
          id: 'saved',
          bankBin: '970422',
          bankName: 'MBBank',
          accountNumber: '0012345678',
          accountHolder: 'LE THANH',
          defaultNote: 'Thanh Taxi Xanh',
          isDefault: true,
        ),
      ]);
      await tester.pumpWidget(
        testApp(home: const PaymentScreen(), recipients: recipients),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VietQrCard), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      final amount = find.byKey(const Key('payment-amount'));
      final update = find.byKey(const Key('update-payment'));
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '-25000');
      await tester.pump();
      expect(find.byType(VietQrCard), findsNothing);
      await tester.ensureVisible(update);
      await tester.tap(update);
      await tester.pumpAndSettle();
      expect(find.textContaining('Nhập số tiền VND nguyên'), findsOneWidget);
      await tester.enterText(amount, '25000');
      await tester.enterText(
        find.byKey(const Key('payment-note')),
        'Chuyen tien',
      );
      await tester.ensureVisible(update);
      await tester.tap(update);
      await tester.pumpAndSettle();
      expect(find.byType(VietQrCard), findsOneWidget);
      expect(find.text('25,000 VND'), findsOneWidget);
      final clear = find.byKey(const Key('clear-amount'));
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(
        tester.widget<VietQrCard>(find.byType(VietQrCard)).payment.amount,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bank picker saves a recipient without entering a BIN', (
    tester,
  ) async {
    final recipients = MemoryRecipients();
    await tester.pumpWidget(
      testApp(home: const PaymentScreen(), recipients: recipients),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-recipient')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bank-picker')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'MB Bank');
    await tester.pumpAndSettle();
    await tester.tap(find.text('MBBank'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('recipient-number')),
      '0012345678',
    );
    await tester.enterText(
      find.byKey(const Key('recipient-holder')),
      'LE THANH',
    );
    final save = find.byKey(const Key('save-recipient'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(recipients.records.values.single.bankBin, '970422');
    expect(find.byType(VietQrCard), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the shortcut-style card can be exported to a PNG', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 450,
              child: RepaintBoundary(
                key: key,
                child: VietQrCard(
                  payment: VietQr(
                    bankBin: '970422',
                    accountNumber: '0123456789',
                    accountHolder: 'NGUYEN VAN A',
                    bankName: 'Ngan hang thu nghiem',
                    amount: '10000',
                    note: 'Test QR',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final bytes = await tester.runAsync(() => captureVietQrPng(key));
    expect(bytes, isNotNull);
    expect(bytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final preview = Platform.environment['QR_PREVIEW_OUTPUT'];
    if (preview != null) File(preview).writeAsBytesSync(bytes);
    expect(tester.takeException(), isNull);
  });
}
