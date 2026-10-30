import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/youtube_location.dart';
import 'youtube_providers.dart';
import 'youtube_session.dart';

class YouTubeScreen extends ConsumerStatefulWidget {
  const YouTubeScreen({super.key});
  @override
  ConsumerState<YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends ConsumerState<YouTubeScreen> {
  final _input = TextEditingController();
  late final YouTubeSession _session;
  @override
  void initState() {
    super.initState();
    _session = ref.read(youTubeSessionProvider.notifier);
    _session.setVisible(true);
    unawaited(_session.ensureInitialized());
  }

  @override
  void dispose() {
    _session.setVisible(false);
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    try {
      unawaited(_session.load(YouTubeLocation.fromInput(_input.text)));
    } on FormatException catch (error) {
      _session.showError(error.message);
    }
  }

  Future<void> _back() async {
    final state = ref.read(youTubeSessionProvider);
    if (state.fullscreen != null) {
      _session.exitFullscreen();
      return;
    }
    if (state.canGoBack) {
      await _session.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _option(String value) async {
    final settings = ref.read(youTubeSettingsProvider).asData?.value;
    final controller = ref.read(youTubeSettingsProvider.notifier);
    try {
      if (value == 'background' && settings != null) {
        await controller.setBackgroundAudio(!settings.backgroundAudio);
      } else if (value == 'autoPip' && settings != null) {
        await controller.setAutoPip(!settings.autoPip);
      } else if (value == 'stop') {
        await _session.stop();
      } else if (value == 'help' && mounted) {
        _showHelp();
      }
    } catch (_) {
      _session.showError('Chưa lưu được cài đặt cho lần mở sau.');
    }
  }

  Future<void> _filter() async {
    final settings = ref.read(youTubeSettingsProvider).asData?.value;
    if (settings == null) return;
    try {
      await ref
          .read(youTubeSettingsProvider.notifier)
          .setFilter(!settings.filterAds);
    } catch (_) {
      _session.showError('Chưa lưu được cài đặt bộ lọc.');
    }
  }

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Text(
            'Chọn video rồi dùng nút PiP để xem trong cửa sổ nhỏ trên Android. '
            'Có thể bật/tắt tự vào PiP khi về màn hình chính.\n\n'
            'Phát nền giữ phiên nghe khi quay về trang chính, chuyển ứng dụng hoặc khóa màn hình. '
            'Điều khiển phát/tạm dừng/dừng ở thông báo, màn hình khóa hoặc Android Auto. '
            'YouTube có thể giới hạn phát nền của video/tài khoản; PiP giữ video hiển thị.\n\n'
            'Android Auto nhận phiên âm thanh và danh sách video gần đây. '
            'Android Auto không nhận cửa sổ PiP Android hoặc video WebView qua dịch vụ media.\n\n'
            'Bộ lọc quảng cáo đang thử nghiệm. Tắt bộ lọc nếu video không phát. '
            'Cần Internet; Google có thể từ chối đăng nhập trong WebView.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(youTubeSessionProvider);
    final settings = ref.watch(youTubeSettingsProvider).asData?.value;
    final compact = state.inPip || state.fullscreen != null;
    return PopScope(
      canPop: state.fullscreen == null && !state.canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: compact
            ? null
            : AppBar(
                leading: IconButton(
                  key: const Key('youtube-back'),
                  tooltip: 'Quay lại',
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back),
                ),
                title: const Text(
                  'YouTube • Khách',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    key: const Key('youtube-pip'),
                    tooltip: 'Hình trong hình (PiP)',
                    onPressed: _session.enterPip,
                    icon: const Icon(Icons.picture_in_picture_alt),
                  ),
                  IconButton(
                    key: const Key('youtube-filter'),
                    tooltip: settings?.filterAds == true
                        ? 'Lọc quảng cáo: bật (thử nghiệm)'
                        : 'Lọc quảng cáo: tắt',
                    onPressed: settings == null ? null : _filter,
                    icon: Icon(
                      settings?.filterAds == true
                          ? Icons.shield_outlined
                          : Icons.gpp_bad_outlined,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Cài đặt YouTube',
                    onSelected: _option,
                    itemBuilder: (_) => [
                      CheckedPopupMenuItem(
                        value: 'background',
                        checked: settings?.backgroundAudio ?? true,
                        child: const Text('Phát âm thanh nền'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'autoPip',
                        checked: settings?.autoPip ?? true,
                        child: const Text('Tự bật PiP khi về Home'),
                      ),
                      const PopupMenuItem(
                        value: 'stop',
                        child: Text('Dừng phát'),
                      ),
                      const PopupMenuItem(
                        value: 'help',
                        child: Text('Thông tin YouTube'),
                      ),
                    ],
                  ),
                ],
              ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              top: !state.inPip,
              bottom: !state.inPip,
              child: Column(
                children: [
                  Offstage(
                    offstage: compact,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          IconButton(
                            key: const Key('youtube-home'),
                            tooltip: 'Trang chủ YouTube',
                            onPressed: state.initialized
                                ? () => _session.load(YouTubeLocation.home)
                                : null,
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
                                  onPressed: state.initialized ? _submit : null,
                                  icon: const Icon(Icons.search),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('youtube-reload'),
                            tooltip: 'Tải lại',
                            onPressed: _session.reload,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!compact && state.progress < 100)
                    LinearProgressIndicator(
                      value: state.progress == 0 ? null : state.progress / 100,
                    ),
                  if (!compact && state.message != null)
                    Flexible(
                      child: SingleChildScrollView(
                        child: MaterialBanner(
                          content: Text(state.message!),
                          actions: [
                            TextButton(
                              onPressed: _session.clearError,
                              child: const Text('Đóng'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 4,
                    child: Offstage(
                      offstage: state.fullscreen != null,
                      child:
                          _session.browser?.buildView(context) ??
                          const Center(child: Text('Đang mở YouTube…')),
                    ),
                  ),
                ],
              ),
            ),
            if (state.fullscreen != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      state.fullscreen!,
                      if (!state.inPip)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: SafeArea(
                            child: Row(
                              children: [
                                IconButton.filledTonal(
                                  tooltip: 'Hình trong hình (PiP)',
                                  onPressed: _session.enterPip,
                                  icon: const Icon(
                                    Icons.picture_in_picture_alt,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  key: const Key('youtube-exit-fullscreen'),
                                  tooltip: 'Thoát toàn màn hình',
                                  onPressed: _session.exitFullscreen,
                                  icon: const Icon(Icons.fullscreen_exit),
                                ),
                              ],
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
