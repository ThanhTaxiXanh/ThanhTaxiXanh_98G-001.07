import 'package:sqflite/sqflite.dart';

import '../domain/calendar_event.dart';
import '../domain/default_events.dart';
import '../domain/lunar_calendar.dart';

class SqliteEventRepository implements EventRepository {
  SqliteEventRepository(this.db, this.calendar);
  final Database db;
  final LunarCalendar calendar;

  Future<void> _seedDefaults() => db.transaction((txn) async {
    final marker = await txn.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['default_events_v1'],
    );
    if (marker.isNotEmpty) return;
    for (final event in defaultCalendarEvents) {
      event.validate(calendar);
      await txn.insert(
        'events',
        _row(event),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await txn.insert('metadata', {'key': 'default_events_v1', 'value': '1'});
  });

  Map<String, Object?> _row(CalendarEvent event) => {
    'id': event.id,
    'title': event.title.trim(),
    'notes': event.notes.trim(),
    'day': event.day,
    'month': event.month,
    'year': event.year,
    'calendar': event.calendar.name,
    'is_leap': event.leap ? 1 : 0,
    'is_yearly': event.yearly ? 1 : 0,
    'is_monthly': event.monthly ? 1 : 0,
  };

  @override
  Future<List<CalendarEvent>> list() async {
    await _seedDefaults();
    return (await db.query('events', orderBy: 'title'))
        .map(
          (r) => CalendarEvent(
            id: r['id'] as String,
            title: r['title'] as String,
            notes: r['notes'] as String,
            day: r['day'] as int,
            month: r['month'] as int,
            year: r['year'] as int,
            calendar: EventCalendar.values.byName(r['calendar'] as String),
            leap: r['is_leap'] == 1,
            yearly: r['is_yearly'] == 1,
            monthly: r['is_monthly'] == 1,
          ),
        )
        .toList();
  }

  @override
  Future<void> save(CalendarEvent event) async {
    event.validate(calendar);
    await db.insert(
      'events',
      _row(event),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }
}
