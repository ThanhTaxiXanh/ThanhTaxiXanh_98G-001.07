import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/android_pip_controller.dart';
import '../data/youtube_history_repository.dart';
import '../domain/youtube_media.dart';
import 'youtube_browser.dart';
import 'youtube_providers.dart';
import 'youtube_audio_handler.dart';

final pipControllerProvider = Provider<PipController>((ref) {
  final controller = AndroidPipController();
  ref.onDispose(controller.dispose);
  return controller;
});
final youTubeHistoryRepositoryProvider = Provider<YouTubeHistoryRepository>(
  (ref) => PreferencesYouTubeHistory(),
);
final youTubeSessionProvider =
    NotifierProvider<YouTubeSession, YouTubeSessionState>(YouTubeSession.new);

class YouTubeSessionState {
  const YouTubeSessionState({
    this.initialized = false,
    this.canGoBack = false,
    this.inPip = false,
    this.serviceReady = false,
    this.progress = 0,
    this.media,
    this.fullscreen,
    this.message,
    this.recent = const [],
    this.carVideo = false,
    this.carPip = false,
    this.carViewId,
  });
  final bool initialized, canGoBack, inPip, serviceReady;
  final int progress;
  final YouTubeMedia? media;
  final Widget? fullscreen;
  final String? message;
  final List<YouTubeMedia> recent;
  final bool carVideo;
  final bool carPip;
  final int? carViewId;
  YouTubeSessionState copy({
    bool? initialized,
    bool? canGoBack,
    bool? inPip,
    bool? serviceReady,
    int? progress,
    YouTubeMedia? media,
    Widget? fullscreen,
    String? message,
    List<YouTubeMedia>? recent,
    bool clearFullscreen = false,
    bool clearMessage = false,
    bool? carVideo,
    bool? carPip,
    int? carViewId,
    bool clearCarView = false,
  }) => YouTubeSessionState(
    initialized: initialized ?? this.initialized,
    canGoBack: canGoBack ?? this.canGoBack,
    inPip: inPip ?? this.inPip,
    serviceReady: serviceReady ?? this.serviceReady,
    progress: progress ?? this.progress,
    media: media ?? this.media,
    fullscreen: clearFullscreen ? null : fullscreen ?? this.fullscreen,
    message: clearMessage ? null : message ?? this.message,
    recent: recent ?? this.recent,
    carVideo: carVideo ?? this.carVideo,
    carPip: carPip ?? this.carPip,
    carViewId: clearCarView ? null : carViewId ?? this.carViewId,
  );
}

