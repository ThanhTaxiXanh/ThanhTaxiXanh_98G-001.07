import 'dart:typed_data';

import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../domain/bank.dart';
import '../domain/recipient_account.dart';
import '../domain/viet_qr.dart';
import 'payment_providers.dart';

class RecipientEditorScreen extends ConsumerStatefulWidget {
  const RecipientEditorScreen({this.account, super.key});
  final RecipientAccount? account;

  @override
  ConsumerState<RecipientEditorScreen> createState() =>
      _RecipientEditorScreenState();
}

class _RecipientEditorScreenState extends ConsumerState<RecipientEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _holder;
  late final TextEditingController _note;
  Bank? _bank;
  Uint8List? _footerLogo;
  Uint8List? _centerLogo;
  bool _saving = false;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _number = TextEditingController(text: a?.accountNumber);
    _holder = TextEditingController(text: a?.accountHolder);
    _note = TextEditingController(text: a?.defaultNote);
    if (a != null) {
      _bank = Bank(
        bin: a.bankBin,
        name: a.bankName,
        shortName: a.bankName,
        code: '',
      );
      _footerLogo = a.footerLogo;
      _centerLogo = a.centerLogo;
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    _note.dispose();
    super.dispose();
  }

  void _showError(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _refreshBanks() async {
    setState(() => _refreshing = true);
    try {
      await (await ref.read(bankRepositoryProvider.future)).refresh();
      ref.invalidate(bankCatalogProvider);
      _showError('Đã cập nhật danh sách ngân hàng để dùng offline.');
    } catch (_) {
      _showError(
        'Không thể cập nhật ngân hàng. Danh sách đã lưu vẫn dùng được khi không có mạng.',
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _pickLogo(bool center) async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        _showError('Vui lòng chọn ảnh logo nhỏ hơn 2 MB.');
        return;
      }
      final decoded = await decodeImageFromList(bytes);
      decoded.dispose();
      if (!mounted) return;
      setState(() {
        if (center) {
          _centerLogo = bytes;
        } else {
          _footerLogo = bytes;
        }
      });
    } catch (_) {
      _showError('Không thể đọc ảnh. Vui lòng chọn lại.');
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_bank == null) {
      setState(() => _error = 'Vui lòng chọn ngân hàng.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final qr = VietQr(bankBin: _bank!.bin, accountNumber: _number.text);
      final account = RecipientAccount(
        id: widget.account?.id ?? const Uuid().v4(),
        bankBin: _bank!.bin,
        bankName: _bank!.shortName,
        accountNumber: qr.accountNumber,
        accountHolder: _holder.text.trim(),
        defaultNote: _note.text.trim(),
        isDefault: widget.account?.isDefault ?? false,
        footerLogo: _footerLogo,
        centerLogo: _centerLogo,
      );
      await (await ref.read(recipientRepositoryProvider.future)).save(account);
      if (mounted) Navigator.of(context).pop(account.id);
    } on DuplicateRecipientException {
      if (mounted) {
        setState(
          () => _error =
              'Tài khoản này đã được lưu. Hãy chọn tài khoản đó để sửa.',
        );
      }
    } on ArgumentError {
      if (mounted) {
        setState(
          () => _error = 'Số tài khoản cần có từ 1–19 chữ cái hoặc chữ số.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể lưu tài khoản trên máy. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(bankCatalogProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.account == null ? 'Thêm tài khoản' : 'Sửa tài khoản',
        ),
      ),
      body: SafeArea(
        child: catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(bankCatalogProvider),
              child: const Text('Không thể mở danh sách ngân hàng. Thử lại'),
            ),
          ),
          data: (catalog) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Thiết lập một lần. Tài khoản và logo được lưu trên máy để dùng offline.',
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        key: const Key('bank-picker'),
                        onPressed: _saving
                            ? null
                            : () async {
                                final bank = await showSearch<Bank?>(
                                  context: context,
                                  delegate: _BankSearch(catalog.banks),
                                );
                                if (bank != null && mounted) {
                                  setState(() {
                                    _bank = bank;
                                    _error = null;
                                  });
                                }
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _bank?.shortName ?? 'Chọn ngân hàng',
                                ),
                              ),
                              const Icon(Icons.expand_more),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${catalog.banks.length} ngân hàng · Dùng được offline',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          IconButton(
                            key: const Key('refresh-banks'),
                            tooltip: 'Cập nhật ngân hàng',
                            onPressed: _refreshing || _saving
                                ? null
                                : _refreshBanks,
                            icon: _refreshing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sync),
                          ),
                        ],
                      ),
                      TextFormField(
                        key: const Key('recipient-number'),
                        controller: _number,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Số tài khoản',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Nhập số tài khoản.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('recipient-holder'),
                        controller: _holder,
                        maxLength: 100,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Tên chủ tài khoản',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Nhập tên chủ tài khoản.'
                            : null,
                      ),
                      TextFormField(
                        key: const Key('recipient-note'),
                        controller: _note,
                        maxLength: 200,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung mặc định (tùy chọn)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _logoTile('Logo dưới QR', _footerLogo, false),
                      _logoTile('Logo giữa QR', _centerLogo, true),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('save-recipient'),
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Đang lưu…' : 'Lưu tài khoản'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoTile(String label, Uint8List? bytes, bool center) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: bytes == null
        ? const Icon(Icons.image_outlined)
        : Image.memory(bytes, width: 48, height: 48, fit: BoxFit.contain),
    title: Text(label),
    onTap: _saving ? null : () => _pickLogo(center),
    trailing: bytes == null
        ? const Icon(Icons.add_photo_alternate_outlined)
        : IconButton(
            tooltip: 'Xóa $label',
            onPressed: _saving
                ? null
                : () => setState(() {
                    if (center) {
                      _centerLogo = null;
                    } else {
                      _footerLogo = null;
                    }
                  }),
            icon: const Icon(Icons.close),
          ),
  );
}

class _BankSearch extends SearchDelegate<Bank?> {
  _BankSearch(this.banks) : super(searchFieldLabel: 'Tìm tên ngân hàng');
  final List<Bank> banks;
  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      tooltip: 'Xóa tìm kiếm',
      onPressed: () => query = '',
      icon: const Icon(Icons.clear),
    ),
  ];
  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'Quay lại',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );
  @override
  Widget buildResults(BuildContext context) => _results(context);
  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    String searchKey(String value) => removeDiacritics(
      value,
    ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final text = searchKey(query);
    final results = banks
        .where(
          (bank) => searchKey(
            '${bank.shortName} ${bank.name} ${bank.code}',
          ).contains(text),
        )
        .toList();
    if (results.isEmpty) {
      return const Center(child: Text('Không tìm thấy ngân hàng.'));
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final bank = results[i];
        return ListTile(
          title: Text(bank.shortName),
          subtitle: Text(bank.name),
          onTap: () => close(context, bank),
        );
      },
    );
  }
}
