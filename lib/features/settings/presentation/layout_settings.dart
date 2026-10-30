import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/dashboard_layout.dart';
import '../data/preferences_layout_repository.dart';
export '../domain/dashboard_layout.dart';

final layoutSettingsProvider =
    AsyncNotifierProvider<LayoutSettings, DashboardLayout>(LayoutSettings.new);

class LayoutSettings extends AsyncNotifier<DashboardLayout> {
  static const key = 'dashboard_layout_v1';
  Future<void> _writes = Future.value();
  final _repository = PreferencesLayoutRepository();
  @override
  Future<DashboardLayout> build() => _repository.load();

  Future<void> save(DashboardLayout next) {
    final write = _writes.then((_) async {
      await _repository.save(next);
      if (ref.mounted) state = AsyncData(next);
    });
    _writes = write.catchError((Object _) {});
    return write;
  }
}
