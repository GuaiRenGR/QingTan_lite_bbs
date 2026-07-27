import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/music.dart';

class MusicApiException implements Exception {
  const MusicApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MusicApiService {
  MusicApiService._();

  static final instance = MusicApiService._();

  static const _gdApi = 'https://music-api.gdstudio.xyz/api.php';
  static const _neteaseApi = 'https://music.163.com';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; QingTanMusic) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36',
      },
    ),
  );

  final Map<String, Future<String>> _coverCache = {};
  final Map<String, Future<LyricsPayload>> _lyricsCache = {};

  Future<List<MusicTrack>> search({
    required MusicSource source,
    required String keyword,
    int page = 1,
    int limit = 20,
  }) async {
    final query = keyword.trim();
    if (query.isEmpty) return const [];
    try {
      if (source.official) {
        return await _searchNeteaseOfficial(query, page, limit);
      }
      final response = await _dio.get<dynamic>(
        _gdApi,
        queryParameters: {
          'types': 'search',
          'source': source.value,
          'name': query,
          'count': limit.clamp(1, 50),
          'pages': page < 1 ? 1 : page,
        },
        options: Options(headers: {'Referer': 'https://music.gdstudio.xyz/'}),
      );
      final rows = _extractList(response.data);
      return rows.map((row) => _gdTrack(row, source.value)).whereType<MusicTrack>().toList(growable: false);
    } on MusicApiException {
      rethrow;
    } on DioException catch (error) {
      throw MusicApiException(_networkMessage(error, '搜索失败'));
    } catch (_) {
      throw const MusicApiException('音乐接口返回的数据无法解析');
    }
  }

  Future<List<MusicTrack>> _searchNeteaseOfficial(
    String keyword,
    int page,
    int limit,
  ) async {
    final response = await _dio.get<dynamic>(
      '$_neteaseApi/api/cloudsearch/pc',
      queryParameters: {
        's': keyword,
        'type': 1,
        'limit': limit.clamp(1, 50),
        'offset': (page < 1 ? 0 : page - 1) * limit,
      },
      options: Options(headers: {'Referer': 'https://music.163.com/'}),
    );
    final payload = _asMap(response.data);
    final result = _asMap(payload['result']);
    final songs = result['songs'] is List ? result['songs'] as List : const [];
    return songs.map((value) {
      final song = _asMap(value);
      final id = song['id']?.toString().trim() ?? '';
      if (id.isEmpty) return null;
      final artists = song['artists'] ?? song['ar'];
      final album = _asMap(song['album'] ?? song['al']);
      return MusicTrack(
        id: id,
        title: _nonEmpty(song['name'], '未知歌曲'),
        artist: _artistNames(artists),
        album: album['name']?.toString().trim() ?? '',
        source: 'netease_official',
        picId: '',
        lyricId: id,
        coverUrl: _httpsUrl(album['picUrl']?.toString() ?? ''),
        durationMs: _toInt(song['duration'] ?? song['dt']),
      );
    }).whereType<MusicTrack>().toList(growable: false);
  }

  Future<String> resolveAudioUrl(MusicTrack track) async {
    try {
      if (track.source == 'netease_official') {
        final response = await _dio.get<dynamic>(
          '$_neteaseApi/api/song/enhance/player/url',
          queryParameters: {'ids': '[${track.id}]', 'br': 128000},
          options: Options(headers: {'Referer': 'https://music.163.com/'}),
        );
        final payload = _asMap(response.data);
        final data = payload['data'] is List ? payload['data'] as List : const [];
        final item = data.isEmpty ? const <String, dynamic>{} : _asMap(data.first);
        return _requireUrl(item['url'], '当前歌曲无法以标准音质播放');
      }
      final response = await _dio.get<dynamic>(
        _gdApi,
        queryParameters: {
          'types': 'url',
          'source': track.source,
          'id': track.id,
          'br': 128,
        },
        options: Options(headers: {'Referer': 'https://music.gdstudio.xyz/'}),
      );
      return _requireUrl(_asMap(response.data)['url'], '当前歌曲无法以标准音质播放');
    } on MusicApiException {
      rethrow;
    } on DioException catch (error) {
      throw MusicApiException(_networkMessage(error, '播放地址获取失败'));
    }
  }

  Future<String> resolveCoverUrl(MusicTrack track) {
    return _coverCache.putIfAbsent(track.key, () => _loadCoverUrl(track));
  }

  Future<String> _loadCoverUrl(MusicTrack track) async {
    final direct = _httpsUrl(track.coverUrl.isNotEmpty ? track.coverUrl : track.picId);
    if (direct.isNotEmpty) return direct;
    if (track.picId.isEmpty || track.source == 'netease_official') return '';
    try {
      final response = await _dio.get<dynamic>(
        _gdApi,
        queryParameters: {
          'types': 'pic',
          'source': track.source,
          'id': track.picId,
          'size': 500,
        },
        options: Options(headers: {'Referer': 'https://music.gdstudio.xyz/'}),
      );
      return _httpsUrl(_asMap(response.data)['url']?.toString() ?? '');
    } catch (_) {
      return '';
    }
  }

  Future<LyricsPayload> lyrics(MusicTrack track) {
    return _lyricsCache.putIfAbsent(track.key, () => _loadLyrics(track));
  }

  Future<LyricsPayload> _loadLyrics(MusicTrack track) async {
    final lyricId = track.lyricId.isEmpty ? track.id : track.lyricId;
    try {
      if (track.source == 'netease_official') {
        final response = await _dio.get<dynamic>(
          '$_neteaseApi/api/song/lyric',
          queryParameters: {'id': lyricId, 'lv': -1, 'tv': -1},
          options: Options(headers: {'Referer': 'https://music.163.com/'}),
        );
        final payload = _asMap(response.data);
        return LyricsPayload(
          original: _asMap(payload['lrc'])['lyric']?.toString() ?? '',
          translated: _asMap(payload['tlyric'])['lyric']?.toString() ?? '',
        );
      }
      final response = await _dio.get<dynamic>(
        _gdApi,
        queryParameters: {
          'types': 'lyric',
          'source': track.source,
          'id': lyricId,
        },
        options: Options(headers: {'Referer': 'https://music.gdstudio.xyz/'}),
      );
      final payload = _asMap(response.data);
      return LyricsPayload(
        original: payload['lyric']?.toString() ?? '',
        translated: payload['tlyric']?.toString() ?? '',
      );
    } catch (_) {
      return const LyricsPayload();
    }
  }

  Future<Uint8List?> coverBytes(MusicTrack track) async {
    final url = await resolveCoverUrl(track);
    if (url.isEmpty) return null;
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      return data == null || data.isEmpty ? null : Uint8List.fromList(data);
    } catch (_) {
      return null;
    }
  }

  MusicTrack? _gdTrack(Map<String, dynamic> row, String fallbackSource) {
    final id = row['id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    final source = row['source']?.toString().trim() ?? '';
    return MusicTrack(
      id: id,
      title: _nonEmpty(row['name'], '未知歌曲'),
      artist: _artistNames(row['artist']),
      album: row['album']?.toString().trim() ?? '',
      source: source.isEmpty ? fallbackSource : source,
      picId: row['pic_id']?.toString().trim() ?? '',
      lyricId: row['lyric_id']?.toString().trim() ?? id,
      coverUrl: '',
    );
  }

  List<Map<String, dynamic>> _extractList(dynamic payload) {
    if (payload is List) return payload.map(_asMap).where((row) => row.isNotEmpty).toList();
    final map = _asMap(payload);
    final value = map['data'] ?? map['list'];
    if (value is! List) return const [];
    return value.map(_asMap).where((row) => row.isNotEmpty).toList();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String _artistNames(dynamic value) {
    if (value is String) return value.trim();
    if (value is! List) return '';
    return value.map((artist) {
      if (artist is Map) return artist['name']?.toString().trim() ?? '';
      return artist?.toString().trim() ?? '';
    }).where((name) => name.isNotEmpty).join(' / ');
  }

  String _requireUrl(dynamic value, String message) {
    final url = _httpsUrl(value?.toString() ?? '');
    if (url.isEmpty) throw MusicApiException(message);
    return url;
  }

  String _httpsUrl(String value) {
    var url = value.trim();
    if (url.startsWith('//')) url = 'https:$url';
    if (url.startsWith('http://')) url = 'https://${url.substring(7)}';
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty ? url : '';
  }

  String _nonEmpty(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  int _toInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  String _networkMessage(DioException error, String fallback) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return '音乐接口连接超时';
    }
    final status = error.response?.statusCode;
    return status == null ? fallback : '$fallback（HTTP $status）';
  }
}
