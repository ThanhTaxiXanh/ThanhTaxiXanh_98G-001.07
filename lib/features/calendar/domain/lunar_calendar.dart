import 'dart:math';

class LunarDate {
  const LunarDate(this.day, this.month, this.year, {this.leap = false});

  final int day;
  final int month;
  final int year;
  final bool leap;
}

/// Port of the supplied Kotlin algorithm, attributed there to Ho Ngoc Duc.
/// Civil dates use Vietnam's UTC+7 calendar, independent of the device timezone.
/// The supported Gregorian interval is 1900-01-01 through 2099-12-31.
class LunarCalendar {
  static const _rad = pi / 180;
  static const _epoch = 2415021.076998695;
  static const _synodic = 29.530588853;
  static const _tz = 7.0;
  static const _can = [
    'Giáp',
    'Ất',
    'Bính',
    'Đinh',
    'Mậu',
    'Kỷ',
    'Canh',
    'Tân',
    'Nhâm',
    'Quý',
  ];
  static const _chi = [
    'Tý',
    'Sửu',
    'Dần',
    'Mão',
    'Thìn',
    'Tỵ',
    'Ngọ',
    'Mùi',
    'Thân',
    'Dậu',
    'Tuất',
    'Hợi',
  ];
  final _moonCache = <int, int>{};

  String canChi(int year) =>
      '${_can[(year + 6) % 10]} ${_chi[(year + 8) % 12]}';

  LunarDate forInstant(DateTime instant) {
    final civil = instant.toUtc().add(const Duration(hours: 7));
    return solarToLunar(civil.day, civil.month, civil.year);
  }

  LunarDate solarToLunar(int day, int month, int year) {
    final date = DateTime.utc(year, month, day);
    if (year < 1900 ||
        year > 2099 ||
        date.year != year ||
        date.month != month ||
        date.day != day) {
      throw ArgumentError('Expected a valid Gregorian date in 1900–2099.');
    }
    final dayNumber = _jdFromDate(day, month, year);
    var k = ((dayNumber - _epoch) / _synodic).floor();
    // The mean-lunation estimate can itself start after the requested date
    // (e.g. 2054-05-07). Bracket the actual local new moon to avoid lunar day 0.
    while (_newMoonDay(k) > dayNumber) {
      k--;
    }
    while (_newMoonDay(k + 1) <= dayNumber) {
      k++;
    }
    final monthStart = _newMoonDay(k);
    var a11 = _lunarMonth11(year);
    var b11 = a11;
    int lunarYear;
    if (a11 >= monthStart) {
      lunarYear = year;
      a11 = _lunarMonth11(year - 1);
    } else {
      lunarYear = year + 1;
      b11 = _lunarMonth11(year + 1);
    }
    final lunarDay = dayNumber - monthStart + 1;
    final diff = (monthStart - a11) ~/ 29;
    var lunarMonth = diff + 11;
    var leap = false;
    if (b11 - a11 > 365) {
      final leapDiff = _leapMonthOffset(a11);
      if (diff >= leapDiff) {
        lunarMonth = diff + 10;
        leap = diff == leapDiff;
      }
    }
    if (lunarMonth > 12) lunarMonth -= 12;
    if (lunarMonth >= 11 && diff < 4) lunarYear--;
    return LunarDate(lunarDay, lunarMonth, lunarYear, leap: leap);
  }

  /// Returns a UTC date carrying civil year/month/day, or null for invalid input.
  DateTime? lunarToSolar(LunarDate lunar) {
    if (lunar.day < 1 ||
        lunar.day > 30 ||
        lunar.month < 1 ||
        lunar.month > 12 ||
        lunar.year < 1899 ||
        lunar.year > 2099) {
      return null;
    }
    final a11 = _lunarMonth11(lunar.month < 11 ? lunar.year - 1 : lunar.year);
    final b11 = _lunarMonth11(lunar.month < 11 ? lunar.year : lunar.year + 1);
    final k = (0.5 + (a11 - _epoch) / _synodic).floor();
    var off = lunar.month - 11;
    if (off < 0) off += 12;
    if (b11 - a11 > 365) {
      final leapOff = _leapMonthOffset(a11);
      var leapMonth = leapOff - 2;
      if (leapMonth < 0) leapMonth += 12;
      if (lunar.leap && lunar.month != leapMonth) return null;
      if (lunar.leap || off >= leapOff) off++;
    } else if (lunar.leap) {
      return null;
    }
    final date = _jdToDate(_newMoonDay(k + off) + lunar.day - 1);
    if (date.year < 1900 || date.year > 2099) return null;
    // The source accepted day 30 in 29-day months. Round-tripping rejects it.
    final check = solarToLunar(date.day, date.month, date.year);
    if (check.day != lunar.day ||
        check.month != lunar.month ||
        check.year != lunar.year ||
        check.leap != lunar.leap) {
      return null;
    }
    return date;
  }

