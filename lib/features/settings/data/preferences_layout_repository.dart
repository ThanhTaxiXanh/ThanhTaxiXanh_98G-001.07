import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/dashboard_layout.dart';

class PreferencesLayoutRepository {
  static const key = 'dashboard_layout_v1';
  Future<DashboardLayout> load() async {
    final value = (await SharedPreferences.getInstance()).get(key);
    try {
      return value is String
          ? DashboardLayout.read(jsonDecode(value))
          : DashboardLayout.qr;
    } on FormatException {
      return DashboardLayout.qr;
    }
  }

  Future<void> save(DashboardLayout value) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(value.toJson()),
    )) {
      throw StateError('Chưa lưu được bố cục.');
    }
  }
}
