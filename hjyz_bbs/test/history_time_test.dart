import 'package:flutter_test/flutter_test.dart';
import 'package:hjyz_bbs/features/history/history_page.dart';

void main() {
  test('formats the history last viewed time to minutes', () {
    expect(
      formatHistoryViewedAt('2026-07-26 09:05:42'),
      '2026-07-26 09:05',
    );
  });

  test('keeps an unknown history time unchanged', () {
    expect(formatHistoryViewedAt('刚刚'), '刚刚');
  });
}
