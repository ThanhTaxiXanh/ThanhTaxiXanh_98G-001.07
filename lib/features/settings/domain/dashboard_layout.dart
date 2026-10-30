class DashboardLayout {
  const DashboardLayout._(this.calendar, this.payment, this.media);
  static const qr = DashboardLayout._(25, 50, 25);
  static const balanced = DashboardLayout._(33, 34, 33);
  static const events = DashboardLayout._(45, 35, 20);
  factory DashboardLayout(int calendar, int payment, int media) {
    if ([calendar, payment, media].any((n) => n < 15 || n > 70) ||
        calendar + payment + media != 100) {
      throw ArgumentError('Ba hàng phải có tổng 100%, mỗi hàng từ 15–70%.');
    }
    return DashboardLayout._(calendar, payment, media);
  }
  final int calendar, payment, media;
  Map<String, int> toJson() => {
    'calendar': calendar,
    'payment': payment,
    'media': media,
  };
  static DashboardLayout read(Object? value) {
    try {
      if (value is! Map) return qr;
      return DashboardLayout(
        value['calendar'] as int,
        value['payment'] as int,
        value['media'] as int,
      );
    } catch (_) {
      return qr;
    }
  }
}
