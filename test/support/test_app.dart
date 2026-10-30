import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taxi_auto/app/app.dart';
import 'package:taxi_auto/features/calendar/domain/calendar_event.dart';
import 'package:taxi_auto/features/calendar/presentation/calendar_providers.dart';
import 'package:taxi_auto/features/calendar/presentation/event_providers.dart';
import 'package:taxi_auto/features/payment/domain/bank.dart';
import 'package:taxi_auto/features/map/presentation/native_map_surface.dart';
import 'package:taxi_auto/features/payment/domain/recipient_account.dart';
import 'package:taxi_auto/features/payment/presentation/payment_providers.dart';

class MemoryRecipients implements RecipientRepository {
  MemoryRecipients([Iterable<RecipientAccount> initial = const []]) {
    for (final account in initial) {
      records[account.id] = account;
    }
  }
  final records = <String, RecipientAccount>{};
  String? defaultId;
  @override
  Future<List<RecipientAccount>> list() async {
    final accounts = records.values.toList();
    accounts.sort((a, b) {
      if (a.id == defaultId) return -1;
      if (b.id == defaultId) return 1;
      return a.id.compareTo(b.id);
    });
    return accounts;
  }

  @override
  Future<void> save(RecipientAccount account) async {
    records[account.id] = account;
  }

  @override
  Future<void> setDefault(String id) async {
    defaultId = id;
  }

  @override
  Future<void> delete(String id) async {
    records.remove(id);
  }
}

class MemoryEvents implements EventRepository {
  MemoryEvents([Iterable<CalendarEvent> initial = const []]) {
    for (final event in initial) {
      records[event.id] = event;
    }
  }
  final records = <String, CalendarEvent>{};
  @override
  Future<List<CalendarEvent>> list() async => records.values.toList();
  @override
  Future<void> save(CalendarEvent event) async {
    records[event.id] = event;
  }

  @override
  Future<void> delete(String id) async {
    records.remove(id);
  }
}

class OfflineBanks implements BankRepository {
  static final catalog = BankCatalog(const [
    Bank(
      bin: '970422',
      name: 'Ngân hàng Quân đội',
      shortName: 'MBBank',
      code: 'MB',
    ),
    Bank(
      bin: '970436',
      name: 'Ngân hàng Ngoại thương',
      shortName: 'Vietcombank',
      code: 'VCB',
    ),
  ], DateTime.utc(2026, 10, 30));
  @override
  Future<BankCatalog> load() async => catalog;
  @override
  Future<BankCatalog> refresh() async => throw StateError('Offline');
}

Widget testApp({
  Widget? home,
  MemoryRecipients? recipients,
  MemoryEvents? events,
  DateTime? instant,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      mapSurfaceBuilderProvider.overrideWithValue(
        (_) => const ColoredBox(
          key: Key('test-map-surface'),
          color: Color(0xffe8eff3),
        ),
      ),
      recipientRepositoryProvider.overrideWith(
        (ref) async => recipients ?? MemoryRecipients(),
      ),
      bankRepositoryProvider.overrideWith((ref) async => OfflineBanks()),
      eventRepositoryProvider.overrideWith(
        (ref) async => events ?? MemoryEvents(),
      ),
      calendarClockProvider.overrideWith(
        (ref) => Stream.value(instant ?? DateTime.utc(2026, 10, 30, 5)),
      ),
    ],
    child: home == null ? const TaxiAutoApp() : MaterialApp(home: home),
  );
}
