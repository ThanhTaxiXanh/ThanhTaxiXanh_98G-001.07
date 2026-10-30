import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import '../domain/youtube_media.dart';
import 'youtube_session.dart';

/// Publishes actual browser playback to Android's MediaSession/MediaBrowser.
class TaxiAudioHandler extends BaseAudioHandler {
  TaxiAudioHandler(this.session);
  final YouTubeSession session;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  List<YouTubeMedia> _recent = [];
  DateTime? _lastPositionUpdate;
  final _recentChanges = BehaviorSubject<Map<String, dynamic>>.seeded({});

  Future<void> initializeAudioEvents() async {
    final audio = await AudioSession.instance;
    // Android WebView/Chromium owns audio focus for its media element. A
    // second AudioSession.setActive request can suspend that same WebView.
    _subscriptions.add(
      audio.becomingNoisyEventStream.listen((_) {
        unawaited(pause());
      }),
    );
  }

  Future<void> disposeResources() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _recentChanges.close();
  }

  MediaItem _item(YouTubeMedia media) => MediaItem(
    id: 'youtube:${media.id}',
    title: media.title,
    artist: media.artist,
    album: 'YouTube',
    duration: media.duration,
    artUri: Uri.https('i.ytimg.com', '/vi/${media.id}/hqdefault.jpg'),
    playable: true,
  );
  void updateRecent(List<YouTubeMedia> recent) {
    _recent = recent;
    queue.add(recent.map(_item).toList());
    _recentChanges.add({});
  }

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) =>
      parentMediaId == 'recent'
      ? _recentChanges
      : super.subscribeToChildren(parentMediaId);

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    if (parentMediaId == AudioService.browsableRootId) {
      return [
        const MediaItem(
          id: 'recent',
          title: 'YouTube gần đây',
          playable: false,
          extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
        ),
      ];
    }
    if (parentMediaId == 'recent') return _recent.map(_item).toList();
    return [];
  }

  void acceptMedia(YouTubeMedia media) {
    final previous = mediaItem.value;
    if (previous?.id != 'youtube:${media.id}' ||
        previous?.title != media.title ||
        previous?.duration != media.duration) {
      mediaItem.add(_item(media));
    }
    final current = playbackState.value;
    final now = DateTime.now();
    // Publish changes/seeks and occasional corrections, not a clock every tick.
    if (current.playing == media.playing &&
        current.processingState ==
            (media.buffering
                ? AudioProcessingState.buffering
                : AudioProcessingState.ready) &&
        (current.position - media.position).abs() <
            const Duration(seconds: 3) &&
        _lastPositionUpdate != null &&
        now.difference(_lastPositionUpdate!) < const Duration(seconds: 15)) {
      return;
    }
    _lastPositionUpdate = now;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          media.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: {if (media.duration != null) MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 3],
        processingState: media.buffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: media.playing && !media.ended,
        updatePosition: media.position,
        queueIndex: _recent.indexWhere((entry) => entry.id == media.id) < 0
            ? null
            : _recent.indexWhere((entry) => entry.id == media.id),
      ),
    );
  }

  void markPaused() => playbackState.add(
    playbackState.value.copyWith(
      playing: false,
      controls: const [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
    ),
  );
  void markStopped() {
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
    );
  }

  @override
  Future<void> play() => session.play();
  @override
  Future<void> pause() => session.pause();
  @override
  Future<void> stop() => session.stop();
  @override
  Future<void> seek(Duration position) => session.seek(position);
  @override
  Future<void> skipToNext() => session.skip(1);
  @override
  Future<void> skipToPrevious() => session.skip(-1);
  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    if (mediaId.startsWith('youtube:')) {
      await session.playId(mediaId.substring(8));
    }
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    for (final media in _recent) {
      if ('youtube:${media.id}' == mediaId) return _item(media);
    }
    return null;
  }
}
