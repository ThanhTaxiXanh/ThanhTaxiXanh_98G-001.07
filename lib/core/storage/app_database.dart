import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

Future<Database> openAppDatabase({
  DatabaseFactory? factory,
  String? databasePath,
}) async {
  final selectedFactory = factory ?? databaseFactory;
  final location =
      databasePath ??
      path.join(await selectedFactory.getDatabasesPath(), 'taxi_auto.db');
  return selectedFactory.openDatabase(
    location,
    options: OpenDatabaseOptions(
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE events ADD COLUMN is_monthly INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
      onCreate: (db, _) async {
        await db.execute('''CREATE TABLE banks (
        bin TEXT PRIMARY KEY, name TEXT NOT NULL,
        short_name TEXT NOT NULL, code TEXT NOT NULL
      )''');
        await db.execute(
          'CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute('''CREATE TABLE recipients (
        id TEXT PRIMARY KEY, bank_bin TEXT NOT NULL, bank_name TEXT NOT NULL,
        account_number TEXT NOT NULL, account_holder TEXT NOT NULL,
        default_note TEXT NOT NULL, is_default INTEGER NOT NULL DEFAULT 0,
        footer_logo BLOB, center_logo BLOB,
        UNIQUE(bank_bin, account_number), CHECK(is_default IN (0, 1))
      )''');
        await db.execute(
          'CREATE UNIQUE INDEX one_default_recipient ON recipients(is_default) WHERE is_default = 1',
        );
        await db.execute('''CREATE TABLE events (
        id TEXT PRIMARY KEY, title TEXT NOT NULL, notes TEXT NOT NULL,
        calendar TEXT NOT NULL, day INTEGER NOT NULL,
        month INTEGER NOT NULL, year INTEGER NOT NULL,
        is_leap INTEGER NOT NULL, is_yearly INTEGER NOT NULL,
        is_monthly INTEGER NOT NULL DEFAULT 0
      )''');
      },
    ),
  );
}
