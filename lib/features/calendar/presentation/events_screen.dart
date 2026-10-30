import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/calendar_event.dart';
import 'calendar_providers.dart';
import 'event_editor_screen.dart';
import 'event_countdown.dart';
import 'event_providers.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  Future<void> _delete(BuildContext context, CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa sự kiện?'),
        content: Text(event.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await (await container.read(
        eventRepositoryProvider.future,
      )).delete(event.id);
      container.invalidate(eventsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xóa sự kiện. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final today = ref.watch(vietnamTodayProvider);
    final lunar = ref.watch(lunarCalendarProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý sự kiện')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-event'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EventEditorScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Thêm sự kiện'),
      ),
      body: SafeArea(
        child: events.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(eventsProvider),
              child: const Text('Không thể mở sự kiện. Thử lại'),
            ),
          ),
          data: (events) {
            if (events.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Chưa có sự kiện. Nhấn “Thêm sự kiện” để lưu lịch cá nhân.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final sorted = [...events]
              ..sort((a, b) {
                final da = a.nextOnOrAfter(today, lunar);
                final db = b.nextOnOrAfter(today, lunar);
                if (da == null && db != null) return 1;
                if (db == null && da != null) return -1;
                return da != null && db != null
                    ? da.compareTo(db)
                    : a.title.compareTo(b.title);
              });
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final event = sorted[i];
                final next = event.nextOnOrAfter(today, lunar);
                final occurrence = next == null
                    ? null
                    : EventOccurrence(event, next);
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(occurrence?.title(lunar) ?? event.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.dateLabel),
                        if (occurrence != null)
                          EventCountdown(
                            occurrence: occurrence,
                            today: today,
                            calendar: lunar,
                          )
                        else
                          Text(
                            event.yearly || event.monthly
                                ? 'Không còn lần lặp trong khoảng lịch hỗ trợ'
                                : 'Đã qua',
                          ),
                        if (event.notes.isNotEmpty) Text(event.notes),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EventEditorScreen(event: event),
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      key: ValueKey('event-menu-${event.id}'),
                      tooltip: 'Thao tác sự kiện',
                      onSelected: (action) {
                        if (action == 'edit') {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EventEditorScreen(event: event),
                            ),
                          );
                        } else {
                          _delete(context, event);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Sửa')),
                        PopupMenuItem(value: 'delete', child: Text('Xóa')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
