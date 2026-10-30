import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_auto/core/storage/app_database.dart';
import 'package:taxi_auto/features/calendar/data/sqlite_event_repository.dart';
import 'package:taxi_auto/features/calendar/domain/calendar_event.dart';
import 'package:taxi_auto/features/calendar/domain/lunar_calendar.dart';
import 'package:taxi_auto/features/payment/data/sqlite_bank_repository.dart';
import 'package:taxi_auto/features/payment/data/sqlite_recipient_repository.dart';
import 'package:taxi_auto/features/payment/domain/recipient_account.dart';

void main() {
  late Directory directory;
  late Database db;
  late String location;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('taxi-storage-test-');
    location = '${directory.path}/app.db';
    db = await openAppDatabase(
      factory: databaseFactoryFfi,
      databasePath: location,
    );
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> reopen() async {
    await db.close();
    db = await openAppDatabase(
      factory: databaseFactoryFfi,
      databasePath: location,
    );
  }

  RecipientAccount account(
    String id,
    String number, {
    bool isDefault = false,
  }) => RecipientAccount(
    id: id,
    bankBin: '970422',
    bankName: 'MBBank',
    accountNumber: number,
    accountHolder: 'LE THANH',
    defaultNote: 'Thanh Taxi Xanh',
    isDefault: isDefault,
    footerLogo: Uint8List.fromList([1, 2, 3]),
    centerLogo: Uint8List.fromList([4, 5]),
  );

  test(
    'recipients, logos and a single default survive database reopen',
    () async {
      var repo = SqliteRecipientRepository(db);
      await repo.save(account('a', '001234'));
      await repo.save(account('b', '009876'));
      expect((await repo.list()).where((a) => a.isDefault).single.id, 'a');
      await repo.setDefault('b');
      await reopen();
      repo = SqliteRecipientRepository(db);
      final loaded = await repo.list();
      expect(loaded.first.id, 'b');
      expect(loaded.where((a) => a.isDefault).length, 1);
      expect(loaded.first.accountNumber, '009876');
      expect(loaded.first.defaultNote, 'Thanh Taxi Xanh');
      expect(loaded.first.footerLogo, [1, 2, 3]);
      expect(loaded.first.centerLogo, [4, 5]);
      await repo.save(account('b', '001111', isDefault: true));
      expect((await repo.list()).first.accountNumber, '001111');
      await repo.delete('b');
      expect((await repo.list()).single.isDefault, isTrue);
      await repo.delete('a');
      expect(await repo.list(), isEmpty);
    },
  );

  test(
    'duplicate or failed default changes keep existing recipient data',
    () async {
      final repo = SqliteRecipientRepository(db);
      await repo.save(account('a', '001234'));
      await expectLater(
        repo.save(account('b', ' 001 234 ', isDefault: true)),
        throwsA(isA<DuplicateRecipientException>()),
      );
      await expectLater(repo.setDefault('missing'), throwsArgumentError);
      final loaded = await repo.list();
      expect(loaded.single.id, 'a');
      expect(loaded.single.isDefault, isTrue);
      await repo.save(account('b', '009876'));
      await Future.wait([repo.setDefault('a'), repo.setDefault('b')]);
      expect((await repo.list()).where((a) => a.isDefault).length, 1);
    },
  );

  test(
    'bundled banks work on first offline launch and persist after reopen',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        throw const SocketException('offline');
      });
      addTearDown(client.close);
      var repo = SqliteBankRepository(
        db,
        client,
        () => File('assets/data/vietqr_banks.json').readAsString(),
      );
      final catalog = await repo.load();
      expect(catalog.banks.length, greaterThan(50));
      expect(catalog.banks.firstWhere((b) => b.code == 'MB').bin, '970422');
      expect(requests, 0);
      await expectLater(repo.refresh(), throwsA(isA<SocketException>()));
      await reopen();
      repo = SqliteBankRepository(
        db,
        client,
        () async => throw StateError('Cache should be used.'),
      );
      final cached = await repo.load();
      expect(cached.banks.length, catalog.banks.length);
      expect(cached.updatedAt, catalog.updatedAt);
    },
  );

  test(
    'bank refresh validates a full response before replacing the offline cache',
    () async {
      final seed = await File('assets/data/vietqr_banks.json').readAsString();
      var body = jsonEncode({'code': '00', 'data': []});
      final client = MockClient((request) async {
        expect(request.url, SqliteBankRepository.endpoint);
        expect(request.method, 'GET');
        expect(request.body, isEmpty);
        return http.Response(
          body,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      final repo = SqliteBankRepository(db, client, () async => seed);
      final original = await repo.load();
      await expectLater(repo.refresh(), throwsFormatException);
      expect((await repo.load()).banks.length, original.banks.length);
      body = jsonEncode({
        'code': '00',
        'data': [
          {
            'bin': '970422',
            'name': 'Ngân hàng cập nhật',
            'shortName': 'MB Updated',
            'code': 'MB',
          },
        ],
      });
      final updated = await repo.refresh();
      expect(updated.banks.single.name, 'Ngân hàng cập nhật');
      await reopen();
      final cacheOnly = SqliteBankRepository(
        db,
        client,
        () async => throw StateError('No seed'),
      );
      expect((await cacheOnly.load()).banks.single.shortName, 'MB Updated');
    },
  );

  test(
    'event create, edit, reload and delete preserve calendar semantics',
    () async {
      var repo = SqliteEventRepository(db, LunarCalendar());
      const initial = CalendarEvent(
        id: 'event',
        title: 'Giỗ',
        notes: 'Ghi chú',
        day: 1,
        month: 2,
        year: 2023,
        leap: true,
        yearly: true,
        calendar: EventCalendar.lunar,
      );
      await repo.save(initial);
      await reopen();
      repo = SqliteEventRepository(db, LunarCalendar());
      var loaded = (await repo.list()).single;
      expect(
        (loaded.calendar, loaded.leap, loaded.yearly),
        (EventCalendar.lunar, true, true),
      );
      expect(loaded.notes, 'Ghi chú');
      await repo.save(
        const CalendarEvent(
          id: 'event',
          title: 'Lịch hẹn mới',
          day: 30,
          month: 10,
          year: 2026,
        ),
      );
      loaded = (await repo.list()).single;
      expect(loaded.title, 'Lịch hẹn mới');
      expect(loaded.calendar, EventCalendar.solar);
      await expectLater(
        repo.save(
          const CalendarEvent(
            id: 'bad',
            title: 'Sai',
            day: 31,
            month: 2,
            year: 2026,
          ),
        ),
        throwsArgumentError,
      );
      expect((await repo.list()).length, 1);
      await repo.delete('event');
      expect(await repo.list(), isEmpty);
    },
  );
}
