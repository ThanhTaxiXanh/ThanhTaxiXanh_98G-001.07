import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Taxi Auto')),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Khung ứng dụng đã sẵn sàng.\n'
              'Bản đồ, lịch, VietQR và media đang chờ triển khai.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
