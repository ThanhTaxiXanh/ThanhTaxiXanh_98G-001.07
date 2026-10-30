import 'package:flutter/material.dart';

import '../features/dashboard/presentation/dashboard_screen.dart';

class TaxiAutoApp extends StatelessWidget {
  const TaxiAutoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taxi Auto',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const DashboardScreen(),
    );
  }
}
