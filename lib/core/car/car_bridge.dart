import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/calendar/presentation/calendar_providers.dart';
import '../../features/calendar/presentation/event_providers.dart';
import '../../features/map/domain/map_models.dart';
import '../../features/map/presentation/map_providers.dart';
import '../../features/media/presentation/youtube_session.dart';
import '../../features/payment/domain/viet_qr.dart';
import '../../features/payment/presentation/payment_preview.dart';
import '../../features/payment/presentation/payment_providers.dart';
import 'car_snapshot.dart';
import '../../features/settings/presentation/layout_settings.dart';

class CarBridge {
  CarBridge(this.container, {MethodChannel? channel})
    : channel = channel ?? const MethodChannel('vn.thanhtaxixanh/car');
  final ProviderContainer container;
  final MethodChannel channel;
  final _listeners = <ProviderSubscription<dynamic>>[];
  bool _connected = false, _publishing = false, _pending = false;
  String? _qrPayload;
  List<String>? _qrMatrix;

  Future<void> start() async {
    channel.setMethodCallHandler((call) async {
      if (call.method != 'carAction' || call.arguments is! Map) return null;
      return action(Map<String, dynamic>.from(call.arguments as Map));
    });
    try {
      await channel.invokeMethod<void>('ready');
    } on MissingPluginException {
      /* Native car service attaches on connection. */
    }
  }

  Future<Map<String, Object?>> action(Map<String, dynamic> command) async {
    final type = command['type'];
    if (type == 'connect') _connect();
    if (type == 'disconnect') {
      await container.read(youTubeSessionProvider.notifier).showOnCar(false);
      _connected = false;
      for (final listener in _listeners) {
        listener.close();
      }
      _listeners.clear();
      if (container.read(mapSessionProvider).carNavigationActive) {
        container.read(mapSessionProvider.notifier).pauseGps();
      }
      return {};
    }
    final maps = container.read(mapSessionProvider.notifier);
    final media = container.read(youTubeSessionProvider.notifier);
    if (type == 'gps') {
      final current = container.read(mapSessionProvider);
      if (current.gpsActive && current.carNavigationActive) {
        maps.pauseGps();
      } else {
        await maps.enableGps(backgroundNavigation: true);
      }
    } else if (type == '3d') {
      maps.toggle3D();
    } else if (type == 'route') {
      await maps.fetchRoute();
    } else if (type == 'clearRoute') {
      maps.clearDestination();
    } else if (type == 'destination') {
      final lat = command['latitude'], lon = command['longitude'];
      if (lat is num && lon is num) {
        final point = GeoPoint(lat.toDouble(), lon.toDouble());
        if (point.isValid) {
          maps.selectDestination(MapPlace('Điểm trên bản đồ', point));
        }
      }
    } else if (type == 'playPause') {
      if (container.read(youTubeSessionProvider).media?.playing == true) {
        await media.pause();
      } else {
        await media.play();
      }
    } else if (type == 'playVideo' && command['id'] is String) {
      await media.playId(command['id'] as String);
    } else if (type == 'next') {
      await media.skip(1);
    } else if (type == 'previous') {
      await media.skip(-1);
    } else if (type == 'stop') {
      await media.stop();
    } else if (type == 'openYouTube') {
      await media.showOnCar(true);
    } else if (type == 'closeYouTube') {
      await media.showOnCar(false);
    } else if (type == 'toggleCarPip') {
      await media.toggleCarPip();
    } else if (type == 'videoAttached' && command['id'] is int) {
      media.confirmCarVideo(command['id'] as int);
    } else if (type == 'videoAttachFailed') {
      await media.showOnCar(false);
      media.showError(
        'Bộ nhận chưa hiển thị được trình phát. Video đã chuyển về điện thoại.',
      );
    } else if (type == 'layoutPreset') {
      final preset = switch (command['preset']) {
        'balanced' => DashboardLayout.balanced,
        'events' => DashboardLayout.events,
        'qr' => DashboardLayout.qr,
        _ => null,
      };
      if (preset != null) {
        await container.read(layoutSettingsProvider.notifier).save(preset);
      }
    }
    final snapshot = buildSnapshot();
    if (_connected) unawaited(publish());
    return snapshot;
  }

  void _connect() {
    if (_connected) return;
    _connected = true;
    void changed(Object? _, Object? _) {
      unawaited(publish());
    }

    _listeners.addAll([
      container.listen(mapSessionProvider, changed),
      container.listen(eventOccurrencesProvider, changed),
      container.listen(recipientsProvider, changed),
      container.listen(youTubeSessionProvider, changed),
      container.listen(calendarClockProvider, changed),
      container.listen(paymentPreviewProvider, changed),
      container.listen(layoutSettingsProvider, changed),
    ]);
  }

