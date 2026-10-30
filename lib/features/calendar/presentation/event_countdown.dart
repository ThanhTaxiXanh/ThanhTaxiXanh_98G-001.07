import 'package:flutter/material.dart';

import '../domain/calendar_event.dart';
import '../domain/lunar_calendar.dart';

class EventCountdown extends StatelessWidget {
  const EventCountdown({
    required this.occurrence,
    required this.today,
    required this.calendar,
    super.key,
  });

  final EventOccurrence occurrence;
  final DateTime today;
  final LunarCalendar calendar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        occurrence.countdown(today),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(occurrence.solarLabel),
          Text(occurrence.lunarLabel(calendar)),
        ],
      ),
    ],
  );
}
