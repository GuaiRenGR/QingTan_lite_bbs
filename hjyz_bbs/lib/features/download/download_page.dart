import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/download_service.dart';
import '../../core/theme/app_colors.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  Timer? _timer;
  final Map<String, StreamSubscription<double>> _subs = {};

  @override
  void initState() {
    super.initState();
    _listenAll();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _listenAll() {
    final tasks = DownloadService.instance.tasks;
    for (final entry in tasks.entries) {
      _listenTask(entry.key);
    }
  }

  void _listenTask(String id) {
    if (_subs.containsKey(id)) return;
    final task = DownloadService.instance.tasks[id];
    if (task == null) return;
    _subs[id] = task.progressStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final sub in _subs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  String _statusText(DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.waiting:
        return '等待中';
      case DownloadStatus.downloading:
        return '${(task.progress * 100).toInt()}%';
      case DownloadStatus.paused:
        return '已暂停';
      case DownloadStatus.completed:
        return '已完成';
      case DownloadStatus.failed:
        return '失败: ${task.error ?? "未知错误"}';
    }
  }

  IconData _statusIcon(DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.waiting:
        return Icons.hourglass_empty_rounded;
      case DownloadStatus.downloading:
        return Icons.downloading_rounded;
      case DownloadStatus.paused:
        return Icons.pause_circle_outline_rounded;
      case DownloadStatus.completed:
        return Icons.check_circle_outline_rounded;
      case DownloadStatus.failed:
        return Icons.error_outline_rounded;
    }
  }

  Color _statusColor(DownloadTask task) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return const Color(0xFFFB7299);
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red.shade400;
      default:
        return Colors.grey;
    }
  }

  Widget _buildActions(DownloadTask task) {
    final service = DownloadService.instance;

    switch (task.status) {
      case DownloadStatus.downloading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.pause_rounded),
              tooltip: '暂停',
              onPressed: () {
                service.pause(task.id);
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: '取消',
              onPressed: () {
                service.cancel(task.id);
                _subs.remove(task.id)?.cancel();
                setState(() {});
              },
            ),
          ],
        );
      case DownloadStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded),
              tooltip: '继续',
              onPressed: () {
                service.resume(task.id);
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: '取消',
              onPressed: () {
                service.cancel(task.id);
                _subs.remove(task.id)?.cancel();
                setState(() {});
              },
            ),
          ],
        );
      case DownloadStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded),
              tooltip: '打开',
              onPressed: () => service.openFile(task.id),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: '移除',
              onPressed: () {
                service.cancel(task.id);
                _subs.remove(task.id)?.cancel();
                setState(() {});
              },
            ),
          ],
        );
      case DownloadStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '重试',
              onPressed: () {
                service.cancel(task.id);
                _subs.remove(task.id)?.cancel();
                service.download(
                  url: task.url,
                  fileName: task.fileName,
                  taskId: task.id,
                );
                _listenTask(task.id);
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: '移除',
              onPressed: () {
                service.cancel(task.id);
                _subs.remove(task.id)?.cancel();
                setState(() {});
              },
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = DownloadService.instance.tasks;
    final entries = tasks.entries.toList()
      ..sort((a, b) => a.value.status == DownloadStatus.downloading ? -1 : 1);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        title: const Text('下载管理'),
        actions: [
          if (tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清除已完成',
              onPressed: () {
                final completed = tasks.entries
                    .where((e) => e.value.status == DownloadStatus.completed)
                    .toList();
                for (final e in completed) {
                  DownloadService.instance.cancel(e.key);
                  _subs.remove(e.key)?.cancel();
                }
                setState(() {});
              },
            ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_download_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无下载任务',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '在帖子中点击附件下载按钮开始下载',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final task = entry.value;
                _listenTask(entry.key);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 文件名 + 状态图标
                      Row(
                        children: [
                          Icon(
                            _statusIcon(task),
                            size: 20,
                            color: _statusColor(task),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              task.fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 进度条
                      if (task.status == DownloadStatus.downloading ||
                          task.status == DownloadStatus.paused)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: task.progress,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            color: _statusColor(task),
                          ),
                        ),
                      if (task.status == DownloadStatus.downloading ||
                          task.status == DownloadStatus.paused)
                        const SizedBox(height: 8),

                      // 大小 + 状态文字 + 操作按钮
                      Row(
                        children: [
                          if (task.totalBytes > 0)
                            Text(
                              '${_formatBytes(task.downloadedBytes)} / ${_formatBytes(task.totalBytes)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          if (task.totalBytes > 0) const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _statusText(task),
                              style: TextStyle(
                                fontSize: 12,
                                color: _statusColor(task),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildActions(task),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
