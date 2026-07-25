import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 下载任务状态
enum DownloadStatus { waiting, downloading, paused, completed, failed }

/// 单个下载任务
class DownloadTask {
  final String id;
  final String url;
  final String fileName;
  final String savePath;
  final bool openOnComplete;
  final DateTime createdAt;
  String? contentUri;
  String? displayPath;
  int totalBytes;
  int downloadedBytes;
  DownloadStatus status;
  String? error;
  CancelToken? cancelToken;
  final List<DownloadChunk> chunks;
  final StreamController<double> _progressController;

  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    required this.savePath,
    this.openOnComplete = false,
    DateTime? createdAt,
    this.contentUri,
    this.displayPath,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.waiting,
    this.error,
    this.cancelToken,
    List<DownloadChunk>? chunks,
  })  : createdAt = createdAt ?? DateTime.now(),
        chunks = chunks ?? [],
        _progressController = StreamController<double>.broadcast();

  double get progress =>
      totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

  Stream<double> get progressStream => _progressController.stream;

  void updateProgress(double p) {
    _progressController.add(p);
  }

  void dispose() {
    _progressController.close();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'file_name': fileName,
        'save_path': savePath,
        'open_on_complete': openOnComplete,
        'created_at': createdAt.toIso8601String(),
        'content_uri': contentUri,
        'display_path': displayPath,
        'total_bytes': totalBytes,
        'downloaded_bytes': downloadedBytes,
        'status': status.name,
        'error': error,
      };

  static DownloadTask? fromJson(dynamic value) {
    if (value is! Map) return null;
    final id = value['id']?.toString() ?? '';
    final url = value['url']?.toString() ?? '';
    final fileName = value['file_name']?.toString() ?? '';
    final savePath = value['save_path']?.toString() ?? '';
    if (id.isEmpty || fileName.isEmpty || savePath.isEmpty) return null;

    final restoredStatus = DownloadStatus.values.firstWhere(
      (item) => item.name == value['status']?.toString(),
      orElse: () => DownloadStatus.completed,
    );
    return DownloadTask(
      id: id,
      url: url,
      fileName: fileName,
      savePath: savePath,
      openOnComplete: value['open_on_complete'] == true,
      createdAt: DateTime.tryParse(value['created_at']?.toString() ?? ''),
      contentUri: value['content_uri']?.toString(),
      displayPath: value['display_path']?.toString(),
      totalBytes: int.tryParse(value['total_bytes']?.toString() ?? '') ?? 0,
      downloadedBytes:
          int.tryParse(value['downloaded_bytes']?.toString() ?? '') ?? 0,
      status: restoredStatus == DownloadStatus.downloading ||
              restoredStatus == DownloadStatus.waiting
          ? DownloadStatus.paused
          : restoredStatus,
      error: value['error']?.toString(),
    );
  }
}

class DownloadChunk {
  final int start;
  final int end;
  int downloaded;

  DownloadChunk({
    required this.start,
    required this.end,
    this.downloaded = 0,
  });
}

/// 内置多线程下载服务
class DownloadService {
  static const _chunkCount = 4;
  static const _historyKey = 'download_history';
  static const _androidChannel = MethodChannel(
    'com.qingtan.hjyzbbs/file_actions',
  );

  final Dio _dio = Dio();
  final Map<String, DownloadTask> _tasks = {};
  Future<void>? _initializing;

  DownloadService._();

  static final DownloadService instance = DownloadService._();

  Map<String, DownloadTask> get tasks => _tasks;

  Future<void> init() {
    return _initializing ??= _loadHistory();
  }

