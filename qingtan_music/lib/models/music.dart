class MusicSource {
  const MusicSource({
    required this.value,
    required this.label,
    this.official = false,
  });

  final String value;
  final String label;
  final bool official;

  static const all = [
    MusicSource(value: 'netease', label: '网易云音乐'),
    MusicSource(
      value: 'netease_official',
      label: '网易云音乐官方',
      official: true,
    ),
    MusicSource(value: 'tencent', label: 'QQ音乐'),
    MusicSource(value: 'kuwo', label: '酷我音乐'),
    MusicSource(value: 'tidal', label: 'Tidal'),
    MusicSource(value: 'qobuz', label: 'Qobuz'),
    MusicSource(value: 'joox', label: 'JOOX'),
    MusicSource(value: 'bilibili', label: '哔哩哔哩'),
    MusicSource(value: 'apple', label: 'Apple Music'),
    MusicSource(value: 'ytmusic', label: 'Youtube Music'),
    MusicSource(value: 'spotify', label: 'Spotify'),
  ];

  static MusicSource fromValue(String value) {
    return all.firstWhere(
      (source) => source.value == value,
      orElse: () => all.first,
    );
  }
}

class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.source,
    this.artist = '',
    this.album = '',
    this.picId = '',
    this.lyricId = '',
    this.coverUrl = '',
    this.durationMs = 0,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String source;
  final String picId;
  final String lyricId;
  final String coverUrl;
  final int durationMs;

  String get key => '$source:$id';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'source': source,
        'pic_id': picId,
        'lyric_id': lyricId,
        'cover_url': coverUrl,
        'duration_ms': durationMs,
      };

  static MusicTrack? fromJson(dynamic value) {
    if (value is! Map) return null;
    final id = value['id']?.toString().trim() ?? '';
    final source = value['source']?.toString().trim() ?? '';
    if (id.isEmpty || source.isEmpty) return null;
    return MusicTrack(
      id: id,
      title: value['title']?.toString().trim().isNotEmpty == true
          ? value['title'].toString().trim()
          : '未知歌曲',
      artist: value['artist']?.toString().trim() ?? '',
      album: value['album']?.toString().trim() ?? '',
      source: source,
      picId: value['pic_id']?.toString().trim() ?? '',
      lyricId: value['lyric_id']?.toString().trim() ?? '',
      coverUrl: value['cover_url']?.toString().trim() ?? '',
      durationMs: int.tryParse(value['duration_ms']?.toString() ?? '') ?? 0,
    );
  }
}

class LyricsPayload {
  const LyricsPayload({this.original = '', this.translated = ''});

  final String original;
  final String translated;

  String get preferred => original.trim().isNotEmpty ? original : translated;
}
