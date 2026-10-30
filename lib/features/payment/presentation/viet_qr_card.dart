import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../domain/viet_qr.dart';

/// Flutter rendering of the shortcut's account/QR/logo/amount card.
class VietQrCard extends StatelessWidget {
  const VietQrCard({
    required this.payment,
    this.bankLogo,
    this.centerLogo,
    super.key,
  });

  final VietQr payment;
  final ImageProvider? bankLogo;
  final ImageProvider? centerLogo;

  @override
  Widget build(BuildContext context) {
    final amount = payment.amount.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffe0edfb), Color(0xfff5f8ff)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  payment.accountNumber,
                  style: const TextStyle(fontSize: 22, letterSpacing: 2),
                ),
                if (payment.accountHolder.isNotEmpty)
                  Text(
                    payment.accountHolder,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const Divider(height: 32),
                AspectRatio(
                  aspectRatio: 1,
                  child: PrettyQrView.data(
                    data: payment.payload,
                    errorCorrectLevel: centerLogo == null
                        ? QrErrorCorrectLevel.M
                        : QrErrorCorrectLevel.H,
                    decoration: PrettyQrDecoration(
                      background: Colors.white,
                      shape: const PrettyQrSquaresSymbol(),
                      quietZone: const PrettyQrQuietZone.modules(4),
                      image: centerLogo == null
                          ? null
                          : PrettyQrDecorationImage(
                              image: centerLogo!,
                              scale: 0.12,
                            ),
                    ),
                  ),
                ),
                if (bankLogo != null)
                  SizedBox(height: 60, child: Image(image: bankLogo!))
                else
                  Text(
                    payment.bankName.isEmpty
                        ? payment.bankBin
                        : payment.bankName,
                    style: const TextStyle(
                      color: Color(0xff005ca8),
                      fontSize: 20,
                    ),
                  ),
              ],
            ),
          ),
          if (amount.isNotEmpty || payment.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  if (amount.isNotEmpty)
                    Text(
                      '$amount VND',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (payment.note.isNotEmpty)
                    Text(payment.note, textAlign: TextAlign.center),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Capture a painted RepaintBoundary around the card, replacing canvas.toDataURL.
/// Call after the frame and any logo image decoding have completed.
Future<Uint8List> captureVietQrPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 2,
}) async {
  final renderObject = boundaryKey.currentContext?.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) {
    throw StateError('The QR card must be mounted inside a RepaintBoundary.');
  }
  final image = await renderObject.toImage(pixelRatio: pixelRatio);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('PNG encoding failed.');
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    image.dispose();
  }
}
