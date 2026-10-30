import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/youtube_location.dart';
import 'youtube_browser.dart';
import 'youtube_providers.dart';

class YouTubeScreen extends ConsumerStatefulWidget {
  const YouTubeScreen({super.key});
  @override
  ConsumerState<YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends ConsumerState<YouTubeScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  YouTubeBrowser? _browser;
  Widget? _fullscreen;
  Timer? _rememberTimer;
  bool _initializing = false, _canGoBack = false;
  bool _foreground = true;
  int _progress = 0;
  int _historyGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (_initializing) return;
    _initializing = true;
    try {
      final settings = await ref.read(youTubeSettingsProvider.future);
      if (!mounted) return;
      final browser = ref.read(youTubeBrowserFactoryProvider)(
        YouTubeBrowserCallbacks(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onLocation: _locationChanged,
          onReady: () {
            unawaited(_refreshHistory());
            unawaited(_applyFiltering());
          },
          onError: _showError,
          onFullscreen: (widget) {
            if (mounted) setState(() => _fullscreen = widget);
          },
        ),
      );
      setState(() {
        _browser = browser;
        _error = null;
      });
      await browser.initialize(settings.startLocation);
    } catch (_) {
      _browser?.close();
      if (mounted) setState(() => _browser = null);
      _showError('Không mở được YouTube trên thiết bị này. Vui lòng thử lại.');
    } finally {
      _initializing = false;
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _error = message;
        _progress = 100;
      });
    }
  }

  void _locationChanged(Uri uri) {
    if (!mounted) return;
    unawaited(_refreshHistory());
    _rememberTimer?.cancel();
    _rememberTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      try {
        await ref.read(youTubeSettingsProvider.notifier).remember(uri);
      } catch (_) {
        _showError('Chưa lưu được trang gần nhất. Bạn vẫn có thể xem video.');
      }
    });
  }

  Future<void> _refreshHistory() async {
    final generation = ++_historyGeneration;
    try {
      final value = await _browser?.canGoBack() ?? false;
      if (mounted && generation == _historyGeneration) {
        setState(() => _canGoBack = value);
      }
    } catch (_) {
      // A disposed native view can finish an outstanding history request.
    }
  }

  Future<void> _applyFiltering() async {
    if (!mounted) return;
    final enabled =
        _foreground &&
        (ref.read(youTubeSettingsProvider).asData?.value.filterAds ?? true);
    try {
      await _browser?.setFiltering(enabled);
    } catch (_) {
      _showError(
        'Chưa kích hoạt được bộ lọc quảng cáo. '
        'Thử tải lại hoặc tắt bộ lọc nếu video không phát.',
      );
    }
  }

  Future<void> _toggleFiltering() async {
    final current = ref.read(youTubeSettingsProvider).asData?.value;
    if (current == null) return;
    try {
      await ref
          .read(youTubeSettingsProvider.notifier)
          .setFilter(!current.filterAds);
    } catch (_) {
      _showError('Chưa lưu được cài đặt bộ lọc cho lần mở sau.');
    }
    if (mounted) await _applyFiltering();
  }

  Future<void> _load(Uri uri) async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    try {
      await _browser?.pause().catchError((Object _) {});
      await _browser?.load(uri);
    } catch (_) {
      _showError('Chưa mở được trang YouTube. Vui lòng thử lại.');
    }
  }

  void _submit() {
    try {
      unawaited(_load(YouTubeLocation.fromInput(_input.text)));
    } on FormatException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _back() async {
    if (_fullscreen != null) {
      _browser?.exitFullscreen();
      return;
    }
    try {
      if (await _browser?.canGoBack() ?? false) {
        await _browser?.goBack();
        await _refreshHistory();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      _showError('Chưa quay lại được trang trước. Thử mở trang chủ.');
    }
  }

  Future<void> _retry() async {
    setState(() => _error = null);
    if (_browser == null) {
      ref.invalidate(youTubeSettingsProvider);
      await _initialize();
    } else {
      try {
        await _browser!.reload();
      } catch (_) {
        _showError('Chưa tải lại được YouTube. Kiểm tra mạng rồi thử lại.');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      unawaited(_browser?.pause().catchError((Object _) {}));
    } else {
      unawaited(_applyFiltering());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rememberTimer?.cancel();
    _browser?.close();
    _input.dispose();
    super.dispose();
  }

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Text(
            'YouTube dành cho màn hình riêng của hành khách.\n\n'
            'Bộ lọc quảng cáo đang thử nghiệm: ẩn các ô quảng cáo và '
            'bỏ qua quảng cáo khi trang nhận diện được. '
            'Có thể vẫn xuất hiện quảng cáo khi YouTube thay đổi. '
            'Tắt bộ lọc nếu video không phát.\n\n'
            'Cần Internet. Có thể xem video công khai không cần đăng nhập. '
            'Google có thể không cho đăng nhập bên trong WebView.\n\n'
            'Việc chiếu lên Android Auto phụ thuộc bộ nhận và điện thoại; '
            'bản này chưa xác nhận hỗ trợ chiếu video khi xe di chuyển.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(youTubeSettingsProvider).asData?.value;
    final fullscreen = _fullscreen;
    return PopScope(
      canPop: fullscreen == null && !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: fullscreen != null
            ? null
            : AppBar(
                leading: IconButton(
                  key: const Key('youtube-back'),
                  tooltip: 'Quay lại',
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back),
                ),
                title: const Text('YouTube • Khách'),
                actions: [
                  IconButton(
                    key: const Key('youtube-filter'),
                    tooltip: settings?.filterAds == true
                        ? 'Lọc quảng cáo: bật (thử nghiệm)'
                        : 'Lọc quảng cáo: tắt',
                    onPressed: settings == null ? null : _toggleFiltering,
                    icon: Icon(
                      settings?.filterAds == true
                          ? Icons.shield_outlined
                          : Icons.gpp_bad_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Thông tin YouTube',
                    onPressed: _showHelp,
                    icon: const Icon(Icons.info_outline),
                  ),
                ],
              ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Keep the native WebView mounted while its fullscreen video custom
            // view is shown, so switching modes cannot destroy the session.
            Offstage(
              offstage: fullscreen != null,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          IconButton(
                            key: const Key('youtube-home'),
                            tooltip: 'Trang chủ YouTube',
                            onPressed: _browser == null
                                ? null
                                : () => _load(YouTubeLocation.home),
                            icon: const Icon(Icons.home_outlined),
                          ),
                          Expanded(
                            child: TextField(
                              key: const Key('youtube-search'),
                              controller: _input,
                              maxLength: 2048,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                hintText: 'Tìm video hoặc dán liên kết',
                                counterText: '',
                                contentPadding: const EdgeInsets.all(12),
                                suffixIcon: IconButton(
                                  key: const Key('youtube-submit'),
                                  tooltip: 'Tìm kiếm',
                                  onPressed: _browser == null ? null : _submit,
                                  icon: const Icon(Icons.search),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('youtube-reload'),
                            tooltip: 'Tải lại',
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                    if (_progress < 100)
                      LinearProgressIndicator(
                        value: _progress == 0 ? null : _progress / 100,
                      ),
                    if (_error != null)
                      Flexible(
                        child: SingleChildScrollView(
                          child: MaterialBanner(
                            content: Text(_error!),
                            actions: [
                              TextButton(
                                onPressed: () => setState(() => _error = null),
                                child: const Text('Đóng'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      flex: 4,
                      child:
                          _browser?.buildView(context) ??
                          const Center(child: Text('Đang mở YouTube…')),
                    ),
                  ],
                ),
              ),
            ),
            if (fullscreen != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      fullscreen,
                      Positioned(
                        top: 8,
                        right: 8,
                        child: SafeArea(
                          child: IconButton.filledTonal(
                            key: const Key('youtube-exit-fullscreen'),
                            tooltip: 'Thoát toàn màn hình',
                            onPressed: () => _browser?.exitFullscreen(),
                            icon: const Icon(Icons.fullscreen_exit),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
