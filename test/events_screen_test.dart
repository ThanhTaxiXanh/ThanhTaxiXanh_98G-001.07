import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_auto/features/calendar/domain/calendar_event.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('events can be created, edited, seen on dashboard and deleted', (
    tester,
  ) async {
    final events = MemoryEvents();
    await tester.pumpWidget(testApp(events: events));
    await tester.pumpAndSettle();
    final manage = find.byKey(const Key('manage-events'));
    await tester.ensureVisible(manage);
    await tester.tap(manage);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-event')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('event-title')),
      'Hẹn bảo dưỡng',
    );
    final save = find.byKey(const Key('save-event'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(events.records.values.single.title, 'Hẹn bảo dưỡng');
    expect(find.text('Hẹn bảo dưỡng'), findsOneWidget);
    await tester.tap(find.text('Hẹn bảo dưỡng'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('event-title')), 'Hẹn mới');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(events.records.values.single.title, 'Hẹn mới');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Hẹn mới'), findsOneWidget);
    expect(find.textContaining('Hôm nay'), findsOneWidget);
    await tester.ensureVisible(manage);
    await tester.tap(manage);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('event-menu-${events.records.keys.single}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(events.records, isEmpty);
    expect(find.textContaining('Chưa có sự kiện.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dashboard includes lunar annual events on the Vietnam civil day',
    (tester) async {
      final events = MemoryEvents([
        const CalendarEvent(
          id: 'tet',
          title: 'Tết gia đình',
          day: 1,
          month: 1,
          year: 2023,
          calendar: EventCalendar.lunar,
          yearly: true,
        ),
      ]);
      await tester.pumpWidget(
        testApp(events: events, instant: DateTime.utc(2026, 2, 16, 17)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tết gia đình'), findsOneWidget);
      expect(find.textContaining('Hôm nay'), findsOneWidget);
      expect(find.textContaining('Âm lịch 1/1'), findsOneWidget);
    },
  );
}