  int _jdFromDate(int day, int month, int year) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }

  DateTime _jdToDate(int jd) {
    final a = jd + 32044;
    final b = (4 * a + 3) ~/ 146097;
    final c = a - b * 146097 ~/ 4;
    final d = (4 * c + 3) ~/ 1461;
    final e = c - 1461 * d ~/ 4;
    final m = (5 * e + 2) ~/ 153;
    return DateTime.utc(
      b * 100 + d - 4800 + m ~/ 10,
      m + 3 - 12 * (m ~/ 10),
      e - (153 * m + 2) ~/ 5 + 1,
    );
  }

  double _newMoon(int k) {
    final t = k / 1236.85;
    final t2 = t * t;
    final t3 = t2 * t;
    var jd1 =
        2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jd1 += 0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * _rad);
    final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    var c1 = (0.1734 - 0.000393 * t) * sin(m * _rad);
    c1 += 0.0021 * sin(2 * m * _rad);
    c1 -= 0.4068 * sin(mpr * _rad);
    c1 += 0.0161 * sin(2 * mpr * _rad);
    c1 -= 0.0004 * sin(3 * mpr * _rad);
    c1 += 0.0104 * sin(2 * f * _rad);
    c1 -= 0.0051 * sin((m + mpr) * _rad);
    c1 -= 0.0074 * sin((m - mpr) * _rad);
    c1 += 0.0004 * sin((2 * f + m) * _rad);
    c1 -= 0.0004 * sin((2 * f - m) * _rad);
    c1 -= 0.0006 * sin((2 * f + mpr) * _rad);
    c1 += 0.0010 * sin((2 * f - mpr) * _rad);
    c1 += 0.0005 * sin((2 * mpr + m) * _rad);
    final deltaT = t < -11
        ? 0.001 +
              0.000839 * t +
              0.0002261 * t2 -
              0.00000845 * t3 -
              0.000000081 * t * t3
        : -0.000278 + 0.000265 * t + 0.000262 * t2;
    return jd1 + c1 - deltaT;
  }

  int _newMoonDay(int k) => _moonCache.putIfAbsent(
    k,
    () => (_newMoon(k) + 0.5 + _tz / 24 + 1e-12).floor(),
  );

  double _sunLongitude(double jdn) {
    final t = (jdn - 2451545.0) / 36525;
    final t2 = t * t;
    final m =
        357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
    final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    final dl =
        (1.914600 - 0.004817 * t - 0.000014 * t2) * sin(m * _rad) +
        (0.019993 - 0.000101 * t) * sin(2 * m * _rad) +
        0.000290 * sin(3 * m * _rad);
    final l = (l0 + dl) * _rad;
    return l - 2 * pi * (l / (2 * pi)).floor();
  }

  int _sunIndex(int jdn) =>
      (_sunLongitude(jdn - 0.5 - _tz / 24) / pi * 6 + 1e-12).floor();

  int _lunarMonth11(int year) {
    final k = ((_jdFromDate(31, 12, year) - _epoch) / _synodic).floor();
    final nm = _newMoonDay(k);
    return _sunIndex(nm) >= 9 ? _newMoonDay(k - 1) : nm;
  }

  int _leapMonthOffset(int a11) {
    final k = ((a11 - _epoch) / _synodic + 0.5).floor();
    var i = 1;
    var arc = _sunIndex(_newMoonDay(k + i));
    while (i < 15) {
      final next = _sunIndex(_newMoonDay(k + i + 1));
      if (next == arc) break;
      arc = next;
      i++;
    }
    return i;
  }
}
