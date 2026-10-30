import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../data/sqlite_event_repository.dart';
import '../domain/calendar_event.dart';
import 'calendar_providers.dart';

final eventRepositoryProvider = FutureProvider<EventRepository>(
  (ref) async => SqliteEventRepository(
    await ref.watch(appDatabaseProvider.future),
    ref.watch(lunarCalendarProvider),
  ),
);

final eventsProvider = FutureProvider(
  (ref) async => (await ref.watch(eventRepositoryProvider.future)).list(),
);

final vietnamTodayProvider = Provider<DateTime>((ref) {
  final instant =
      ref.watch(calendarClockProvider).value ?? DateTime.now().toUtc();
  final civil = instant.toUtc().add(const Duration(hours: 7));
  return DateTime.utc(civil.year, civil.month, civil.day);
});

final eventOccurrencesProvider = Provider((ref) {
  final today = ref.watch(vietnamTodayProvider);
  final calendar = ref.watch(lunarCalendarProvider);
  return ref.watch(eventsProvider).whenData((events) {
    final occurrences = <EventOccurrence>[];
    for (final event in events) {
      final date = event.nextOnOrAfter(today, calendar);
      if (date != null) occurrences.add(EventOccurrence(event, date));
    }
    occurrences.sort((a, b) {
      final dateOrder = a.date.compareTo(b.date);
      return dateOrder != 0
          ? dateOrder
          : a.event.title.compareTo(b.event.title);
    });
    return occurrences;
  });
});
