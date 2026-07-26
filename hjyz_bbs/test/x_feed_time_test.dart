import 'package:flutter_test/flutter_test.dart';
import 'package:hjyz_bbs/features/home/x_feed_page.dart';

void main() {
  final now = DateTime(2026, 7, 26, 15, 30);

  test('formats same-day X feed times without 前', () {
    expect(formatXFeedTime('2026-07-26 15:29:30', now: now), '刚刚');
    expect(formatXFeedTime('2026-07-26 15:12:00', now: now), '18分钟');
    expect(formatXFeedTime('2026-07-26 12:00:00', now: now), '3小时');
  });

  test('formats recent and older X feed times', () {
    expect(formatXFeedTime('2026-07-25 15:30:00', now: now), '1天');
    expect(formatXFeedTime('2026-07-24 12:00:00', now: now), '2天');
    expect(
      formatXFeedTime('2026-07-20 08:05:00', now: now),
      '2026-07-20 08:05',
    );
  });

  test('accepts boolean and legacy numeric liked states', () {
    expect(parseXFeedLiked(true), isTrue);
    expect(parseXFeedLiked(1), isTrue);
    expect(parseXFeedLiked('1'), isTrue);
    expect(parseXFeedLiked('true'), isTrue);
    expect(parseXFeedLiked(false), isFalse);
    expect(parseXFeedLiked(0), isFalse);
  });
}
