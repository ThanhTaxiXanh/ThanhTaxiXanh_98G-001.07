import 'package:qr/qr.dart';

/// Binary modules only. Android paints a white four-module quiet zone around it.
List<String> carQrMatrix(String payload) {
  final image = QrImage(
    QrCode.fromData(data: payload, errorCorrectLevel: QrErrorCorrectLevel.M),
  );
  return [
    for (var row = 0; row < image.moduleCount; row++)
      [
        for (var col = 0; col < image.moduleCount; col++)
          image.isDark(row, col) ? '1' : '0',
      ].join(),
  ];
}
