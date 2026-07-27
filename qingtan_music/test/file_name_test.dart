import 'package:flutter_test/flutter_test.dart';
import 'package:qingtan_music/utils/file_name.dart';

void main() {
  test('builds the required song and artist filename', () {
    expect(buildDownloadBaseName('晴天', '周杰伦'), '晴天 - 周杰伦');
  });

  test('replaces characters Android cannot use in filenames', () {
    expect(
      buildDownloadBaseName('A/B: C?', 'X\\Y | Z'),
      'A、B、 C、 - X、Y 、 Z',
    );
  });

  test('uses explicit fallbacks for missing metadata', () {
    expect(buildDownloadBaseName('', ''), '未知歌曲 - 未知歌手');
  });
}
