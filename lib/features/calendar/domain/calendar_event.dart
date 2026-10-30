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
    this.monthly = false,
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
  final bool monthly;

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
        (monthly && (yearly || leap)) ||
        (calendar == EventCalendar.solar && leap) ||
        _dateForYear(year, lunar) == null) {
      throw ArgumentError('Invalid event or calendar date.');
    }
  }

  /// Civil Gregorian day for the next occurrence; never shifts invalid dates.
  /// Feb 29 and lunar leap months recur only in years containing that date.
  DateTime? nextOnOrAfter(DateTime today, LunarCalendar lunar) {
    final start = DateTime.utc(today.year, today.month, today.day);
    if (monthly) {
      final first = _dateForYear(year, lunar);
      if (first == null) return null;
      var candidate = first.isAfter(start) ? first : start;
      final end = candidate.add(const Duration(days: 366));
      while (candidate.isBefore(end) && candidate.year <= 2099) {
        final candidateDay = calendar == EventCalendar.solar
            ? candidate.day
            : lunar
                  .solarToLunar(candidate.day, candidate.month, candidate.year)
                  .day;
        if (candidateDay == day) return candidate;
        candidate = candidate.add(const Duration(days: 1));
      }
      return null;
    }
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
      '${monthly ? 'ngày $day · Hằng tháng' : '$day/$month${leap ? ' nhuận' : ''}${yearly ? ' · Hằng năm' : '/$year'}'}';
}

class EventOccurrence {
  const EventOccurrence(this.event, this.date);
  final CalendarEvent event;
  final DateTime date;

  int daysUntil(DateTime today) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

  String countdown(DateTime today) {
    final days = daysUntil(today);
    return days == 0
        ? 'Hôm nay'
        : days == 1
        ? 'Còn 1 ngày'
        : 'Còn $days ngày';
  }

  String get solarLabel =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  String lunarLabel(LunarCalendar calendar) {
    final lunar = calendar.solarToLunar(date.day, date.month, date.year);
    return '${lunar.day}/${lunar.month}${lunar.leap ? ' nhuận' : ''} (Âm lịch)';
  }

  String title(LunarCalendar calendar) {
    if (event.monthly &&
        event.calendar == EventCalendar.lunar &&
        ((event.id == 'default-lunar-first' && event.title == 'Ngày mùng 1') ||
            (event.id == 'default-lunar-full' && event.title == 'Ngày rằm'))) {
      final lunar = calendar.solarToLunar(date.day, date.month, date.year);
      return '${event.title} tháng ${lunar.month}${lunar.leap ? ' nhuận' : ''}';
    }
    return event.title;
  }
}

abstract interface class EventRepository {
  Future<List<CalendarEvent>> list();
  Future<void> save(CalendarEvent event);
  Future<void> delete(String id);
}
