import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../calendar/presentation/events_screen.dart';
import '../../payment/presentation/payment_screen.dart';
import 'layout_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(layoutSettingsProvider);
    Future<void> save(DashboardLayout next) async {
      try {
        await ref.read(layoutSettingsProvider.notifier).save(next);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chưa lưu được bố cục. Thử lại.')),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Bố cục màn hình khách',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Bản đồ bên trái 60% • Bảng bên phải 40%. Tỷ lệ ba hàng bên phải được lưu trên máy và đồng bộ sang màn hình khách.',
          ),
          const SizedBox(height: 16),
          layout.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(layoutSettingsProvider),
              child: const Text('Tải lại bố cục'),
            ),
            data: (value) => Column(
              children: [
                Text(
                  'Lịch ${value.calendar}% · QR ${value.payment}% · Media ${value.media}%',
                ),
                for (final option in <(String, DashboardLayout)>[
                  ('QR lớn', DashboardLayout.qr),
                  ('Ba hàng cân đối', DashboardLayout.balanced),
                  ('Ưu tiên sự kiện', DashboardLayout.events),
                ])
                  ListTile(
                    title: Text(option.$1),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => save(option.$2),
                  ),
                ListTile(
                  title: const Text('Tùy chỉnh tỷ lệ hàng'),
                  leading: const Icon(Icons.tune),
                  onTap: () async {
                    final next = await editLayout(context, value);
                    if (next != null) await save(next);
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Quản lý tài khoản & VietQR'),
            leading: const Icon(Icons.qr_code),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PaymentScreen()),
            ),
          ),
          ListTile(
            title: const Text('Quản lý sự kiện'),
            leading: const Icon(Icons.event),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EventsScreen()),
            ),
          ),
          const LicensePageButton(),
        ],
      ),
    );
  }
}

Future<DashboardLayout?> editLayout(
  BuildContext context,
  DashboardLayout value,
) async {
  final inputs = [
    value.calendar,
    value.payment,
    value.media,
  ].map((n) => TextEditingController(text: '$n')).toList();
  String? error;
  try {
    return await showDialog<DashboardLayout>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Tỷ lệ ba hàng'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tổng 100%, mỗi hàng từ 15–70%.'),
                for (var index = 0; index < 3; index++)
                  TextField(
                    controller: inputs[index],
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    decoration: InputDecoration(
                      labelText: ['Lịch (%)', 'QR (%)', 'Media (%)'][index],
                    ),
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final weights = inputs
                      .map((c) => int.tryParse(c.text) ?? 0)
                      .toList();
                  Navigator.of(
                    context,
                  ).pop(DashboardLayout(weights[0], weights[1], weights[2]));
                } on ArgumentError {
                  update(
                    () => error = 'Kiểm tra tổng 100% và giới hạn từng hàng.',
                  );
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  } finally {
    for (final input in inputs) {
      input.dispose();
    }
  }
}

class LicensePageButton extends StatelessWidget {
  const LicensePageButton({super.key});
  @override
  Widget build(BuildContext context) => ListTile(
    title: const Text('Giấy phép phần mềm nguồn mở'),
    leading: const Icon(Icons.info_outline),
    onTap: () =>
        showLicensePage(context: context, applicationName: 'Thanh Taxi Xanh'),
  );
}
