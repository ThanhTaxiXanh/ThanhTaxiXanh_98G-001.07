import 'dart:math';

import 'lunar_calendar.dart';

enum EventCalendar { solar, lunar }

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.day,
    required this.month,
    required this.year,
    this.notes = '',
    this.calendar = EventCalendar.solar,
    this.leap = false,
    this.yearly = false,
  });

  final String id;
  final String title;
  final String notes;
  final int day;
  final int month;
  final int year;
  final EventCalendar calendar;
  final bool leap;
  final bool yearly;

  DateTime? _dateForYear(int eventYear, LunarCalendar lunar) {
    if (calendar == EventCalendar.lunar) {
      return lunar.lunarToSolar(LunarDate(day, month, eventYear, leap: leap));
    }
    final date = DateTime.utc(eventYear, month, day);
    return date.year == eventYear && date.month == month && date.day == day
        ? date
        : null;
  }

  void validate(LunarCalendar lunar) {
    if (id.isEmpty ||
        title.trim().isEmpty ||
        title.length > 100 ||
        notes.length > 1000 ||
        year < 1900 ||
        year > 2099 ||
        (calendar == EventCalendar.solar && leap) ||
        _dateForYear(year, lunar) == null) {
      throw ArgumentError('Invalid event or calendar date.');
    }
  }

  /// Civil Gregorian day for the next occurrence; never shifts invalid dates.
  /// Feb 29 and lunar leap months recur only in years containing that date.
  DateTime? nextOnOrAfter(DateTime today, LunarCalendar lunar) {
    final start = DateTime.utc(today.year, today.month, today.day);
    if (!yearly) {
      final date = _dateForYear(year, lunar);
      return date != null && !date.isBefore(start) ? date : null;
    }
    // A lunar year can begin in the previous Gregorian year for month 11/12.
    for (var y = max(year, start.year - 1); y <= 2099; y++) {
      final date = _dateForYear(y, lunar);
      if (date != null && !date.isBefore(start)) return date;
    }
    return null;
  }

  String get dateLabel =>
      '${calendar == EventCalendar.lunar ? 'Âm lịch' : 'Dương lịch'} '
      '$day/$month${leap ? ' nhuận' : ''}${yearly ? ' · Hằng năm' : '/$year'}';
}

class EventOccurrence {
  const EventOccurrence(this.event, this.date);
  final CalendarEvent event;
  final DateTime date;
}

abstract interface class EventRepository {
  Future<List<CalendarEvent>> list();
  Future<void> save(CalendarEvent event);
  Future<void> delete(String id);
}
