import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/calendar_event.dart';
import '../domain/lunar_calendar.dart';
import 'calendar_providers.dart';
import 'event_providers.dart';

class EventEditorScreen extends ConsumerStatefulWidget {
  const EventEditorScreen({this.event, super.key});
  final CalendarEvent? event;
  @override
  ConsumerState<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends ConsumerState<EventEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _year;
  late int _day;
  late int _month;
  late EventCalendar _calendar;
  bool _leap = false;
  bool _yearly = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final today = ref.read(vietnamTodayProvider);
    _title = TextEditingController(text: event?.title);
    _notes = TextEditingController(text: event?.notes);
    _year = TextEditingController(text: '${event?.year ?? today.year}');
    _day = event?.day ?? today.day;
    _month = event?.month ?? today.month;
    _calendar = event?.calendar ?? EventCalendar.solar;
    _leap = event?.leap ?? false;
    _yearly = event?.yearly ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _year.dispose();
    super.dispose();
  }

  DateTime? get _solar {
    final year = int.tryParse(_year.text);
    if (year == null || year < 1900 || year > 2099) return null;
    if (_calendar == EventCalendar.lunar) {
      return ref
          .read(lunarCalendarProvider)
          .lunarToSolar(LunarDate(_day, _month, year, leap: _leap));
    }
    return DateTime.utc(year, _month, _day);
  }

  void _switchCalendar(EventCalendar next) {
    if (next == _calendar) return;
    final DateTime date = _solar ?? ref.read(vietnamTodayProvider);
    setState(() {
      _calendar = next;
      _error = null;
      if (next == EventCalendar.lunar) {
        final lunar = ref
            .read(lunarCalendarProvider)
            .solarToLunar(date.day, date.month, date.year);
        _day = lunar.day;
        _month = lunar.month;
        _year.text = '${lunar.year}';
        _leap = lunar.leap;
      } else {
        _day = date.day;
        _month = date.month;
        _year.text = '${date.year}';
        _leap = false;
      }
    });
  }

  Future<void> _pickDate() async {
    final DateTime current = _solar ?? ref.read(vietnamTodayProvider);
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime(2099, 12, 31),
      helpText: 'Chọn ngày sự kiện',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (date != null && mounted) {
      setState(() {
        _day = date.day;
        _month = date.month;
        _year.text = '${date.year}';
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final event = CalendarEvent(
      id: widget.event?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      notes: _notes.text.trim(),
      day: _day,
      month: _month,
      year: int.tryParse(_year.text) ?? 0,
      calendar: _calendar,
      leap: _leap,
      yearly: _yearly,
    );
    try {
      event.validate(ref.read(lunarCalendarProvider));
    } on ArgumentError {
      setState(
        () => _error =
            'Ngày không hợp lệ. Kiểm tra ngày, tháng, năm và tháng nhuận.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await (await ref.read(eventRepositoryProvider.future)).save(event);
      ref.invalidate(eventsProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể lưu sự kiện trên máy. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = _solar;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'Thêm sự kiện' : 'Sửa sự kiện'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('event-title'),
                      controller: _title,
                      enabled: !_saving,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Tên sự kiện',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nhập tên sự kiện.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<EventCalendar>(
                      initialValue: _calendar,
                      decoration: const InputDecoration(labelText: 'Loại lịch'),
                      items: const [
                        DropdownMenuItem(
                          value: EventCalendar.solar,
                          child: Text('Dương lịch'),
                        ),
                        DropdownMenuItem(
                          value: EventCalendar.lunar,
                          child: Text('Âm lịch'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) _switchCalendar(value);
                            },
                    ),
                    const SizedBox(height: 16),
                    if (_calendar == EventCalendar.solar)
                      OutlinedButton.icon(
                        key: const Key('event-date'),
                        onPressed: _saving ? null : _pickDate,
                        icon: const Icon(Icons.calendar_month),
                        label: Text('$_day/$_month/${_year.text}'),
                      )
                    else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: ValueKey('lunar-day-$_day'),
                              initialValue: _day,
                              decoration: const InputDecoration(
                                labelText: 'Ngày âm',
                              ),
                              items: [
                                for (var i = 1; i <= 30; i++)
                                  DropdownMenuItem(value: i, child: Text('$i')),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => _day = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: ValueKey('lunar-month-$_month'),
                              initialValue: _month,
                              decoration: const InputDecoration(
                                labelText: 'Tháng âm',
                              ),
                              items: [
                                for (var i = 1; i <= 12; i++)
                                  DropdownMenuItem(value: i, child: Text('$i')),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => _month = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('event-lunar-year'),
                        controller: _year,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'Năm âm (1900–2099)',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      CheckboxListTile(
                        title: const Text('Tháng nhuận'),
                        contentPadding: EdgeInsets.zero,
                        value: _leap,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _leap = v!),
                      ),
                      Text(
                        date == null
                            ? 'Ngày âm này không tồn tại trong năm đã chọn.'
                            : 'Dương lịch: ${date.day}/${date.month}/${date.year}',
                      ),
                    ],
                    SwitchListTile(
                      key: const Key('event-yearly'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Lặp hằng năm'),
                      value: _yearly,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _yearly = v),
                    ),
                    if (_yearly)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Ngày 29/2 và ngày âm trong tháng nhuận chỉ lặp ở năm có ngày đó.',
                        ),
                      ),
                    TextFormField(
                      key: const Key('event-notes'),
                      controller: _notes,
                      maxLength: 1000,
                      maxLines: 3,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (tùy chọn)',
                      ),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('save-event'),
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Đang lưu…' : 'Lưu sự kiện'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
