import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
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
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.waiting,
    this.error,
    this.cancelToken,
    List<DownloadChunk>? chunks,
  })  : chunks = chunks ?? [],
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

  final Dio _dio = Dio();
  final Map<String, DownloadTask> _tasks = {};

  DownloadService._();

  static final DownloadService instance = DownloadService._();

  Map<String, DownloadTask> get tasks => _tasks;

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
    void Function(double progress)? onProgress,
  }) async {
    final id = taskId ?? url.hashCode.toRadixString(16);

    // 已存在任务
    if (_tasks.containsKey(id)) {
      final existing = _tasks[id]!;
      if (existing.status == DownloadStatus.completed) {
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
    );

    _tasks[id] = task;

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
      task.updateProgress(1.0);
      await _saveHistory(task);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        task.status = DownloadStatus.paused;
      } else {
        task.status = DownloadStatus.failed;
        task.error = e.toString();
      }
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
      task.updateProgress(1.0);
      await _saveHistory(task);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        task.status = DownloadStatus.paused;
      } else {
        task.status = DownloadStatus.failed;
        task.error = e.toString();
      }
    }
  }

  /// 取消下载
  void cancel(String taskId) {
    final task = _tasks[taskId];
    if (task == null) return;
    task.cancelToken?.cancel('user cancelled');
    task.dispose();
    _tasks.remove(taskId);
  }

  /// 打开已下载文件，返回结果消息
  Future<String> openFile(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.completed) {
      return '文件不存在';
    }
    try {
      final result = await OpenFile.open(task.savePath);
      if (result.type == ResultType.done) {
        return '已打开';
      }
      return '无法打开: ${result.message}';
    } catch (e) {
      return '打开失败: $e';
    }
  }

  /// 保存下载历史
  Future<void> _saveHistory(DownloadTask task) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_historyKey) ?? [];
      history.add('${task.id}|${task.url}|${task.fileName}|${task.savePath}');
      if (history.length > 100) history.removeAt(0);
      await prefs.setStringList(_historyKey, history);
    } catch (_) {}
  }
}
