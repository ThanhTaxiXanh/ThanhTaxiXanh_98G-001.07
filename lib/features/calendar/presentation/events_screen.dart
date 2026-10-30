import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/calendar_event.dart';
import 'calendar_providers.dart';
import 'event_editor_screen.dart';
import 'event_providers.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
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
    if (confirmed != true) return;
    try {
      await (await ref.read(eventRepositoryProvider.future)).delete(event.id);
      ref.invalidate(eventsProvider);
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
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(event.title),
                    subtitle: Text(
                      '${event.dateLabel}\n'
                      '${next == null ? (event.yearly ? "Không còn lần lặp trong khoảng lịch hỗ trợ" : "Đã qua") : "Lần tới: ${next.day}/${next.month}/${next.year}"}'
                      '${event.notes.isEmpty ? "" : "\n${event.notes}"}',
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
                          _delete(context, ref, event);
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
