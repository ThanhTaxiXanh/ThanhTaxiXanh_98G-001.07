import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../domain/youtube_location.dart';
import '../data/youtube_bridge_codec.dart';
import 'youtube_browser.dart';

class WebViewYouTubeBrowser implements YouTubeBrowser {
  WebViewYouTubeBrowser(this.callbacks);
  final YouTubeBrowserCallbacks callbacks;
  final _controller = WebViewController(
    onPermissionRequest: (request) => unawaited(request.deny()),
  );
  static final _filterScript = rootBundle.loadString(
    'assets/scripts/youtube_filter.js',
  );
  static final _mediaScript = rootBundle.loadString(
    'assets/scripts/youtube_media.js',
  );
  bool _closed = false;
  final _bridge = YouTubeBridgeCodec();
  int _document = 0;
  bool _playOnReady = false;
  Uri? _mainLocation;
  OnHideCustomWidgetCallback? _hideFullscreen;
  @override
  int? get androidViewIdentifier =>
      _controller.platform is AndroidWebViewController
      ? (_controller.platform as AndroidWebViewController).webViewIdentifier
      : null;

  @override
  Future<void> initialize(Uri location) async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setBackgroundColor(Colors.white);
    await _controller.addJavaScriptChannel(
      'TaxiYouTubeMedia',
      onMessageReceived: (message) {
        if (_closed ||
            _mainLocation == null ||
            !YouTubeLocation.isContent(_mainLocation!)) {
          return;
        }
        final decoded = _bridge.decode(message.message);
        if (decoded?.error != null) callbacks.onError(decoded!.error!);
        if (decoded?.media != null) callbacks.onMedia?.call(decoded!.media!);
      },
    );
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) {
          if (_closed) return NavigationDecision.prevent;
          final uri = Uri.tryParse(request.url);
          final appLink = uri == null ? null : YouTubeLocation.fromAppLink(uri);
          if (request.isMainFrame && appLink != null) {
            _playOnReady = true;
            unawaited(_controller.loadRequest(appLink));
            return NavigationDecision.prevent;
          }
          if (!request.isMainFrame && uri?.scheme == 'https') {
            return NavigationDecision.navigate;
          }
          if (uri != null && YouTubeLocation.allowsNavigation(uri)) {
            return NavigationDecision.navigate;
          }
          if (request.isMainFrame) {
            callbacks.onError(
              'Liên kết bên ngoài YouTube chưa được mở. '
              'Hãy nhập từ khóa hoặc liên kết YouTube.',
            );
          }
          return NavigationDecision.prevent;
        },
        onProgress: (progress) {
          if (!_closed) callbacks.onProgress(progress);
        },
        onPageStarted: (url) {
          _document++;
          _bridge.newDocument();
          _mainLocation = Uri.tryParse(url);
          if (!_closed) callbacks.onProgress(0);
        },
        onUrlChange: (change) {
          final uri = Uri.tryParse(change.url ?? '');
          _mainLocation = uri;
          if (!_closed && uri != null) callbacks.onLocation(uri);
        },
        onPageFinished: (url) async {
          if (_closed) return;
          final document = _document;
          callbacks.onProgress(100);
          final uri = Uri.tryParse(url);
          if (uri != null) callbacks.onLocation(uri);
          if (uri != null && YouTubeLocation.isContent(uri)) {
            try {
              final script = await _mediaScript;
              final current = Uri.tryParse(
                await _controller.currentUrl() ?? '',
              );
              if (_closed ||
                  document != _document ||
                  current == null ||
                  !YouTubeLocation.isContent(current)) {
                return;
              }
              await _controller.runJavaScript(_bridge.inject(script));
              if (_playOnReady) {
                _playOnReady = false;
                await play();
              }
            } catch (_) {
              if (!_closed) {
                callbacks.onError(
                  'Chưa kết nối được điều khiển media. Thử tải lại.',
                );
              }
            }
          }
          if (_closed || document != _document) return;
          callbacks.onReady();
        },
        onWebResourceError: (error) {
          if (!_closed && error.isForMainFrame != false) {
            callbacks.onError(
              'Không tải được YouTube. Kiểm tra kết nối mạng rồi tải lại.',
            );
          }
        },
        onHttpError: (error) {
          if (!_closed &&
              _mainLocation != null &&
              error.request?.uri == _mainLocation) {
            callbacks.onError(
              'YouTube chưa trả về trang hợp lệ. Vui lòng thử tải lại sau.',
            );
          }
        },
      ),
    );
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setAllowFileAccess(false);
      await platform.setAllowContentAccess(false);
      await platform.setMixedContentMode(MixedContentMode.neverAllow);
      // Native media-session play is an explicit user action outside the page.
      await platform.setMediaPlaybackRequiresUserGesture(false);
      await platform.setCustomWidgetCallbacks(
        onShowCustomWidget: (widget, hide) {
          if (_closed) {
            hide();
            return;
          }
          _hideFullscreen = hide;
          callbacks.onFullscreen(widget);
        },
        onHideCustomWidget: () {
          _hideFullscreen = null;
          if (!_closed) callbacks.onFullscreen(null);
        },
      );
    }
    if (!_closed) await load(location);
  }

  @override
  Widget buildView(BuildContext context) {
    final platform = _controller.platform;
    final params = PlatformWebViewWidgetCreationParams(
      controller: platform,
      layoutDirection: TextDirection.ltr,
    );
    return WebViewWidget.fromPlatformCreationParams(
      params: platform is AndroidWebViewController
          ? AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
              params,
              displayWithHybridComposition: true,
            )
          : params,
    );
  }

  @override
  Future<void> load(Uri location) {
    if (!YouTubeLocation.isContent(location)) {
      throw const FormatException('Chỉ nhận liên kết HTTPS của YouTube.');
    }
    return _controller.loadRequest(location);
  }

  @override
  Future<void> reload() => _controller.reload();
  @override
  Future<bool> canGoBack() => _controller.canGoBack();
  @override
  Future<void> goBack() async {
    await pause();
    await _controller.goBack();
  }

  @override
  Future<void> setFiltering(bool enabled) async {
    final document = _document;
    final current = Uri.tryParse(await _controller.currentUrl() ?? '');
    if (_closed || current == null || !YouTubeLocation.isContent(current)) {
      return;
    }
    final script = await _filterScript;
    if (_closed || document != _document) return;
    await _controller.runJavaScript(script);
    await _controller.runJavaScript(
      'window.taxiYouTubeFilter.setEnabled($enabled);',
    );
  }

  @override
  Future<void> pause() => _controller.runJavaScript(
    'if(window.taxiYouTubeMedia) window.taxiYouTubeMedia.pause();'
    "document.querySelectorAll('video,audio').forEach(function(v){v.pause();});",
  );

  @override
  Future<void> play() => _controller.runJavaScript(
    'if(window.taxiYouTubeMedia) window.taxiYouTubeMedia.play();',
  );
  @override
  Future<void> seek(Duration position) {
    final seconds = position.inMilliseconds / 1000;
    return _controller.runJavaScript(
      'if(window.taxiYouTubeMedia) window.taxiYouTubeMedia.seek($seconds);',
    );
  }

  @override
  Future<void> setCompact(bool compact) => _controller.runJavaScript(
    'if(window.taxiYouTubeMedia) window.taxiYouTubeMedia.compact($compact);',
  );
  @override
  Future<void> setBackgroundAudio(bool enabled) => _controller.runJavaScript(
    'if(window.taxiYouTubeMedia) window.taxiYouTubeMedia.configureBackground($enabled);',
  );

  @override
  void exitFullscreen() {
    final hide = _hideFullscreen;
    _hideFullscreen = null;
    hide?.call();
    if (!_closed) callbacks.onFullscreen(null);
  }

  @override
  void close() {
    _closed = true;
    exitFullscreen();
    unawaited(pause().catchError((Object _) {}));
  }
}
