import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/music_player_controller.dart';
import '../models/music.dart';
import '../services/music_api_service.dart';
import '../services/music_download_service.dart';
import '../utils/lrc.dart';
import '../widgets/music_artwork.dart';

class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);
    final track = state.currentTrack;
    if (track == null) {
      return const SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.headphones_rounded, size: 62),
              SizedBox(height: 14),
              Text('还没有播放歌曲'),
            ],
          ),
        ),
      );
    }

    final controller = ref.read(musicPlayerProvider.notifier);
    final downloads = ref.watch(musicDownloadProvider);
    final download = downloads.entryFor(track);
    final durationMs = math.max(1, state.duration.inMilliseconds);
    final positionMs = state.position.inMilliseconds.clamp(0, durationMs).toInt();
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '正在播放',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: download?.active == true ||
                          download?.status == MusicDownloadStatus.completed
                      ? null
                      : () {
                          downloads.download(track);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('开始下载：${track.title}')),
                          );
                        },
                  tooltip: download?.status == MusicDownloadStatus.completed
                      ? '已下载'
                      : '下载标准音质',
                  icon: download?.active == true
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          download?.status == MusicDownloadStatus.completed
                              ? Icons.download_done_rounded
                              : Icons.download_rounded,
                        ),
                ),
                IconButton(
                  onPressed: () => _showPlaylist(context),
                  tooltip: '播放列表',
                  icon: const Icon(Icons.queue_music_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: '封面'),
                      Tab(text: '歌词'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _ArtworkView(track: track),
                        _LyricsView(
                          key: ValueKey(track.key),
                          track: track,
                          position: state.position,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
            child: Column(
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  track.artist.isEmpty ? '未知歌手' : track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: positionMs.toDouble(),
                  max: durationMs.toDouble(),
                  onChanged: state.duration == Duration.zero
                      ? null
                      : (value) => controller.seek(
                            Duration(milliseconds: value.round()),
                          ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_duration(state.position)),
                    Text(_duration(state.duration)),
                  ],
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      state.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                SizedBox(
                  height: 72,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: controller.previous,
                        tooltip: '上一曲',
                        iconSize: 36,
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                      const SizedBox(width: 18),
                      SizedBox.square(
                        dimension: 58,
                        child: IconButton.filled(
                          onPressed: state.loading ? null : controller.toggle,
                          tooltip: state.playing ? '暂停' : '播放',
                          iconSize: 34,
                          icon: state.loading
                              ? const SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  state.playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      IconButton(
                        onPressed: controller.next,
                        tooltip: '下一曲',
                        iconSize: 36,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _duration(Duration value) {
    final seconds = value.inSeconds.clamp(0, 359999).toInt();
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _showPlaylist(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.68,
        child: Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(musicPlayerProvider);
            final controller = ref.read(musicPlayerProvider.notifier);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '播放列表 · ${state.playlist.length} 首',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(onPressed: controller.clear, child: const Text('清空')),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.playlist.length,
                    itemBuilder: (context, index) {
                      final track = state.playlist[index];
                      return ListTile(
                        selected: index == state.currentIndex,
                        leading: MusicArtwork(track: track, size: 44),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          onPressed: () => controller.removeAt(index),
                          tooltip: '移除',
                          icon: const Icon(Icons.close_rounded),
                        ),
                        onTap: () => controller.playAt(index),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ArtworkView extends StatelessWidget {
  const _ArtworkView({required this.track});

  final MusicTrack track;

  @override
  Widget build(BuildContext context) {
    final size = math.min(MediaQuery.sizeOf(context).width - 64, 320.0);
    return Center(
      child: MusicArtwork(
        track: track,
        size: size.clamp(180, 320).toDouble(),
        borderRadius: 8,
      ),
    );
  }
}

class _LyricsView extends StatelessWidget {
  const _LyricsView({super.key, required this.track, required this.position});

  final MusicTrack track;
  final Duration position;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LyricsPayload>(
      future: MusicApiService.instance.lyrics(track),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final lines = parseLrc(snapshot.data?.preferred ?? '');
        if (lines.isEmpty) {
          return Center(
            child: Text(
              '暂无歌词',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          );
        }
        return _SyncedLyrics(lines: lines, position: position);
      },
    );
  }
}

class _SyncedLyrics extends StatefulWidget {
  const _SyncedLyrics({required this.lines, required this.position});

  final List<LyricLine> lines;
  final Duration position;

  @override
  State<_SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends State<_SyncedLyrics> {
  static const _itemExtent = 54.0;
  final _controller = ScrollController();
  var _lastIndex = -2;

  @override
  void didUpdateWidget(covariant _SyncedLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = activeLyricIndex(widget.lines, widget.position);
    if (index == _lastIndex) return;
    _lastIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients || index < 0) return;
      final target = (index * _itemExtent -
              _controller.position.viewportDimension / 2)
          .clamp(0.0, _controller.position.maxScrollExtent)
          .toDouble();
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = activeLyricIndex(widget.lines, widget.position);
    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.symmetric(vertical: 110, horizontal: 24),
      itemExtent: _itemExtent,
      itemCount: widget.lines.length,
      itemBuilder: (context, index) {
        final selected = index == active;
        return Center(
          child: Text(
            widget.lines[index].text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: selected ? 18 : 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
