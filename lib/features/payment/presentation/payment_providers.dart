import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/storage/storage_providers.dart';
import '../data/sqlite_bank_repository.dart';
import '../data/sqlite_recipient_repository.dart';
import '../domain/bank.dart';
import '../domain/recipient_account.dart';

final bankRepositoryProvider = FutureProvider<BankRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final client = http.Client();
  ref.onDispose(client.close);
  return SqliteBankRepository(
    db,
    client,
    () => rootBundle.loadString('assets/data/vietqr_banks.json'),
  );
});

final bankCatalogProvider = FutureProvider(
  (ref) async => (await ref.watch(bankRepositoryProvider.future)).load(),
);

final recipientRepositoryProvider = FutureProvider<RecipientRepository>(
  (ref) async =>
      SqliteRecipientRepository(await ref.watch(appDatabaseProvider.future)),
);

final recipientsProvider = FutureProvider(
  (ref) async => (await ref.watch(recipientRepositoryProvider.future)).list(),
);
