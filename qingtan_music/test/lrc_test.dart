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

  test('merges translated lyrics by timestamp with a small tolerance', () {
    final lines = parseBilingualLrc(
      '[00:01.00]Hello\n[00:03.00]Goodbye',
      '[00:01.20]你好\n[00:03.40]再见',
    );

    expect(lines.map((line) => line.text), ['Hello', 'Goodbye']);
    expect(lines.map((line) => line.translation), ['你好', '再见']);
  });

  test('uses translated lyrics as primary when original lyrics are absent', () {
    final lines = parseBilingualLrc('', '[00:01.00]只有翻译');

    expect(lines.single.text, '只有翻译');
    expect(lines.single.translation, isEmpty);
  });

  test('exports original and translated lines in timestamp order', () {
    final result = buildBilingualLrc(
      '[00:01.00]Hello\n[00:03.00]Goodbye',
      '[00:01.00]你好\n[00:03.20]再见',
    );

    expect(
      result,
      '[00:01.000]Hello\n'
      '[00:01.000]你好\n'
      '[00:03.000]Goodbye\n'
      '[00:03.200]再见',
    );
  });
}
