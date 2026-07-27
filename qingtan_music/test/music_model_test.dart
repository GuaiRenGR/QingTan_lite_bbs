import 'package:flutter_test/flutter_test.dart';
import 'package:qingtan_music/models/music.dart';

void main() {
  test('exposes all requested music sources in the required order', () {
    expect(
      MusicSource.all.map((source) => source.label),
      [
        '网易云音乐',
        '网易云音乐官方',
        'QQ音乐',
        '酷我音乐',
        'Tidal',
        'Qobuz',
        'JOOX',
        '哔哩哔哩',
        'Apple Music',
        'Youtube Music',
        'Spotify',
      ],
    );
  });

  test('preserves non-numeric IDs when restoring a track', () {
    final track = MusicTrack.fromJson({
      'id': 'BV14tNDesEpK',
      'title': 'Test',
      'source': 'bilibili',
    });
    expect(track?.id, 'BV14tNDesEpK');
    expect(track?.key, 'bilibili:BV14tNDesEpK');
  });
}
