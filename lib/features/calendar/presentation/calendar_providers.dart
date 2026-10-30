import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/lunar_calendar.dart';

final lunarCalendarProvider = Provider((ref) => LunarCalendar());

final calendarClockProvider = StreamProvider.autoDispose<DateTime>((
  ref,
) async* {
  yield DateTime.now().toUtc();
  yield* Stream.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now().toUtc(),
  );
});
