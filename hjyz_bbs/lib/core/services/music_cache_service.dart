import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';

class MusicMetadata {
  final String url;
  final String title;
  final String artist;
  final Uint8List? coverArt;

  const MusicMetadata({
    required this.url,
    required this.title,
    this.artist = '',
    this.coverArt,
  });

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'artist': artist,
      'cover_art': coverArt == null ? null : base64Encode(coverArt!),
    };
  }

  static MusicMetadata? fromJson(dynamic value) {
    if (value is! Map) return null;

    final url = value['url']?.toString().trim() ?? '';
    final title = value['title']?.toString().trim() ?? '';
    if (url.isEmpty || title.isEmpty) return null;

    Uint8List? coverArt;
    final encodedCover = value['cover_art']?.toString() ?? '';
    if (encodedCover.isNotEmpty) {
      try {
        coverArt = base64Decode(encodedCover);
      } catch (_) {}
    }

    return MusicMetadata(
      url: url,
      title: title,
      artist: value['artist']?.toString().trim() ?? '',
      coverArt: coverArt,
    );
  }
}

class MusicLyricLine {
  final Duration? timestamp;
  final String text;

  const MusicLyricLine({required this.timestamp, required this.text});
}

class MusicLyrics {
  final List<MusicLyricLine> lines;
  final bool synchronized;

  const MusicLyrics({required this.lines, required this.synchronized});

  int activeIndex(Duration position) {
    if (!synchronized || lines.isEmpty) return -1;

    var active = -1;
    for (var index = 0; index < lines.length; index++) {
      final timestamp = lines[index].timestamp;
      if (timestamp == null || timestamp > position) break;
      active = index;
    }
    return active;
  }
}

class MusicCacheService {
  MusicCacheService._();

  static final MusicCacheService instance = MusicCacheService._();

  final CacheManager audioCache = CacheManager(
    Config(
      'hjyz_bbs_music_audio',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 40,
    ),
  );

  final CacheManager metadataCache = CacheManager(
    Config(
      'hjyz_bbs_music_metadata',
      stalePeriod: const Duration(days: 60),
      maxNrOfCacheObjects: 300,
    ),
  );

  final CacheManager lyricsCache = CacheManager(
    Config(
      'hjyz_bbs_music_lyrics',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 200,
    ),
  );

  final Map<String, MusicMetadata> _metadataMemory = {};
  final Map<String, Future<MusicMetadata>> _metadataRequests = {};
  final Map<String, MusicLyrics> _lyricsMemory = {};
  final Map<String, Future<MusicLyrics?>> _lyricsRequests = {};
  final Map<String, Future<File>> _audioDownloads = {};

  String resolveUrl(String source) => ApiClient.instance.resolveUrl(source);

  Future<MusicMetadata> loadMetadata(String source) {
    final url = resolveUrl(source);
    final fallback = MusicMetadata(
      url: url,
      title: _titleFromUrl(source),
    );
    if (url.isEmpty) return Future.value(fallback);

    final memory = _metadataMemory[url];
    if (memory != null) return Future.value(memory);

    return _metadataRequests.putIfAbsent(url, () async {
      try {
        final cached = await _readMetadata(url);
        if (cached != null) {
          _metadataMemory[url] = cached;
          return cached;
        }

        final loaded = await _fetchMetadata(url, fallback.title);
        if (loaded.cacheable) {
          _metadataMemory[url] = loaded.metadata;
          await _writeMetadata(loaded.metadata);
        }
        return loaded.metadata;
      } finally {
        _metadataRequests.remove(url);
      }
    });
  }

  Future<MusicMetadata> readLocalMetadata(File file, {String? fallbackTitle}) async {
    final fallback = _withoutExtension(fallbackTitle ?? file.path.split('/').last);
    try {
      final bytes = await file.openRead(0, 1024 * 1024).fold<List<int>>(
        <int>[],
        (value, chunk) => value..addAll(chunk),
      );
      if (bytes.length < 10 || bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) {
        return MusicMetadata(url: '', title: fallback.isEmpty ? '未知歌曲' : fallback);
      }
      final tagSize = _readSyncSafeInt(bytes, 6);
      final metadata = _readId3TextMetadata(bytes, tagSize);
      return MusicMetadata(
        url: '',
        title: metadata['title']?.isNotEmpty == true ? metadata['title']! : (fallback.isEmpty ? '未知歌曲' : fallback),
        artist: metadata['artist'] ?? '',
        coverArt: _extractApic(bytes, 10, tagSize),
      );
    } catch (_) {
      return MusicMetadata(url: '', title: fallback.isEmpty ? '未知歌曲' : fallback);
    }
  }

