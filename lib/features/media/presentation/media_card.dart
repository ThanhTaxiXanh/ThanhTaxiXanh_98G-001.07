import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'youtube_screen.dart';
import 'youtube_session.dart';

class MediaCard extends ConsumerWidget {
  const MediaCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(
      youTubeSessionProvider.select((state) => state.media),
    );
    final session = ref.read(youTubeSessionProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Media • YouTube',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              media?.title ?? 'Chọn video để xem hoặc nghe',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (media != null)
              Text(media.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: media?.playing == true ? 'Tạm dừng' : 'Phát',
                  onPressed: media == null
                      ? null
                      : media.playing
                      ? session.pause
                      : session.play,
                  icon: Icon(
                    media?.playing == true ? Icons.pause : Icons.play_arrow,
                  ),
                ),
                IconButton(
                  tooltip: 'Dừng phát',
                  onPressed: media == null ? null : session.stop,
                  icon: const Icon(Icons.stop),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const YouTubeScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.smart_display_outlined),
                  label: const Text('Mở YouTube'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
