import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/viet_qr.dart';
import 'viet_qr_card.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _bank = TextEditingController();
  final _account = TextEditingController();
  final _holder = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _bankName = TextEditingController();
  VietQr? _payment;
  ImageProvider? _bankLogo;
  ImageProvider? _centerLogo;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _bank,
      _account,
      _holder,
      _amount,
      _note,
      _bankName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _generate() {
    try {
      final payment = VietQr(
        bankBin: _bank.text.trim(),
        accountNumber: _account.text,
        bankName: _bankName.text.trim(),
        accountHolder: _holder.text,
        amount: _amount.text,
        note: _note.text,
      );
      setState(() {
        _payment = payment;
        _error = null;
      });
    } on ArgumentError {
      setState(() {
        _payment = null;
        _error =
            'Kiểm tra BIN ngân hàng (6 chữ số), tài khoản (1–19 ký tự) '
            'và số tiền VND nguyên, tối đa 13 chữ số.';
      });
    }
  }

  Future<void> _pickLogo({required bool center}) async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (center) {
          _centerLogo = MemoryImage(bytes);
        } else {
          _bankLogo = MemoryImage(bytes);
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở ảnh. Vui lòng chọn lại.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo VietQR')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nhập thông tin tài khoản nhận tiền. '
                  'Thông tin chỉ dùng trong phiên này.',
                ),
                _field(_bankName, 'Tên ngân hàng (tùy chọn)'),
                _field(_bank, 'BIN ngân hàng (6 chữ số)', numeric: true),
                _field(_account, 'Số tài khoản'),
                _field(_holder, 'Tên chủ tài khoản (tùy chọn)'),
                _field(
                  _amount,
                  'Số tiền VND (để trống để người trả nhập)',
                  numeric: true,
                ),
                _field(_note, 'Nội dung chuyển khoản (tùy chọn)'),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _pickLogo(center: false),
                      child: const Text('Logo ngân hàng'),
                    ),
                    OutlinedButton(
                      onPressed: () => _pickLogo(center: true),
                      child: const Text('Logo giữa QR'),
                    ),
                    if (_centerLogo != null || _bankLogo != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _centerLogo = null;
                          _bankLogo = null;
                        }),
                        child: const Text('Xóa logo'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _generate,
                  child: const Text('Tạo mã QR'),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_payment != null) ...[
                  const SizedBox(height: 20),
                  VietQrCard(
                    payment: _payment!,
                    bankLogo: _bankLogo,
                    centerLogo: _centerLogo,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Kiểm tra tên người nhận trên ứng dụng ngân hàng trước khi chuyển tiền.',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