  Future<MusicLyrics?> loadLyrics(String source) {
    final url = resolveUrl(source);
    if (url.isEmpty) return Future.value(null);

    final memory = _lyricsMemory[url];
    if (memory != null) return Future.value(memory);

    return _lyricsRequests.putIfAbsent(url, () async {
      try {
        final key = 'lyrics:$url';
        final cached = await lyricsCache.getFileFromCache(key);
        final file = cached?.file ??
            await lyricsCache.getSingleFile(
              url,
              key: key,
            );
        final bytes = await file.readAsBytes();
        final content = utf8.decode(bytes, allowMalformed: true).replaceFirst('\uFEFF', '');
        final lyrics = _parseLyrics(content);
        _lyricsMemory[url] = lyrics;
        return lyrics;
      } catch (_) {
        return null;
      } finally {
        _lyricsRequests.remove(url);
      }
    });
  }

  Future<File?> getCachedAudio(String source) async {
    final url = resolveUrl(source);
    if (url.isEmpty) return null;
    return (await audioCache.getFileFromCache(url))?.file;
  }

  Future<File> getPersistentStreamCacheFile(String source) async {
    final url = resolveUrl(source);
    final supportDirectory = await getApplicationSupportDirectory();
    final cacheDirectory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}music_audio_cache',
    );
    await cacheDirectory.create(recursive: true);
    return File(
      '${cacheDirectory.path}${Platform.pathSeparator}${_stableUrlHash(url)}.audio',
    );
  }

  Future<void> preloadAudio(String source) async {
    final url = resolveUrl(source);
    if (url.isEmpty) return;
    if (await audioCache.getFileFromCache(url) != null) return;

    final request = _audioDownloads.putIfAbsent(
      url,
      () => audioCache.getSingleFile(url, key: url),
    );
    try {
      await request;
    } catch (_) {
    } finally {
      _audioDownloads.remove(url);
    }
  }

  Future<MusicMetadata?> _readMetadata(String url) async {
    try {
      final info = await metadataCache.getFileFromCache('metadata:$url');
      if (info == null) return null;
      final raw = await info.file.readAsString();
      return MusicMetadata.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMetadata(MusicMetadata metadata) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(metadata.toJson())));
    await metadataCache.putFile(
      metadata.url,
      bytes,
      key: 'metadata:${metadata.url}',
      fileExtension: 'json',
      maxAge: const Duration(days: 60),
    );
  }

  Future<_MetadataLoadResult> _fetchMetadata(
    String url,
    String fallbackTitle,
  ) async {
    var title = fallbackTitle;
    var infoLoaded = true;
    final uri = Uri.tryParse(url);
    if (uri?.queryParameters['route'] == 'file/resolve') {
      final id = int.tryParse(uri?.queryParameters['id'] ?? '') ?? 0;
      if (id > 0) {
        try {
          final result = await ApiClient.instance.get(
            'upload/info',
            query: {'id': id},
          );
          if (result.success && result.data is Map<String, dynamic>) {
            final name = (result.data as Map<String, dynamic>)['name']
                    ?.toString()
                    .trim() ??
                '';
            final resolvedTitle = _withoutExtension(name);
            if (resolvedTitle.isNotEmpty && resolvedTitle.toLowerCase() != 'index') {
              title = resolvedTitle;
            }
          } else {
            infoLoaded = false;
          }
        } catch (_) {
          infoLoaded = false;
        }
      }
    }

    final coverResult = await _fetchCoverArt(url);
    return _MetadataLoadResult(
      metadata: MusicMetadata(
        url: url,
        title: title,
        artist: '',
        coverArt: coverResult.coverArt,
      ),
      cacheable: infoLoaded && coverResult.requestCompleted,
    );
  }

  Future<_CoverLoadResult> _fetchCoverArt(String url) async {
    try {
      final response = await ApiClient.instance.rawGet(
        url,
        headers: {'Range': 'bytes=0-9'},
      );
      if (response.statusCode != 206 && response.statusCode != 200) {
        return const _CoverLoadResult(requestCompleted: false);
      }

      final header = response.data ?? const <int>[];
      if (header.length < 10 ||
          header[0] != 0x49 ||
          header[1] != 0x44 ||
          header[2] != 0x33) {
        return const _CoverLoadResult(requestCompleted: true);
      }

      var tagSize = 0;
      for (var index = 6; index < 10; index++) {
        tagSize = (tagSize << 7) | (header[index] & 0x7F);
      }
      if (tagSize <= 0) {
        return const _CoverLoadResult(requestCompleted: true);
      }
      if (tagSize > 1024 * 1024) tagSize = 1024 * 1024;

      List<int> tagData = header;
      if (header.length < 10 + tagSize) {
        final response = await ApiClient.instance.rawGet(
          url,
          headers: {'Range': 'bytes=0-${9 + tagSize}'},
        );
        if (response.statusCode != 206 && response.statusCode != 200) {
          return const _CoverLoadResult(requestCompleted: false);
        }
        tagData = response.data ?? const <int>[];
      }
      if (tagData.length < 10) {
        return const _CoverLoadResult(requestCompleted: false);
      }

      return _CoverLoadResult(
        requestCompleted: true,
        coverArt: _extractApic(tagData, 10, tagSize),
      );
    } catch (_) {
      return const _CoverLoadResult(requestCompleted: false);
    }
  }

  Uint8List? _extractApic(List<int> data, int offset, int tagSize) {
    final expectedEnd = offset + tagSize;
    final end = expectedEnd < data.length ? expectedEnd : data.length;
    var position = offset;
    final versionMajor = data[3];

    if ((data[5] & 0x40) != 0 && position + 4 <= end) {
      final extendedSize = versionMajor >= 4
          ? _readSyncSafeInt(data, position)
          : _readBigEndianInt(data, position);
      position += versionMajor >= 4 ? extendedSize : extendedSize + 4;
    }

    if (versionMajor == 2) {
      return _extractId3v22Cover(data, position, end);
    }

    while (position + 10 <= end) {
      final frameId = String.fromCharCodes(data.sublist(position, position + 4));
      final frameSize = versionMajor >= 4
          ? _readSyncSafeInt(data, position + 4)
          : _readBigEndianInt(data, position + 4);
      if (frameSize <= 0) break;

      final frameStart = position + 10;
      final frameEnd = frameStart + frameSize;
      if (frameEnd > end) break;

      if (frameId == 'APIC') {
        final frameData = data.sublist(frameStart, frameEnd);
        if (frameData.length < 2) break;

        var pictureOffset = 1;
        while (pictureOffset < frameData.length && frameData[pictureOffset] != 0) {
          pictureOffset++;
        }
        pictureOffset += 2;
        if (pictureOffset >= frameData.length) break;
        return _extractPictureBytes(frameData, pictureOffset);
      }

      position += 10 + frameSize;
    }
    return null;
  }

  Map<String, String> _readId3TextMetadata(List<int> data, int tagSize) {
    if (data.length < 10) return const {};
    final end = (10 + tagSize).clamp(10, data.length);
    final version = data[3];
    var position = 10;
    final values = <String, String>{};
    while (position + 10 <= end && version >= 3) {
      final id = String.fromCharCodes(data.sublist(position, position + 4));
      final size = version >= 4 ? _readSyncSafeInt(data, position + 4) : _readBigEndianInt(data, position + 4);
      if (size <= 0 || position + 10 + size > end) break;
      if (id == 'TIT2' || id == 'TPE1') {
        final text = _decodeId3Text(data.sublist(position + 10, position + 10 + size));
        if (text.isNotEmpty) values[id == 'TIT2' ? 'title' : 'artist'] = text;
      }
      position += 10 + size;
    }
    return values;
  }

  String _decodeId3Text(List<int> value) {
    if (value.length < 2) return '';
    final encoding = value.first;
    final content = value.sublist(1);
    try {
      if (encoding == 0 || encoding == 3) return utf8.decode(content, allowMalformed: true).replaceAll('\u0000', '').trim();
      final codeUnits = <int>[];
      for (var i = 0; i + 1 < content.length; i += 2) {
        codeUnits.add(encoding == 2 ? (content[i] << 8) | content[i + 1] : content[i] | (content[i + 1] << 8));
      }
      return String.fromCharCodes(codeUnits).replaceAll('\u0000', '').trim();
    } catch (_) {
      return '';
    }
  }

  Uint8List? _extractId3v22Cover(List<int> data, int offset, int end) {
    var position = offset;
    while (position + 6 <= end) {
      final frameId = String.fromCharCodes(data.sublist(position, position + 3));
      final frameSize = (data[position + 3] << 16) |
          (data[position + 4] << 8) |
          data[position + 5];
      if (frameSize <= 0) break;

      final frameStart = position + 6;
      final frameEnd = frameStart + frameSize;
      if (frameEnd > end) break;

      if (frameId == 'PIC') {
        final frameData = data.sublist(frameStart, frameEnd);
        if (frameData.length <= 5) return null;
        return _extractPictureBytes(frameData, 5);
      }
      position = frameEnd;
    }
    return null;
  }

  Uint8List? _extractPictureBytes(List<int> frameData, int offset) {
    if (frameData.isEmpty || offset >= frameData.length) return null;

    final encoding = frameData[0];
    var pictureOffset = offset;
    if (encoding == 0x00 || encoding == 0x03) {
      while (pictureOffset < frameData.length && frameData[pictureOffset] != 0) {
        pictureOffset++;
      }
      pictureOffset++;
    } else {
      while (pictureOffset + 1 < frameData.length &&
          !(frameData[pictureOffset] == 0 && frameData[pictureOffset + 1] == 0)) {
        pictureOffset += 2;
      }
      pictureOffset += 2;
    }

    if (pictureOffset >= frameData.length) return null;
    return Uint8List.fromList(frameData.sublist(pictureOffset));
  }

  int _readBigEndianInt(List<int> data, int offset) {
    if (offset + 4 > data.length) return 0;
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  int _readSyncSafeInt(List<int> data, int offset) {
    if (offset + 4 > data.length) return 0;
    return ((data[offset] & 0x7F) << 21) |
        ((data[offset + 1] & 0x7F) << 14) |
        ((data[offset + 2] & 0x7F) << 7) |
        (data[offset + 3] & 0x7F);
  }

  MusicLyrics _parseLyrics(String content) {
    final timestampPattern = RegExp(r'\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]');
    final offsetPattern = RegExp(r'^\[offset:([+-]?\d+)\]$', caseSensitive: false);
    final timedLines = <MusicLyricLine>[];
    final plainLines = <MusicLyricLine>[];
    var offset = Duration.zero;

    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final offsetMatch = offsetPattern.firstMatch(line);
      if (offsetMatch != null) {
        offset = Duration(milliseconds: int.tryParse(offsetMatch.group(1) ?? '') ?? 0);
        continue;
      }

      final matches = timestampPattern.allMatches(line).toList();
      final text = line.replaceAll(timestampPattern, '').trim();
      if (matches.isEmpty) {
        if (!RegExp(r'^\[[a-z]+:', caseSensitive: false).hasMatch(line)) {
          plainLines.add(MusicLyricLine(timestamp: null, text: line));
        }
        continue;
      }

      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final fractionText = match.group(3) ?? '';
        var milliseconds = 0;
        if (fractionText.length == 1) {
          milliseconds = (int.tryParse(fractionText) ?? 0) * 100;
        } else if (fractionText.length == 2) {
          milliseconds = (int.tryParse(fractionText) ?? 0) * 10;
        } else if (fractionText.isNotEmpty) {
          milliseconds = int.tryParse(fractionText.substring(0, 3)) ?? 0;
        }
        var timestamp = Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: milliseconds,
            ) +
            offset;
        if (timestamp.isNegative) timestamp = Duration.zero;
        timedLines.add(
          MusicLyricLine(
            timestamp: timestamp,
            text: text.isEmpty ? '…' : text,
          ),
        );
      }
    }

    if (timedLines.isNotEmpty) {
      timedLines.sort((left, right) => left.timestamp!.compareTo(right.timestamp!));
      return MusicLyrics(lines: List.unmodifiable(timedLines), synchronized: true);
    }
    return MusicLyrics(lines: List.unmodifiable(plainLines), synchronized: false);
  }

  String _titleFromUrl(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null) return '音乐';
    final queryName = uri.queryParameters['filename'] ?? uri.queryParameters['name'];
    final rawName = queryName?.trim().isNotEmpty == true
        ? queryName!
        : uri.path.split('/').last;
    final title = _withoutExtension(rawName);
    return title.isEmpty || title.toLowerCase() == 'index' ? '音乐' : title;
  }

  String _withoutExtension(String value) {
    String decoded;
    try {
      decoded = Uri.decodeComponent(value);
    } catch (_) {
      decoded = value;
    }
    final name = decoded.split('/').last.trim();
    if (name.isEmpty) return '';
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String _stableUrlHash(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _MetadataLoadResult {
  final MusicMetadata metadata;
  final bool cacheable;

  const _MetadataLoadResult({required this.metadata, required this.cacheable});
}

class _CoverLoadResult {
  final bool requestCompleted;
  final Uint8List? coverArt;

  const _CoverLoadResult({required this.requestCompleted, this.coverArt});
}
