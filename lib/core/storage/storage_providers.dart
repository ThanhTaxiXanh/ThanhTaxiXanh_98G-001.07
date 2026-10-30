import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

final appDatabaseProvider = FutureProvider((ref) async {
  final db = await openAppDatabase();
  ref.onDispose(() {
    unawaited(db.close());
  });
  return db;
});
