import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_auto/core/car/car_bridge.dart';
import 'package:taxi_auto/features/calendar/domain/calendar_event.dart';
import 'package:taxi_auto/features/calendar/presentation/calendar_providers.dart';
import 'package:taxi_auto/features/calendar/presentation/event_providers.dart';
import 'package:taxi_auto/features/map/presentation/map_providers.dart';
import 'package:taxi_auto/features/media/presentation/youtube_providers.dart';
import 'package:taxi_auto/features/media/presentation/youtube_session.dart';
import 'package:taxi_auto/features/payment/domain/recipient_account.dart';
import 'package:taxi_auto/features/payment/presentation/payment_preview.dart';
import 'package:taxi_auto/features/payment/presentation/payment_providers.dart';
import 'support/test_app.dart';
import 'support/map_fakes.dart';
import 'support/media_fakes.dart';

const account = RecipientAccount(
  id: 'a',
  bankBin: '970422',
  bankName: 'MBBank',
  accountNumber: '000123456789',
  accountHolder: 'NGUYEN VAN A',
  defaultNote: 'Taxi test',
  isDefault: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late MemoryRecipients recipients;
  late FakeLocationService location;
  late FakePipController pip;
  late CarBridge bridge;
  setUp(() async {
    recipients = MemoryRecipients([account]);
    location = FakeLocationService();
    pip = FakePipController();
    container = ProviderContainer(
      overrides: [
        pipControllerProvider.overrideWithValue(pip),
        youTubeSettingsRepositoryProvider.overrideWithValue(
          MemoryYouTubeSettings(),
        ),
        youTubeHistoryRepositoryProvider.overrideWithValue(
          MemoryYouTubeHistory(),
        ),
        mapRepositoryProvider.overrideWithValue(FakeMapRepository()),
        locationServiceProvider.overrideWithValue(location),
        recipientRepositoryProvider.overrideWith((ref) async => recipients),
        eventRepositoryProvider.overrideWith(
          (ref) async => MemoryEvents([
            const CalendarEvent(
              id: 'default-lunar-first',
              title: 'Ngày mùng 1',
              day: 1,
              month: 1,
              year: 1900,
              calendar: EventCalendar.lunar,
              monthly: true,
            ),
          ]),
        ),
        calendarClockProvider.overrideWith(
          (ref) => Stream.value(DateTime.utc(2026, 10, 29, 2)),
        ),
      ],
    );
    bridge = CarBridge(container);
    container.listen(calendarClockProvider, (_, _) {});
    await container.read(recipientsProvider.future);
    await container.read(eventsProvider.future);
    await container.read(calendarClockProvider.future);
  });
  tearDown(() {
    bridge.dispose();
    container.dispose();
    location.positions.close();
    pip.dispose();
  });

  test(
    'car snapshot carries Vietnam dates, countdowns and a real QR matrix',
    () {
      final snapshot = bridge.buildSnapshot();
      expect(snapshot['calendarTitle'], '29/10/2026');
      final events = snapshot['events'] as List;
      expect((events.single as Map)['detail'], contains('Còn 11 ngày'));
      expect((events.single as Map)['detail'], contains('09/11/2026'));
      final payment = snapshot['payment'] as Map;
      expect(payment['account'], '000123456789');
      final matrix = payment['matrix'] as List<String>;
      expect(matrix.length, greaterThanOrEqualTo(21));
      expect(matrix.every((row) => row.length == matrix.length), isTrue);
      expect(matrix.every((row) => RegExp(r'^[01]+$').hasMatch(row)), isTrue);
    },
  );

  test(
    'editing and changed bank details hide the previous request on the car',
    () async {
      final preview = container.read(paymentPreviewProvider.notifier);
      preview.update(
        PaymentPreview(
          account: account,
          payment: account.payment(amount: '25000'),
        ),
      );
      expect((bridge.buildSnapshot()['payment'] as Map)['amount'], '25000');
      preview.update(const PaymentPreview(account: account, editing: true));
      expect((bridge.buildSnapshot()['payment'] as Map)['matrix'], isNull);
      preview.update(
        PaymentPreview(
          account: account,
          payment: account.payment(amount: '25000'),
        ),
      );
      recipients.records['a'] = const RecipientAccount(
        id: 'a',
        bankBin: '970436',
        bankName: 'Vietcombank',
        accountNumber: '000987654321',
        accountHolder: 'NGUYEN VAN A',
      );
      container.invalidate(recipientsProvider);
      await container.read(recipientsProvider.future);
      final payment = bridge.buildSnapshot()['payment'] as Map;
      expect(payment['matrix'], isNull);
      expect(payment['message'], contains('đã thay đổi'));
    },
  );

  test(
    'car connection does not start GPS until requested and disconnect stops navigation GPS',
    () async {
      await bridge.action({'type': 'connect'});
      expect(location.permissions, 0);
      await bridge.action({'type': 'gps'});
      expect(location.backgroundRequested, isTrue);
      location.sendFix();
      expect(container.read(mapSessionProvider).carNavigationActive, isTrue);
      expect((bridge.buildSnapshot()['map'] as Map)['gpsActive'], isTrue);
      await bridge.action({'type': 'disconnect'});
      expect(container.read(mapSessionProvider).gpsActive, isFalse);
      expect(container.read(mapSessionProvider).carNavigationActive, isFalse);
      expect(container.read(mapSessionProvider).fix, isNull);
    },
  );
}
