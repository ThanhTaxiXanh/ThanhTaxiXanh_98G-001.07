import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recipient_account.dart';
import '../domain/viet_qr.dart';
import 'payment_providers.dart';
import 'recipient_editor_screen.dart';
import 'viet_qr_card.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _amountFocus = FocusNode();
  String? _selectedId;
  VietQr? _payment;
  RecipientAccount? _previewAccount;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(recipientsProvider, (_, next) {
      if (next.isLoading || next.hasError || !next.hasValue) return;
      final accounts = next.requireValue;
      final matches = accounts.where((a) => a.id == _selectedId);
      final selected = matches.firstOrNull ?? accounts.firstOrNull;
      _select(selected);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _select(RecipientAccount? account) {
    setState(() {
      _selectedId = account?.id;
      _amount.clear();
      _note.text = account?.defaultNote ?? '';
      _previewAccount = account;
      _payment = account?.payment();
      _error = null;
    });
  }

  void _dirty() => setState(() {
    _payment = null;
    _error = null;
  });

  Future<void> _edit([RecipientAccount? account]) async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RecipientEditorScreen(account: account),
      ),
    );
    if (!mounted || id == null) return;
    _selectedId = id;
    ref.invalidate(recipientsProvider);
  }

  void _generate(RecipientAccount account) {
    try {
      final payment = account.payment(amount: _amount.text, note: _note.text);
      setState(() {
        _payment = payment;
        _previewAccount = account;
        _error = null;
      });
      FocusScope.of(context).unfocus();
    } on ArgumentError {
      setState(() {
        _payment = null;
        _error =
            'Nhập số tiền VND nguyên, tối đa 13 chữ số. '
            'Ví dụ: 25000 hoặc 25,000.';
      });
    }
  }

  Future<void> _mutate(
    Future<void> Function(RecipientRepository) action,
  ) async {
    setState(() => _busy = true);
    try {
      await action(await ref.read(recipientRepositoryProvider.future));
      ref.invalidate(recipientsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu thay đổi. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(RecipientAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tài khoản?'),
        content: Text(account.label),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _mutate((repo) => repo.delete(account.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipientsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('VietQR nhận tiền')),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(recipientsProvider),
              child: const Text('Không thể mở tài khoản đã lưu. Thử lại'),
            ),
          ),
          data: (accounts) {
            if (accounts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_outlined, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Chưa có tài khoản nhận tiền',
                        style: TextStyle(fontSize: 22),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Chọn ngân hàng, nhập tài khoản và tên chủ tài khoản một lần. '
                        'Những lần sau chỉ cần nhập số tiền và nội dung.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        key: const Key('add-recipient'),
                        onPressed: () => _edit(),
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm tài khoản'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final selected =
                accounts.where((a) => a.id == _selectedId).firstOrNull ??
                accounts.first;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_payment != null) ...[
                        VietQrCard(
                          payment: _payment!,
                          bankLogo: _previewAccount?.footerLogo == null
                              ? null
                              : MemoryImage(_previewAccount!.footerLogo!),
                          centerLogo: _previewAccount?.centerLogo == null
                              ? null
                              : MemoryImage(_previewAccount!.centerLogo!),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                key: ValueKey('recipient-${selected.id}'),
                                initialValue: selected.id,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Tài khoản nhận tiền',
                                ),
                                items: accounts
                                    .map(
                                      (a) => DropdownMenuItem(
                                        value: a.id,
                                        child: Text(
                                          a.label,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _busy
                                    ? null
                                    : (id) => _select(
                                        accounts.firstWhere((a) => a.id == id),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton.icon(
                                    key: const Key('add-recipient'),
                                    onPressed: _busy ? null : () => _edit(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Thêm'),
                                  ),
                                  TextButton(
                                    key: const Key('edit-recipient'),
                                    onPressed: _busy
                                        ? null
                                        : () => _edit(selected),
                                    child: const Text('Sửa tài khoản'),
                                  ),
                                  TextButton.icon(
                                    key: const Key('default-recipient'),
                                    onPressed: _busy || selected.isDefault
                                        ? null
                                        : () => _mutate(
                                            (repo) =>
                                                repo.setDefault(selected.id),
                                          ),
                                    icon: Icon(
                                      selected.isDefault
                                          ? Icons.star
                                          : Icons.star_border,
                                    ),
                                    label: const Text('Mặc định'),
                                  ),
                                  TextButton(
                                    key: const Key('delete-recipient'),
                                    onPressed: _busy
                                        ? null
                                        : () => _delete(selected),
                                    child: const Text('Xóa'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${selected.bankName} · ${selected.accountNumber}\n${selected.accountHolder}',
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                key: const Key('payment-amount'),
                                controller: _amount,
                                focusNode: _amountFocus,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Số tiền (VND)',
                                  hintText: 'Để trống để người trả nhập',
                                ),
                                onChanged: (_) => _dirty(),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final value in [
                                    10000,
                                    20000,
                                    50000,
                                    100000,
                                    200000,
                                    500000,
                                  ])
                                    OutlinedButton(
                                      onPressed: () {
                                        _amount.text = '$value';
                                        _dirty();
                                      },
                                      child: Text('${value ~/ 1000}K'),
                                    ),
                                  TextButton(
                                    onPressed: () =>
                                        _amountFocus.requestFocus(),
                                    child: const Text('Tùy chỉnh'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                key: const Key('payment-note'),
                                controller: _note,
                                maxLength: 200,
                                decoration: const InputDecoration(
                                  labelText: 'Nội dung chuyển khoản',
                                ),
                                onChanged: (_) => _dirty(),
                              ),
                              if (_error != null)
                                Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  FilledButton(
                                    key: const Key('update-payment'),
                                    onPressed: () => _generate(selected),
                                    child: const Text('CẬP NHẬT'),
                                  ),
                                  OutlinedButton(
                                    key: const Key('clear-amount'),
                                    onPressed: () {
                                      _amount.clear();
                                      _generate(selected);
                                    },
                                    child: const Text('XÓA SỐ TIỀN'),
                                  ),
                                ],
                              ),
                              if (_payment == null && _error == null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Nhấn CẬP NHẬT để hiển thị QR với thông tin vừa nhập.',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
