import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'webview_youtube_browser.dart';

class YouTubeBrowserCallbacks {
  const YouTubeBrowserCallbacks({
    required this.onProgress,
    required this.onLocation,
    required this.onReady,
    required this.onError,
    required this.onFullscreen,
  });
  final void Function(int) onProgress;
  final void Function(Uri) onLocation;
  final void Function() onReady;
  final void Function(String) onError;
  final void Function(Widget?) onFullscreen;
}

abstract interface class YouTubeBrowser {
  Widget buildView(BuildContext context);
  Future<void> initialize(Uri location);
  Future<void> load(Uri location);
  Future<void> reload();
  Future<bool> canGoBack();
  Future<void> goBack();
  Future<void> setFiltering(bool enabled);
  Future<void> pause();
  void exitFullscreen();
  void close();
}

typedef YouTubeBrowserFactory =
    YouTubeBrowser Function(YouTubeBrowserCallbacks callbacks);

final youTubeBrowserFactoryProvider = Provider<YouTubeBrowserFactory>(
  (ref) => WebViewYouTubeBrowser.new,
);
