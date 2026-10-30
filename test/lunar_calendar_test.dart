import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_auto/features/calendar/domain/lunar_calendar.dart';

void main() {
  late LunarCalendar calendar;
  setUp(() => calendar = LunarCalendar());

  test('known Vietnamese Tet dates and leap-month boundaries', () {
    final cases = [
      (DateTime.utc(2000, 2, 5), const LunarDate(1, 1, 2000)),
      (DateTime.utc(2023, 1, 22), const LunarDate(1, 1, 2023)),
      (DateTime.utc(2024, 2, 10), const LunarDate(1, 1, 2024)),
      (DateTime.utc(2025, 1, 29), const LunarDate(1, 1, 2025)),
      (DateTime.utc(2026, 2, 17), const LunarDate(1, 1, 2026)),
      (DateTime.utc(2020, 5, 23), const LunarDate(1, 4, 2020, leap: true)),
      (DateTime.utc(2023, 3, 22), const LunarDate(1, 2, 2023, leap: true)),
      (DateTime.utc(2023, 4, 20), const LunarDate(1, 3, 2023)),
      (DateTime.utc(2054, 5, 7), const LunarDate(30, 3, 2054)),
    ];
    for (final (solar, expected) in cases) {
      final result = calendar.solarToLunar(solar.day, solar.month, solar.year);
      expect(
        (result.day, result.month, result.year, result.leap),
        (expected.day, expected.month, expected.year, expected.leap),
        reason: solar.toIso8601String(),
      );
      expect(calendar.lunarToSolar(expected), solar);
    }
  });

  test(
    'UTC+7 midnight changes the lunar year regardless of device timezone',
    () {
      final before = calendar.forInstant(
        DateTime.parse('2024-02-09T16:59:59Z'),
      );
      final after = calendar.forInstant(DateTime.parse('2024-02-09T17:00:00Z'));
      expect((before.day, before.month, before.year), (30, 12, 2023));
      expect((after.day, after.month, after.year), (1, 1, 2024));
      expect(calendar.canChi(2026), 'Bính Ngọ');
    },
  );

  test('rejects nonexistent dates and invalid leap-month flags', () {
    expect(() => calendar.solarToLunar(31, 2, 2026), throwsArgumentError);
    expect(() => calendar.solarToLunar(1, 1, 1899), throwsArgumentError);
    expect(() => calendar.solarToLunar(1, 1, 2100), throwsArgumentError);
    for (final lunar in [
      const LunarDate(0, 1, 2024),
      const LunarDate(31, 1, 2024),
      const LunarDate(1, 13, 2024),
      const LunarDate(1, 1, 2024, leap: true),
      const LunarDate(1, 3, 2023, leap: true),
      const LunarDate(30, 1, 2024),
    ]) {
      expect(calendar.lunarToSolar(lunar), isNull);
    }
  });

  test('every Gregorian day in the supported range round-trips', () {
    final end = DateTime.utc(2100);
    for (
      var date = DateTime.utc(1900);
      date.isBefore(end);
      date = date.add(const Duration(days: 1))
    ) {
      final lunar = calendar.solarToLunar(date.day, date.month, date.year);
      expect(
        calendar.lunarToSolar(lunar),
        date,
        reason: date.toIso8601String(),
      );
    }
  });
}