  /// 获取下载目录
  Future<Directory> getDownloadDir() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) return dir;
    }
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  /// 请求存储权限（桌面平台直接返回 true）
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      // Android 使用 getExternalStorageDirectory 无需额外权限
      // Android 10+ 的 Scoped Storage 机制会自动处理
    }
    return true;
  }

  /// 开始下载
  Future<DownloadTask> download({
    required String url,
    required String fileName,
    String? taskId,
    bool openOnComplete = false,
    void Function(double progress)? onProgress,
  }) async {
    await init();
    final id = taskId ?? url.hashCode.toRadixString(16);

    // 已存在任务
    if (_tasks.containsKey(id)) {
      final existing = _tasks[id]!;
      if (existing.status == DownloadStatus.completed) {
        if (openOnComplete) await openFile(existing.id);
        return existing;
      }
      if (existing.status == DownloadStatus.paused) {
        resume(id);
        return existing;
      }
    }

    final dir = await getDownloadDir();
    final savePath = '${dir.path}/$fileName';

    final task = DownloadTask(
      id: id,
      url: url,
      fileName: fileName,
      savePath: savePath,
      openOnComplete: openOnComplete,
    );

    _tasks[id] = task;
    await _persistTasks();

    if (onProgress != null) {
      task.progressStream.listen(onProgress);
    }

    try {
      // 获取文件大小
      final headResp = await _dio.head(url);
      final contentLength =
          int.tryParse(headResp.headers.value('content-length') ?? '0') ?? 0;
      task.totalBytes = contentLength;

      if (contentLength > 0) {
        // 多线程分片下载
        await _downloadMultiChunk(task);
      } else {
        // 单线程下载
        await _downloadSingle(task);
      }

      task.status = DownloadStatus.completed;
      task.downloadedBytes = task.totalBytes;
      task.updateProgress(1.0);
      await _publishToAndroidDownloads(task);
      await _persistTasks();

      // 完成后自动打开
      if (task.openOnComplete) {
        await openFile(task.id);
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        task.status = DownloadStatus.paused;
      } else {
        task.status = DownloadStatus.failed;
        task.error = e.toString();
      }
      await _persistTasks();
    }

    return task;
  }

  /// 多线程分片下载
  Future<void> _downloadMultiChunk(DownloadTask task) async {
    final totalBytes = task.totalBytes;
    final chunkSize = totalBytes ~/ _chunkCount;
    final cancelToken = CancelToken();
    task.cancelToken = cancelToken;

    task.chunks.clear();
    for (int i = 0; i < _chunkCount; i++) {
      final start = i * chunkSize;
      final end = (i == _chunkCount - 1) ? totalBytes - 1 : start + chunkSize - 1;
      task.chunks.add(DownloadChunk(start: start, end: end));
    }

    task.status = DownloadStatus.downloading;

    // 并发下载各分片
    final tempDir = await getTemporaryDirectory();
    final futures = <Future>[];

    for (int i = 0; i < task.chunks.length; i++) {
      final chunk = task.chunks[i];
      final tempPath = '${tempDir.path}/${task.id}_chunk_$i';
      futures.add(_downloadChunk(task, chunk, tempPath, cancelToken));
    }

    await Future.wait(futures);

    // 合并分片
    final outputFile = File(task.savePath);
    final sink = outputFile.openSync(mode: FileMode.write);

    for (int i = 0; i < task.chunks.length; i++) {
      final tempPath = '${tempDir.path}/${task.id}_chunk_$i';
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await sink.writeFrom(await tempFile.readAsBytes());
        await tempFile.delete();
      }
    }

    await sink.close();
  }

  /// 下载单个分片
  Future<void> _downloadChunk(
    DownloadTask task,
    DownloadChunk chunk,
    String tempPath,
    CancelToken cancelToken,
  ) async {
    await _dio.download(
      task.url,
      tempPath,
      options: Options(
        headers: {
          'Range': 'bytes=${chunk.start}-${chunk.end}',
        },
      ),
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        chunk.downloaded = received;
        _updateTaskProgress(task);
      },
    );
  }

  /// 单线程下载（不支持 Range 或文件太小）
  Future<void> _downloadSingle(DownloadTask task) async {
    final cancelToken = CancelToken();
    task.cancelToken = cancelToken;
    task.status = DownloadStatus.downloading;

    await _dio.download(
      task.url,
      task.savePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          task.totalBytes = total;
          task.downloadedBytes = received;
          task.updateProgress(received / total);
        }
      },
    );
  }

  /// 更新任务总进度
  void _updateTaskProgress(DownloadTask task) {
    int totalDownloaded = 0;
    for (final chunk in task.chunks) {
      totalDownloaded += chunk.downloaded;
    }
    task.downloadedBytes = totalDownloaded;
    final progress =
        task.totalBytes > 0 ? totalDownloaded / task.totalBytes : 0.0;
    task.updateProgress(progress);
  }

  /// 暂停下载
  void pause(String taskId) {
    final task = _tasks[taskId];
    if (task == null) return;
    task.cancelToken?.cancel('user paused');
    task.status = DownloadStatus.paused;
    unawaited(_persistTasks());
  }

  /// 恢复下载
  Future<void> resume(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.paused) return;

    try {
      if (task.chunks.isNotEmpty) {
        // 从断点续传
        await _downloadMultiChunk(task);
      } else {
        await _downloadSingle(task);
      }
      task.status = DownloadStatus.completed;
      task.downloadedBytes = task.totalBytes;
      task.updateProgress(1.0);
      await _publishToAndroidDownloads(task);
      await _persistTasks();

      // 完成后自动打开
      if (task.openOnComplete) {
        await openFile(task.id);
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        task.status = DownloadStatus.paused;
      } else {
        task.status = DownloadStatus.failed;
        task.error = e.toString();
      }
      await _persistTasks();
    }
  }

  /// 取消下载
  void cancel(String taskId) {
    final task = _tasks[taskId];
    if (task == null) return;
    task.cancelToken?.cancel('user cancelled');
    task.dispose();
    _tasks.remove(taskId);
    unawaited(_persistTasks());
  }

  /// 打开已下载文件，返回结果消息
  Future<String> openFile(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.completed) {
      return '文件不存在';
    }
    try {
      final file = File(task.savePath);
      if (!await file.exists() && task.contentUri == null) {
        return '文件已被删除';
      }
      if (Platform.isAndroid) {
        final response = await _androidChannel.invokeMapMethod<String, dynamic>(
          'openFile',
          {
            'path': task.savePath,
            'contentUri': task.contentUri,
          },
        );
        return response?['message']?.toString() ?? '请选择要使用的应用';
      }
      final result = await OpenFile.open(task.savePath);
      if (result.type == ResultType.done) {
        return '已打开';
      }
      return '无法打开: ${result.message}';
    } catch (e) {
      return '打开失败: $e';
    }
  }

  /// 打开文件所在文件夹，返回结果消息
  Future<String> openFolder(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.completed) {
      return '文件不存在';
    }
    try {
      final file = File(task.savePath);
      if (!await file.exists() && task.contentUri == null) {
        return '文件已被删除';
      }
      if (Platform.isAndroid) {
        await _publishToAndroidDownloads(task);
        await _persistTasks();
        final response = await _androidChannel.invokeMapMethod<String, dynamic>(
          'openFolder',
        );
        return response?['message']?.toString() ?? '已打开下载目录';
      }
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', task.savePath]);
        return '已打开文件夹';
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', task.savePath]);
        return '已打开文件夹';
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [file.parent.path]);
        return '已打开文件夹';
      }
      return '当前平台不支持打开文件夹';
    } catch (e) {
      return '打开失败: $e';
    }
  }

  Future<void> _publishToAndroidDownloads(DownloadTask task) async {
    if (!Platform.isAndroid || task.contentUri?.isNotEmpty == true) return;
    try {
      final response = await _androidChannel.invokeMapMethod<String, dynamic>(
        'publishDownload',
        {'path': task.savePath, 'fileName': task.fileName},
      );
      task.contentUri = response?['uri']?.toString();
      task.displayPath = response?['displayPath']?.toString();
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.get(_historyKey);
      if (stored is String && stored.isNotEmpty) {
        final raw = stored;
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            final task = DownloadTask.fromJson(item);
            if (task != null) _tasks[task.id] = task;
          }
        }
        return;
      }

      final legacy = stored is List
          ? stored.map((item) => item.toString()).toList()
          : const <String>[];
      for (final value in legacy) {
        final parts = value.split('|');
        if (parts.length < 4) continue;
        final task = DownloadTask(
          id: parts[0],
          url: parts[1],
          fileName: parts[2],
          savePath: parts.sublist(3).join('|'),
          status: DownloadStatus.completed,
        );
        _tasks[task.id] = task;
      }
      if (legacy.isNotEmpty) await _persistTasks();
    } catch (_) {}
  }

  Future<void> _persistTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = _tasks.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final trimmed = history.length > 100
          ? history.sublist(history.length - 100)
          : history;
      await prefs.remove(_historyKey);
      await prefs.setString(
        _historyKey,
        jsonEncode(trimmed.map((task) => task.toJson()).toList()),
      );
    } catch (_) {}
  }
}
