import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'event_providers.dart';
import 'events_screen.dart';

class UpcomingEventsCard extends ConsumerWidget {
  const UpcomingEventsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(vietnamTodayProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sự kiện', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ref
                .watch(eventOccurrencesProvider)
                .when(
                  loading: () => const Text('Đang tải sự kiện…'),
                  error: (_, _) => TextButton(
                    onPressed: () => ref.invalidate(eventsProvider),
                    child: const Text('Không thể tải sự kiện. Thử lại'),
                  ),
                  data: (occurrences) {
                    final upcoming = occurrences
                        .where(
                          (o) => !o.date.isAfter(
                            today.add(const Duration(days: 30)),
                          ),
                        )
                        .toList();
                    if (upcoming.isEmpty) {
                      return const Text('Chưa có sự kiện trong 30 ngày tới.');
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final occurrence in upcoming.take(5))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  occurrence.event.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${occurrence.date == today ? "Hôm nay" : "${occurrence.date.day}/${occurrence.date.month}/${occurrence.date.year}"}'
                                  ' · ${occurrence.event.dateLabel}',
                                ),
                              ],
                            ),
                          ),
                        if (upcoming.length > 5)
                          Text('Và ${upcoming.length - 5} sự kiện khác…'),
                      ],
                    );
                  },
                ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('manage-events'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const EventsScreen()),
              ),
              icon: const Icon(Icons.event_note),
              label: const Text('Quản lý sự kiện'),
            ),
          ],
        ),
      ),
    );
  }
}
