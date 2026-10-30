import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_auto/features/payment/domain/viet_qr.dart';
import 'package:taxi_auto/features/payment/presentation/payment_screen.dart';
import 'package:taxi_auto/features/payment/presentation/viet_qr_card.dart';

void main() {
  testWidgets(
    'payment form rejects incomplete input and generates a valid QR',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PaymentScreen()));
      final button = find.widgetWithText(FilledButton, 'Tạo mã QR');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(VietQrCard), findsNothing);
      expect(find.textContaining('Kiểm tra BIN'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '970422');
      await tester.enterText(fields.at(2), '0123456789');
      await tester.enterText(fields.at(4), '25000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(VietQrCard), findsOneWidget);
      expect(find.text('25,000 VND'), findsOneWidget);
      expect(find.textContaining('Kiểm tra BIN'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
