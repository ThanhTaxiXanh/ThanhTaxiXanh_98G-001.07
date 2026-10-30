import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_auto/features/calendar/domain/calendar_event.dart';
import 'package:taxi_auto/features/calendar/domain/lunar_calendar.dart';

void main() {
  final lunar = LunarCalendar();

  test('one-off events include today and exclude past dates', () {
    const event = CalendarEvent(
      id: 'one',
      title: 'Lịch hẹn',
      day: 30,
      month: 10,
      year: 2026,
    );
    event.validate(lunar);
    expect(
      event.nextOnOrAfter(DateTime.utc(2026, 10, 30), lunar),
      DateTime.utc(2026, 10, 30),
    );
    expect(event.nextOnOrAfter(DateTime.utc(2026, 10, 31), lunar), isNull);
  });

  test(
    'solar yearly recurrence skips invalid dates and respects its start year',
    () {
      const leap = CalendarEvent(
        id: 'leap',
        title: '29/2',
        day: 29,
        month: 2,
        year: 2024,
        yearly: true,
      );
      leap.validate(lunar);
      expect(
        leap.nextOnOrAfter(DateTime.utc(2026), lunar),
        DateTime.utc(2028, 2, 29),
      );
      const future = CalendarEvent(
        id: 'future',
        title: 'Năm tới',
        day: 1,
        month: 1,
        year: 2027,
        yearly: true,
      );
      expect(
        future.nextOnOrAfter(DateTime.utc(2026), lunar),
        DateTime.utc(2027),
      );
    },
  );

  test(
    'lunar yearly recurrence resolves Tet and skips missing leap months',
    () {
      const tet = CalendarEvent(
        id: 'tet',
        title: 'Tết',
        day: 1,
        month: 1,
        year: 2023,
        calendar: EventCalendar.lunar,
        yearly: true,
      );
      tet.validate(lunar);
      expect(
        tet.nextOnOrAfter(DateTime.utc(2026), lunar),
        DateTime.utc(2026, 2, 17),
      );
      const leap = CalendarEvent(
        id: 'leap',
        title: 'Ngày tháng nhuận',
        day: 1,
        month: 2,
        year: 2023,
        calendar: EventCalendar.lunar,
        leap: true,
        yearly: true,
      );
      leap.validate(lunar);
      expect(
        leap.nextOnOrAfter(DateTime.utc(2023, 3), lunar),
        DateTime.utc(2023, 3, 22),
      );
      final next = leap.nextOnOrAfter(DateTime.utc(2024), lunar)!;
      expect(next.year, greaterThan(2024));
      final converted = lunar.solarToLunar(next.day, next.month, next.year);
      expect((converted.day, converted.month, converted.leap), (1, 2, true));
    },
  );

  test('events reject impossible Gregorian and lunar dates', () {
    for (final event in [
      const CalendarEvent(
        id: 'bad',
        title: 'Sai',
        day: 30,
        month: 2,
        year: 2026,
      ),
      const CalendarEvent(
        id: 'bad',
        title: 'Sai',
        day: 1,
        month: 1,
        year: 2026,
        leap: true,
      ),
      const CalendarEvent(
        id: 'bad',
        title: 'Sai',
        day: 30,
        month: 1,
        year: 2024,
        calendar: EventCalendar.lunar,
      ),
      const CalendarEvent(id: 'bad', title: ' ', day: 1, month: 1, year: 2026),
    ]) {
      expect(() => event.validate(lunar), throwsArgumentError);
    }
  });
}
