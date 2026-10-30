import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/presentation/calendar_providers.dart';
import '../../calendar/presentation/upcoming_events_card.dart';
import '../../payment/presentation/payment_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.watch(calendarClockProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh Taxi Xanh')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Lịch Việt Nam',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            clock.when(
              loading: () => const Text('Đang cập nhật lịch…'),
              error: (_, _) => const Text('Không thể cập nhật ngày hiện tại.'),
              data: (instant) {
                final civil = instant.add(const Duration(hours: 7));
                final calendar = ref.watch(lunarCalendarProvider);
                final lunar = calendar.forInstant(instant);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${civil.day}/${civil.month}/${civil.year}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Âm lịch: ${lunar.day}/${lunar.month}'
                          '${lunar.leap ? " nhuận" : ""} • ${calendar.canChi(lunar.year)}',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const UpcomingEventsCard(),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 64)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PaymentScreen()),
              ),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Tạo mã VietQR'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bản đồ 3D, media và giao diện Android Auto đang chờ triển khai.',
            ),
          ],
        ),
      ),
    );
  }
}