/// Owns the native browser for the process, rather than a phone-only route.
class YouTubeSession extends Notifier<YouTubeSessionState>
    with WidgetsBindingObserver {
  YouTubeBrowser? _browser;
  TaxiAudioHandler? _handler;
  Future<void>? _initializing;
  Future<void> _historyWrites = Future.value();
  StreamSubscription<bool>? _pipSubscription;
  Timer? _remember;
  Timer? _carAttachTimeout;
  int _carRequest = 0;
  int _playRequest = 0;
  bool _visible = false, _pendingPlay = false;
  int _historyGeneration = 0;
  String? _lastRememberedVideo;
  final _playQueue = <String>[];

  YouTubeBrowser? get browser => _browser;
  @override
  YouTubeSessionState build() {
    WidgetsBinding.instance.addObserver(this);
    _pipSubscription = ref.read(pipControllerProvider).changes.listen((active) {
      if (!ref.mounted) return;
      state = state.copy(inPip: active);
      unawaited(_browser?.setCompact(active).catchError((Object _) {}));
    });
    ref.listen(youTubeSettingsProvider, (_, next) {
      if (next.asData != null) {
        unawaited(applyFiltering());
        unawaited(_configurePip());
      }
    });
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _remember?.cancel();
      _carAttachTimeout?.cancel();
      unawaited(_pipSubscription?.cancel());
      _browser?.close();
      unawaited(_handler?.disposeResources());
    });
    unawaited(_loadHistory());
    return const YouTubeSessionState();
  }

  void attachHandler(TaxiAudioHandler handler) {
    _handler = handler;
    state = state.copy(serviceReady: true);
    handler.updateRecent(state.recent);
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ref.read(youTubeHistoryRepositoryProvider).load();
      if (!ref.mounted) return;
      // A cold car browser can request playback before persistence has loaded.
      final merged = [...state.recent];
      for (final media in history) {
        if (!merged.any((entry) => entry.id == media.id)) merged.add(media);
      }
      state = state.copy(recent: merged.take(20).toList());
      _handler?.updateRecent(state.recent);
    } catch (_) {
      // Playback remains available if only the optional recent-video cache fails.
    }
  }

  Future<void> ensureInitialized() {
    if (_initializing != null) return _initializing!;
    if (_browser != null && state.initialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    try {
      final settings = await ref.read(youTubeSettingsProvider.future);
      if (!ref.mounted) return;
      final browser = ref.read(youTubeBrowserFactoryProvider)(
        YouTubeBrowserCallbacks(
          onProgress: (progress) {
            if (ref.mounted) state = state.copy(progress: progress);
          },
          onLocation: _locationChanged,
          onReady: () {
            unawaited(refreshHistory());
            unawaited(applyFiltering());
            unawaited(
              _browser?.setCompact(state.inPip).catchError((Object _) {}),
            );
            if (_pendingPlay) {
              _pendingPlay = false;
              unawaited(play());
            }
          },
          onError: showError,
          onFullscreen: (view) {
            if (view != null && state.carVideo) {
              _browser?.exitFullscreen();
              unawaited(_browser?.setCompact(true));
              return;
            }
            if (ref.mounted) {
              state = state.copy(
                fullscreen: view,
                clearFullscreen: view == null,
              );
            }
          },
          onMedia: _receivedMedia,
        ),
      );
      _browser = browser;
      state = state.copy(initialized: true, clearMessage: true);
      await browser.initialize(settings.startLocation);
    } catch (_) {
      _browser?.close();
      _browser = null;
      if (ref.mounted) {
        state = state.copy(initialized: false);
        showError('Không mở được YouTube. Vui lòng thử lại.');
      }
    }
  }

  void showError(String message) {
    if (ref.mounted) state = state.copy(message: message, progress: 100);
  }

  void clearError() => state = state.copy(clearMessage: true);

  void _locationChanged(Uri uri) {
    if (!ref.mounted) return;
    unawaited(refreshHistory());
    _remember?.cancel();
    _remember = Timer(const Duration(milliseconds: 350), () async {
      if (!ref.mounted) return;
      try {
        await ref.read(youTubeSettingsProvider.notifier).remember(uri);
      } catch (_) {
        showError('Chưa lưu được trang gần nhất.');
      }
    });
  }

  Future<void> refreshHistory() async {
    final generation = ++_historyGeneration;
    try {
      final canBack = await _browser?.canGoBack() ?? false;
      if (ref.mounted && generation == _historyGeneration) {
        state = state.copy(canGoBack: canBack);
      }
    } catch (_) {}
  }

  Future<void> applyFiltering() async {
    final enabled =
        ref.read(youTubeSettingsProvider).asData?.value.filterAds ?? true;
    try {
      await _browser?.setFiltering(enabled);
      await _browser?.setBackgroundAudio(
        ref.read(youTubeSettingsProvider).asData?.value.backgroundAudio ?? true,
      );
    } catch (_) {
      showError('Chưa kích hoạt được bộ lọc. Thử tải lại hoặc tắt bộ lọc.');
    }
  }

  void _receivedMedia(YouTubeMedia media) {
    if (!ref.mounted) return;
    if (!_playQueue.contains(media.id)) {
      _playQueue
        ..clear()
        ..add(media.id)
        ..addAll(state.recent.where((v) => v.id != media.id).map((v) => v.id));
    }
    state = state.copy(media: media);
    _handler?.acceptMedia(media);
    unawaited(_configurePip());
    final key = '${media.id}/${media.title}';
    if (media.playing && _lastRememberedVideo != key) {
      _lastRememberedVideo = key;
      final recent = [
        media,
        ...state.recent.where((entry) => entry.id != media.id),
      ].take(20).toList();
      state = state.copy(recent: recent);
      _handler?.updateRecent(recent);
      final repository = ref.read(youTubeHistoryRepositoryProvider);
      _historyWrites = _historyWrites
          .then((_) => repository.save(recent))
          .catchError((Object _) {
            showError('Chưa lưu được video gần đây.');
          });
    }
  }

  Future<void> load(Uri uri, {bool playAfterLoad = false}) async {
    final request = ++_playRequest;
    clearError();
    await ensureInitialized();
    if (!ref.mounted || request != _playRequest) return;
    _pendingPlay = playAfterLoad;
    try {
      await _browser?.pause().catchError((Object _) {});
      if (!ref.mounted || request != _playRequest) return;
      await _browser?.load(uri);
    } catch (_) {
      showError('Chưa mở được trang YouTube.');
    }
  }

  Future<void> playId(String id) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) return;
    if (state.media?.id == id && _browser != null) return play();
    await load(
      Uri.https('m.youtube.com', '/watch', {'v': id}),
      playAfterLoad: true,
    );
  }

  Future<void> play() async {
    final request = ++_playRequest;
    await ensureInitialized();
    if (!ref.mounted || request != _playRequest) return;
    try {
      await _browser?.play();
    } catch (_) {
      showError('Trang YouTube chưa cho phát. Hãy mở video rồi thử lại.');
    }
  }

  Future<void> pause() async {
    final request = ++_playRequest;
    _pendingPlay = false;
    await _browser?.pause().catchError((Object _) {});
    if (!ref.mounted || request != _playRequest) return;
    if (ref.mounted && state.media != null) {
      state = state.copy(media: state.media!.paused());
    }
    _handler?.markPaused();
    unawaited(_configurePip(forcePaused: true));
  }

  Future<void> stop() async {
    final request = _playRequest + 1;
    await pause();
    if (request == _playRequest) _handler?.markStopped();
  }

  Future<void> seek(Duration position) async {
    await _browser?.seek(position).catchError((Object _) {});
  }

  Future<void> skip(int delta) async {
    final index = _playQueue.indexOf(state.media?.id ?? '');
    final target = index + delta;
    if (target >= 0 && target < _playQueue.length) {
      await playId(_playQueue[target]);
    }
  }

  Future<void> goBack() async {
    await _browser?.goBack();
    await refreshHistory();
  }

  Future<void> reload() async {
    clearError();
    if (_browser == null) {
      await ensureInitialized();
    } else {
      try {
        await _browser!.reload();
      } catch (_) {
        showError('Chưa tải lại được YouTube. Kiểm tra mạng rồi thử lại.');
      }
    }
  }

  void exitFullscreen() => _browser?.exitFullscreen();
  void setVisible(bool visible) {
    _visible = visible;
    unawaited(_configurePip());
  }

  Future<void> _configurePip({bool forcePaused = false}) async {
    if (!ref.mounted) return;
    final settings = ref.read(youTubeSettingsProvider).asData?.value;
    await ref
        .read(pipControllerProvider)
        .configure(
          playing: !forcePaused && state.media?.playing == true,
          visible: _visible && !state.carVideo,
          autoEnter: settings?.autoPip ?? true,
        );
  }

  Future<void> enterPip() async {
    if (state.carVideo) {
      showError('Chuyển video về điện thoại trước khi bật PiP.');
      return;
    }
    if (state.media == null) {
      showError('Hãy mở một video trước khi bật PiP.');
      return;
    }
    await _browser?.setCompact(true);
    final entered = await ref.read(pipControllerProvider).enter();
    if (!entered) {
      await _browser?.setCompact(false);
      showError(
        'PiP chưa khả dụng. Kiểm tra quyền Hình trong hình trong cài đặt Android.',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = ref.read(youTubeSettingsProvider).asData?.value;
    if (state == AppLifecycleState.paused &&
        settings?.backgroundAudio == false &&
        !this.state.carVideo &&
        !this.state.inPip) {
      unawaited(pause());
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(applyFiltering());
      unawaited(_configurePip());
    }
  }

  Future<void> showOnCar(bool enabled) async {
    final request = ++_carRequest;
    _carAttachTimeout?.cancel();
    if (!enabled) {
      try {
        await const MethodChannel(
          'vn.thanhtaxixanh/car',
        ).invokeMethod<void>('releaseCarVideo');
      } on MissingPluginException {
        /* Phone-only/test engine. */
      } on PlatformException {
        showError('Chưa chuyển được video về điện thoại. Thử lại.');
        return;
      }
      if (!ref.mounted || request != _carRequest) return;
      state = state.copy(carVideo: false, carPip: false, clearCarView: true);
      await _browser?.setCompact(state.inPip).catchError((Object _) {});
      unawaited(_configurePip());
      return;
    }
    await ensureInitialized();
    final id = _browser?.androidViewIdentifier;
    if (!ref.mounted || request != _carRequest) return;
    if (id == null) {
      showError('Chưa kết nối được trình phát với màn hình khách.');
      return;
    }
    _browser?.exitFullscreen();
    state = state.copy(
      carVideo: true,
      clearCarView: true,
      clearFullscreen: true,
    );
    // Let Flutter detach the phone platform view before the car reparents it.
    // A car-first headless engine may not produce a frame yet.
    try {
      await WidgetsBinding.instance.endOfFrame.timeout(
        const Duration(milliseconds: 350),
      );
    } on TimeoutException {
      /* No attached phone view. */
    }
    if (!ref.mounted || request != _carRequest || !state.carVideo) return;
    try {
      await const MethodChannel(
        'vn.thanhtaxixanh/car',
      ).invokeMethod<void>('prepareCarVideo');
    } on MissingPluginException {
      /* Test engine. */
    } on PlatformException {
      if (!ref.mounted || request != _carRequest) return;
      await showOnCar(false);
      showError('Chưa kết nối được trình phát với màn hình khách.');
      return;
    }
    if (!ref.mounted || request != _carRequest || !state.carVideo) return;
    state = state.copy(carViewId: id);
    unawaited(_configurePip());
    _carAttachTimeout = Timer(const Duration(seconds: 8), () {
      if (ref.mounted && request == _carRequest && state.carVideo) {
        unawaited(showOnCar(false));
        showError(
          'Màn hình khách chưa nhận trình phát. Video đã chuyển về điện thoại.',
        );
      }
    });
  }

  void confirmCarVideo(int id) {
    if (state.carVideo && state.carViewId == id) _carAttachTimeout?.cancel();
  }

  Future<void> toggleCarPip() async {
    if (!state.carVideo || state.media == null) {
      showError('Chọn một video trước khi thu nhỏ.');
      return;
    }
    final mini = !state.carPip;
    await _browser?.setCompact(mini);
    if (ref.mounted) state = state.copy(carPip: mini);
  }
}
