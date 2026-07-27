import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music.dart';
import '../utils/file_name.dart';
import 'music_api_service.dart';

final musicDownloadProvider =
    ChangeNotifierProvider<MusicDownloadService>((ref) {
  final service = MusicDownloadService.instance;
  unawaited(service.init());
  return service;
});

enum MusicDownloadStatus {
  resolving,
  downloading,
  tagging,
  completed,
  failed,
  cancelled,
}

class MusicDownloadEntry {
  MusicDownloadEntry({
    required this.track,
    this.status = MusicDownloadStatus.resolving,
    this.progress = 0,
    this.audioPath,
    this.lrcPath,
    this.audioContentUri,
    this.displayPath,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final MusicTrack track;
  final DateTime createdAt;
  MusicDownloadStatus status;
  double progress;
  String? audioPath;
  String? lrcPath;
  String? audioContentUri;
  String? displayPath;
  String? error;
  CancelToken? cancelToken;

  bool get active =>
      status == MusicDownloadStatus.resolving ||
      status == MusicDownloadStatus.downloading ||
      status == MusicDownloadStatus.tagging;

  Map<String, dynamic> toJson() => {
        'track': track.toJson(),
        'created_at': createdAt.toIso8601String(),
        'status': status.name,
        'audio_path': audioPath,
        'lrc_path': lrcPath,
        'audio_content_uri': audioContentUri,
        'display_path': displayPath,
        'error': error,
      };

  static MusicDownloadEntry? fromJson(dynamic value) {
    if (value is! Map) return null;
    final track = MusicTrack.fromJson(value['track']);
    if (track == null) return null;
    var status = MusicDownloadStatus.values.firstWhere(
      (item) => item.name == value['status']?.toString(),
      orElse: () => MusicDownloadStatus.failed,
    );
    if (status == MusicDownloadStatus.resolving ||
        status == MusicDownloadStatus.downloading ||
        status == MusicDownloadStatus.tagging) {
      status = MusicDownloadStatus.failed;
    }
    return MusicDownloadEntry(
      track: track,
      createdAt: DateTime.tryParse(value['created_at']?.toString() ?? ''),
      status: status,
      progress: status == MusicDownloadStatus.completed ? 1 : 0,
      audioPath: value['audio_path']?.toString(),
      lrcPath: value['lrc_path']?.toString(),
      audioContentUri: value['audio_content_uri']?.toString(),
      displayPath: value['display_path']?.toString(),
      error: status == MusicDownloadStatus.failed
          ? (value['error']?.toString() ?? '上次下载未完成')
          : value['error']?.toString(),
    );
  }
}

class MusicDownloadService extends ChangeNotifier {
  MusicDownloadService._();

  static final instance = MusicDownloadService._();
  static const _historyKey = 'qingtan_music_downloads_v1';
  static const _channel = MethodChannel('com.qingtan.music/file_actions');

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; QingTanMusic) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36',
      },
    ),
  );
  final Map<String, MusicDownloadEntry> _entries = {};
  Future<void>? _initializing;

  List<MusicDownloadEntry> get entries {
    final result = _entries.values.toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  MusicDownloadEntry? entryFor(MusicTrack track) => _entries[track.key];

  Future<void> init() => _initializing ??= _restore();

  Future<MusicDownloadEntry> download(MusicTrack track) async {
    await init();
    final existing = _entries[track.key];
    if (existing != null && existing.active) return existing;
    if (existing?.status == MusicDownloadStatus.completed &&
        existing?.audioPath != null &&
        await File(existing!.audioPath!).exists()) {
      return existing;
    }

    final entry = MusicDownloadEntry(track: track);
    final cancelToken = CancelToken();
    entry.cancelToken = cancelToken;
    _entries[track.key] = entry;
    notifyListeners();
    unawaited(_persist());

    File? partFile;
    try {
      await _ensureStoragePermission();
      final directory = await _privateDownloadDirectory();
      final audioUrl = await MusicApiService.instance.resolveAudioUrl(track);
      if (cancelToken.isCancelled) {
        throw DioException(
          requestOptions: RequestOptions(path: audioUrl),
          type: DioExceptionType.cancel,
          error: 'cancelled',
        );
      }

      entry.status = MusicDownloadStatus.downloading;
      notifyListeners();
      final partName = '${track.source}_${track.id.hashCode.abs()}.download';
      partFile = File('${directory.path}/$partName');
      final response = await _dio.download(
        audioUrl,
        partFile.path,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) entry.progress = received / total;
          notifyListeners();
        },
      );

      final extension = await detectAudioExtension(
        partFile,
        contentType: response.headers.value('content-type'),
        resolvedUrl: response.realUri.toString(),
      );
      final baseName = buildDownloadBaseName(track.title, track.artist);
      final audioFile = File('${directory.path}/$baseName.$extension');
      final lrcFile = File('${directory.path}/$baseName.lrc');
      if (await audioFile.exists()) await audioFile.delete();
      if (await lrcFile.exists()) await lrcFile.delete();
      await partFile.rename(audioFile.path);
      partFile = null;

      entry.status = MusicDownloadStatus.tagging;
      entry.progress = 1;
      notifyListeners();
      final lyrics = await MusicApiService.instance.lyrics(track);
      final lyricText = lyrics.preferred;
      final cover = await MusicApiService.instance.coverBytes(track);
      final tagged = await writeMetadataAsync(
        path: audioFile.path,
        title: track.title,
        artist: track.artist,
        album: track.album,
        albumArtist: track.artist,
        lyrics: lyricText,
        pictureBytes: cover,
      );
      if (!tagged) throw const FileSystemException('无法写入音频标签');
      await lrcFile.writeAsString(lyricText, flush: true);

      final audioPublish = await _publish(audioFile, audioFile.uri.pathSegments.last);
      await _publish(lrcFile, lrcFile.uri.pathSegments.last);
      entry
        ..status = MusicDownloadStatus.completed
        ..audioPath = audioFile.path
        ..lrcPath = lrcFile.path
        ..audioContentUri = audioPublish['uri']?.toString()
        ..displayPath = audioPublish['displayPath']?.toString()
        ..error = null;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        entry.status = MusicDownloadStatus.cancelled;
        entry.error = null;
      } else {
        entry.status = MusicDownloadStatus.failed;
        entry.error = '下载失败：${error.message ?? '网络错误'}';
      }
    } catch (error) {
      entry.status = MusicDownloadStatus.failed;
      entry.error = error is MusicApiException ? error.message : '下载处理失败：$error';
    } finally {
      if (partFile != null && await partFile.exists()) await partFile.delete();
      entry.cancelToken = null;
      notifyListeners();
      await _persist();
    }
    return entry;
  }

  void cancel(MusicTrack track) {
    final entry = _entries[track.key];
    if (entry == null || !entry.active) return;
    entry.cancelToken?.cancel('user cancelled');
  }

  Future<void> retry(MusicDownloadEntry entry) async {
    _entries.remove(entry.track.key);
    notifyListeners();
    await download(entry.track);
  }

  Future<void> open(MusicDownloadEntry entry) async {
    if (entry.audioPath == null) return;
    await _channel.invokeMethod<dynamic>('openFile', {
      'path': entry.audioPath,
      'contentUri': entry.audioContentUri,
    });
  }

  Future<void> openFolder() async {
    await _channel.invokeMethod<dynamic>('openFolder');
  }

  Future<Directory> _privateDownloadDirectory() async {
    final root = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/music');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<void> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return;
    final info = await DeviceInfoPlugin().androidInfo;
    if (info.version.sdkInt >= 29) return;
    final result = await Permission.storage.request();
    if (!result.isGranted) throw const FileSystemException('没有存储权限');
  }

  Future<Map<dynamic, dynamic>> _publish(File file, String fileName) async {
    final result = await _channel.invokeMapMethod<dynamic, dynamic>(
      'publishDownload',
      {'path': file.path, 'fileName': fileName},
    );
    return result ?? const {};
  }

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_historyKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final value in decoded) {
        final entry = MusicDownloadEntry.fromJson(value);
        if (entry != null) _entries[entry.track.key] = entry;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _historyKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }
}

