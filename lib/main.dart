import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';

import 'app/app.dart';
import 'features/media/presentation/youtube_audio_handler.dart';
import 'features/media/presentation/youtube_session.dart';
import 'core/car/car_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  final session = container.read(youTubeSessionProvider.notifier);
  try {
    final handler = await AudioService.init<TaxiAudioHandler>(
      builder: () => TaxiAudioHandler(session),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'vn.thanhtaxixanh.media',
        androidNotificationChannelName: 'Phát âm thanh',
        androidStopForegroundOnPause: false,
      ),
    );
    session.attachHandler(handler);
    await handler.initializeFocus();
  } catch (_) {
    session.showError(
      'Chưa khởi tạo được dịch vụ phát nền. Bạn vẫn có thể mở YouTube.',
    );
  }
  await CarBridge(container).start();
  runApp(
    UncontrolledProviderScope(container: container, child: const TaxiAutoApp()),
  );
}
