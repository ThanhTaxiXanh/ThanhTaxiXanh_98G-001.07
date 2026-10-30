import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/map_models.dart';
import 'map_providers.dart';

class PlaceSearchScreen extends ConsumerStatefulWidget {
  const PlaceSearchScreen({super.key});
  @override
  ConsumerState<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends ConsumerState<PlaceSearchScreen> {
  final _query = TextEditingController();
  List<MapPlace> _results = [];
  String? _message;
  bool _busy = false;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _results = [];
    });
    final repo = ref.read(mapRepositoryProvider);
    try {
      final results = await repo.search(_query.text);
      if (mounted) {
        setState(() {
          _results = results;
          if (results.isEmpty) {
            _message =
                'Không tìm thấy địa chỉ. Hãy thêm tên đường, xã/phường hoặc tỉnh.';
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is MapServiceException
              ? error.message
              : 'Không tìm được địa chỉ. Kiểm tra kết nối mạng rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tìm điểm đến')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  key: const Key('place-query'),
                  controller: _query,
                  maxLength: 200,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ tại Việt Nam',
                    hintText: 'Tên đường, địa điểm, tỉnh/thành phố',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('search-places'),
                  onPressed: _busy ? null : _search,
                  icon: const Icon(Icons.search),
                  label: Text(_busy ? 'Đang tìm…' : 'Tìm địa chỉ'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tìm địa chỉ qua OpenStreetMap. Bạn cũng có thể nhấn giữ trên bản đồ để chọn đích.',
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_message!),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(result.name),
                  onTap: () => Navigator.pop(context, result),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
