import 'package:flutter_test/flutter_test.dart';
import 'package:qingtan_music/utils/lrc.dart';

void main() {
  test('parses and sorts LRC timestamps', () {
    final lines = parseLrc('[00:10.50]第二句\n[00:02.10]第一句');
    expect(lines.map((line) => line.text), ['第一句', '第二句']);
    expect(lines.first.time, const Duration(seconds: 2, milliseconds: 100));
  });

  test('supports multiple timestamps on one lyric line', () {
    final lines = parseLrc('[00:01.00][00:03.25]重复');
    expect(lines.length, 2);
    expect(lines.last.time, const Duration(seconds: 3, milliseconds: 250));
  });

  test('finds the active line without scanning every item', () {
    final lines = parseLrc('[00:01]一\n[00:02]二\n[00:03]三');
    expect(activeLyricIndex(lines, const Duration(milliseconds: 500)), -1);
    expect(activeLyricIndex(lines, const Duration(milliseconds: 2500)), 1);
  });
}
