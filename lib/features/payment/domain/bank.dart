class Bank {
  const Bank({
    required this.bin,
    required this.name,
    required this.shortName,
    required this.code,
  });

  final String bin;
  final String name;
  final String shortName;
  final String code;
}

class BankCatalog {
  const BankCatalog(this.banks, this.updatedAt);

  final List<Bank> banks;
  final DateTime updatedAt;
}

abstract interface class BankRepository {
  Future<BankCatalog> load();
  Future<BankCatalog> refresh();
}
