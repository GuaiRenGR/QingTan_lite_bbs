import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/music_download_service.dart';
import '../widgets/music_artwork.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(musicDownloadProvider);
    final entries = service.entries;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '下载',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => _openFolder(context, service),
                  tooltip: '打开下载目录',
                  icon: const Icon(Icons.folder_open_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      '还没有下载任务',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _DownloadTile(entry: entry, service: service);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFolder(
    BuildContext context,
    MusicDownloadService service,
  ) async {
    try {
      await service.openFolder();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开下载目录')),
      );
    }
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.entry, required this.service});

  final MusicDownloadEntry entry;
  final MusicDownloadService service;

  @override
  Widget build(BuildContext context) {
    final status = _statusText(entry);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      leading: MusicArtwork(track: entry.track, size: 52),
      title: Text(
        entry.track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: entry.status == MusicDownloadStatus.failed
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
          if (entry.status == MusicDownloadStatus.downloading)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                value: entry.progress.clamp(0.0, 1.0).toDouble(),
              ),
            ),
        ],
      ),
      trailing: _action(context),
      onTap: entry.status == MusicDownloadStatus.completed
          ? () => _open(context)
          : null,
    );
  }

  Widget _action(BuildContext context) {
    switch (entry.status) {
      case MusicDownloadStatus.resolving:
      case MusicDownloadStatus.downloading:
        return IconButton(
          onPressed: () => service.cancel(entry.track),
          tooltip: '取消',
          icon: const Icon(Icons.close_rounded),
        );
      case MusicDownloadStatus.tagging:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case MusicDownloadStatus.completed:
        return IconButton(
          onPressed: () => _open(context),
          tooltip: '打开',
          icon: const Icon(Icons.open_in_new_rounded),
        );
      case MusicDownloadStatus.failed:
      case MusicDownloadStatus.cancelled:
        return IconButton(
          onPressed: () => service.retry(entry),
          tooltip: '重试',
          icon: const Icon(Icons.refresh_rounded),
        );
    }
  }

  Future<void> _open(BuildContext context) async {
    try {
      await service.open(entry);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开文件')),
      );
    }
  }

  String _statusText(MusicDownloadEntry entry) {
    switch (entry.status) {
      case MusicDownloadStatus.resolving:
        return '正在获取标准音质地址';
      case MusicDownloadStatus.downloading:
        return '下载中 ${(entry.progress * 100).clamp(0, 100).round()}%';
      case MusicDownloadStatus.tagging:
        return '正在写入歌曲信息、封面和歌词';
      case MusicDownloadStatus.completed:
        return entry.displayPath ?? '已下载';
      case MusicDownloadStatus.failed:
        return entry.error ?? '下载失败';
      case MusicDownloadStatus.cancelled:
        return '已取消';
    }
  }
}