  Map<String, Object?> buildSnapshot() {
    final calendar = container.read(lunarCalendarProvider);
    final today = container.read(vietnamTodayProvider);
    final lunar = calendar.forInstant(
      container.read(calendarClockProvider).value ?? DateTime.now().toUtc(),
    );
    final events = container.read(eventOccurrencesProvider).asData?.value ?? [];
    final accounts = container.read(recipientsProvider).asData?.value ?? [];
    final preview = container.read(paymentPreviewProvider);
    final savedPreview = accounts
        .where((a) => a.id == preview.account?.id)
        .firstOrNull;
    final stalePreview =
        preview.account != null &&
        (savedPreview == null ||
            savedPreview.bankBin != preview.account!.bankBin ||
            savedPreview.accountNumber != preview.account!.accountNumber ||
            savedPreview.accountHolder != preview.account!.accountHolder);
    final account = preview.account == null
        ? accounts.firstOrNull
        : savedPreview;
    final VietQr? qr = preview.editing || stalePreview
        ? null
        : savedPreview != null
        ? preview.payment ?? account?.payment()
        : account?.payment();
    final payload = qr?.payload;
    if (payload != _qrPayload) {
      _qrPayload = payload;
      _qrMatrix = payload == null ? null : carQrMatrix(payload);
    }
    final map = container.read(mapSessionProvider);
    final fix = map.fix;
    final route = map.route;
    final media = container.read(youTubeSessionProvider);
    final active = media.media;
    return {
      'layout':
          (container.read(layoutSettingsProvider).asData?.value ??
                  DashboardLayout.qr)
              .toJson(),
      'calendarTitle': '${today.day}/${today.month}/${today.year}',
      'lunarLabel':
          '${lunar.day}/${lunar.month} Âm lịch • ${calendar.canChi(lunar.year)}',
      'events': [
        for (final event in events.take(2))
          {
            'title': event.title(calendar),
            'detail':
                '${event.countdown(today)} • ${event.solarLabel} • ${event.lunarLabel(calendar)}',
          },
      ],
      'payment': {
        'holder': account?.accountHolder ?? '',
        'account': account?.accountNumber ?? '',
        'bank': account?.bankName ?? '',
        'amount': qr?.amount ?? '',
        'note': qr?.note ?? '',
        'matrix': _qrMatrix,
        'message': preview.editing
            ? 'QR đang chờ cập nhật trên điện thoại…'
            : stalePreview
            ? 'Thông tin tài khoản đã thay đổi. Cập nhật QR trên điện thoại.'
            : account == null
            ? 'Thêm tài khoản nhận tiền trên điện thoại.'
            : '',
      },
      'media': {
        'carVideo': media.carVideo,
        'carPip': media.carPip,
        'viewId': media.carViewId,
        'title': active?.title ?? 'YouTube',
        'artist':
            active?.artist ?? 'Chọn video trên điện thoại hoặc Video gần đây',
        'playing': active?.playing ?? false,
        'message': media.message,
        'recent': [
          for (final video in media.recent.take(10))
            {'id': video.id, 'title': video.title, 'artist': video.artist},
        ],
      },
      'map': {
        'gpsActive': map.gpsActive,
        'is3D': map.is3D,
        'latitude': fix?.point.latitude,
        'longitude': fix?.point.longitude,
        'speed': fix?.speedKmh,
        'heading': fix?.heading,
        'message': map.message,
        'trafficMessage': map.trafficMessage,
        'destination': map.destination?.name,
        'destinationPoint': map.destination?.point.coordinates,
        'route': route?.points.map((p) => p.coordinates).toList() ?? [],
        'routeLabel': route == null
            ? ''
            : '${formatDistance(route.distanceMeters)} • ${(route.durationSeconds / 60).ceil()} phút',
      },
    };
  }

  Future<void> publish() async {
    if (!_connected) return;
    if (_publishing) {
      _pending = true;
      return;
    }
    _publishing = true;
    try {
      do {
        _pending = false;
        await channel.invokeMethod<void>('snapshot', buildSnapshot());
      } while (_pending && _connected);
    } on PlatformException {
      // Reconnect sends a fresh snapshot after the car host is available.
    } on MissingPluginException {
      // Phone-only launch has no connected car template surface.
    } finally {
      _publishing = false;
    }
  }

  void dispose() {
    _connected = false;
    for (final listener in _listeners) {
      listener.close();
    }
    _listeners.clear();
    channel.setMethodCallHandler(null);
  }
}
