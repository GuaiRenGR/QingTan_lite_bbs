import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'music_player_controller.dart';

class MusicPlayerPage extends ConsumerWidget {
  const MusicPlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final current = state.currentTrack;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        title: const Text('音乐播放器'),
        actions: [
          if (state.playlist.isNotEmpty)
            IconButton(
              onPressed: controller.clearPlaylist,
              tooltip: '清空播放列表',
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: state.playlist.isEmpty || current == null
          ? const _EmptyPlaylist()
          : SafeArea(
              child: Column(
                children: [
                  _NowPlaying(
                    state: state,
                    onSeek: controller.seek,
                    onPrevious: controller.playPrevious,
                    onToggle: controller.toggle,
                    onNext: controller.playNext,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 6),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '播放列表',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${state.playlist.length} 首',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: state.playlist.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final track = state.playlist[index];
                        final selected = index == state.currentIndex;
                        return Material(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.55)
                              : AppColors.card(context),
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            onTap: () => controller.selectTrack(
                              track,
                              autoplay: true,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: _TrackCover(track: track, size: 46),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: selected
                                ? Text(state.playing ? '正在播放' : '已暂停')
                                : null,
                            trailing: IconButton(
                              onPressed: () => controller.removeAt(index),
                              tooltip: '从播放列表移除',
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  final MusicPlayerState state;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;

  const _NowPlaying({
    required this.state,
    required this.onSeek,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
  });

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final track = state.currentTrack!;
    final screenSize = MediaQuery.sizeOf(context);
    final coverSize = max(
      96.0,
      min(screenSize.width - 96, min(230.0, screenSize.height * 0.28)),
    );
    final maxMilliseconds = max(state.duration.inMilliseconds, 1);
    final positionMilliseconds = state.position.inMilliseconds
        .clamp(0, maxMilliseconds)
        .toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
      child: Column(
        children: [
          _TrackCover(track: track, size: coverSize),
          const SizedBox(height: 16),
          Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 4),
            Text(
              state.error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Slider(
            value: positionMilliseconds,
            max: maxMilliseconds.toDouble(),
            onChanged: state.duration.inMilliseconds > 0
                ? (value) => onSeek(
                      Duration(milliseconds: value.round()),
                    )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(state.position),
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11,
                  ),
                ),
                Text(
                  _formatDuration(state.duration),
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onPrevious,
                iconSize: 34,
                tooltip: '上一曲',
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 58,
                height: 58,
                child: FilledButton(
                  onPressed: state.loading ? null : onToggle,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: state.loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          state.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 34,
                        ),
                ),
              ),
              const SizedBox(width: 18),
              IconButton(
                onPressed: onNext,
                iconSize: 34,
                tooltip: '下一曲',
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackCover extends StatelessWidget {
  final MusicTrack track;
  final double size;

  const _TrackCover({required this.track, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: size * 0.38,
      ),
    );
    final coverArt = track.coverArt;
    if (coverArt == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.memory(
        coverArt,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _EmptyPlaylist extends StatelessWidget {
  const _EmptyPlaylist();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 64,
              color: AppColors.textSecondary(context),
            ),
            const SizedBox(height: 14),
            const Text(
              '播放列表为空',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '浏览帖子中的音乐卡片后，歌曲会自动加入这里',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}
