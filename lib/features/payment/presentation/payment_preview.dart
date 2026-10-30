import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/recipient_account.dart';
import '../domain/viet_qr.dart';

class PaymentPreview {
  const PaymentPreview({this.account, this.payment, this.editing = false});
  final RecipientAccount? account;
  final VietQr? payment;
  final bool editing;
}

final paymentPreviewProvider =
    NotifierProvider<PaymentPreviewController, PaymentPreview>(
      PaymentPreviewController.new,
    );

class PaymentPreviewController extends Notifier<PaymentPreview> {
  @override
  PaymentPreview build() => const PaymentPreview();
  void update(PaymentPreview preview) => state = preview;
}
