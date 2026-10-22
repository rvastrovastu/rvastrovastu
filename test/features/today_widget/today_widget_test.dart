import 'package:flutter_test/flutter_test.dart';
import 'package:rv_astro_vastu/features/today_widget/today_widget_sync.dart';

void main() {
  test('days are written with ISO dates for the native widgets', () {
    final day = TodayWidgetDay(
      date: DateTime(2026, 3, 4),
      title: 'Holi',
      detail: 'Purnima · Uttara Phalguni',
      rahuKaal: '01:30 PM – 03:00 PM',
      rashifal: 'Leo ★★★★☆',
    );
    expect(day.toJson(), {
      'date': '2026-03-04',
      'title': 'Holi',
      'detail': 'Purnima · Uttara Phalguni',
      'rahu': '01:30 PM – 03:00 PM',
      'rashifal': 'Leo ★★★★☆',
    });
  });

  test('stars render as five symbols', () {
    expect(starText(4), '★★★★☆');
    expect(starText(1), '★☆☆☆☆');
  });
}