Future<String> detectAudioExtension(
  File file, {
  String? contentType,
  String? resolvedUrl,
}) async {
  final mime = (contentType ?? '').split(';').first.trim().toLowerCase();
  const mimeExtensions = {
    'audio/mpeg': 'mp3',
    'audio/mp3': 'mp3',
    'audio/mp4': 'm4a',
    'audio/x-m4a': 'm4a',
    'video/mp4': 'm4a',
    'audio/flac': 'flac',
    'audio/x-flac': 'flac',
    'audio/ogg': 'ogg',
    'application/ogg': 'ogg',
    'audio/aac': 'aac',
    'audio/aacp': 'aac',
  };
  final mimeExtension = mimeExtensions[mime];
  if (mimeExtension != null) return mimeExtension;

  final handle = await file.open();
  final bytes = await handle.read(16);
  await handle.close();
  if (bytes.length >= 3 && String.fromCharCodes(bytes.take(3)) == 'ID3') {
    return 'mp3';
  }
  if (bytes.length >= 4 && String.fromCharCodes(bytes.take(4)) == 'fLaC') {
    return 'flac';
  }
  if (bytes.length >= 4 && String.fromCharCodes(bytes.take(4)) == 'OggS') {
    return 'ogg';
  }
  if (bytes.length >= 8 && String.fromCharCodes(bytes.skip(4).take(4)) == 'ftyp') {
    return 'm4a';
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF) {
    if ((bytes[1] & 0xF6) == 0xF0) return 'aac';
    if ((bytes[1] & 0xE0) == 0xE0) return 'mp3';
  }

  final path = Uri.tryParse(resolvedUrl ?? '')?.path.toLowerCase() ?? '';
  for (final extension in const ['mp3', 'm4a', 'mp4', 'flac', 'ogg', 'aac', 'm4s']) {
    if (path.endsWith('.$extension')) {
      return extension == 'mp4' || extension == 'm4s' ? 'm4a' : extension;
    }
  }
  return 'mp3';
}
