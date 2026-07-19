import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/music_cache_service.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_controller.dart';
import 'music_favorites_controller.dart';
import 'music_player_controller.dart';

class MusicPlayerPage extends ConsumerStatefulWidget {
  const MusicPlayerPage({super.key});

  @override
  ConsumerState<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends ConsumerState<MusicPlayerPage> {
  var _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    final auth = ref.watch(authControllerProvider);
    final userId = int.tryParse(auth.user?['id']?.toString() ?? '') ?? 0;
    final favorites = ref.watch(musicFavoritesProvider);
    final shouldLoadFavorites = userId > 0
        ? favorites.userId != userId || !favorites.initialized
        : favorites.userId != 0;
    if (shouldLoadFavorites && !favorites.loading) {
      Future.microtask(() => ref.read(musicFavoritesProvider.notifier).load(userId));
    }

    final current = state.currentTrack;
    final isFavorite = current != null && favorites.contains(current.url);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(title: const Text('音乐播放器')),
      body: current == null
          ? const _EmptyPlaylist()
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      onPageChanged: (index) => setState(() => _pageIndex = index),
                      children: [
                        _ArtworkPage(track: current),
                        _LyricsPage(
                          key: ValueKey(current.url),
                          track: current,
                          position: state.position,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      2,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: index == _pageIndex ? 16 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: index == _pageIndex
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  _PlayerControls(
                    state: state,
                    isFavorite: isFavorite,
                    onSeek: controller.seek,
                    onShowPlaylist: () => _showPlaylist(context),
                    onPrevious: controller.playPrevious,
                    onToggle: controller.toggle,
                    onNext: controller.playNext,
                    onFavorite: () => _toggleFavorite(
                      context,
                      current,
                      userId,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    MusicTrack track,
    int userId,
  ) async {
    if (userId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录后才能收藏歌曲')),
      );
      await context.push('/login');
      return;
    }

    final result = await ref.read(musicFavoritesProvider.notifier).toggle(track);
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result ? '已加入默认歌单' : '已取消收藏')),
    );
  }

  Future<void> _showPlaylist(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.68,
          child: Consumer(
            builder: (context, ref, _) {
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
                        if (state.playlist.isNotEmpty)
                          TextButton(
                            onPressed: controller.clearPlaylist,
                            child: const Text('清空'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: state.playlist.isEmpty
                        ? const Center(child: Text('播放列表为空'))
                        : ListView.builder(
                            itemCount: state.playlist.length,
                            itemBuilder: (context, index) {
                              final track = state.playlist[index];
                              final selected = index == state.currentIndex;
                              return ListTile(
                                selected: selected,
                                leading: _TrackCover(track: track, size: 44),
                                title: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: selected
                                    ? Text(state.playing ? '正在播放' : '已暂停')
                                    : null,
                                trailing: IconButton(
                                  onPressed: () => controller.removeAt(index),
                                  tooltip: '移除',
                                  icon: const Icon(Icons.close_rounded),
                                ),
                                onTap: () => controller.selectTrack(
                                  track,
                                  autoplay: true,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ArtworkPage extends StatelessWidget {
  final MusicTrack track;

  const _ArtworkPage({required this.track});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(
          max(180.0, constraints.maxWidth - 64),
          max(180.0, constraints.maxHeight - 52),
        );
        return Center(child: _TrackCover(track: track, size: size));
      },
    );
  }
}

class _LyricsPage extends StatefulWidget {
  final MusicTrack track;
  final Duration position;

  const _LyricsPage({super.key, required this.track, required this.position});

  @override
  State<_LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<_LyricsPage> {
  final ScrollController _scrollController = ScrollController();
  Future<MusicLyrics?>? _lyricsFuture;
  var _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void didUpdateWidget(covariant _LyricsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.lyricsUrl != widget.track.lyricsUrl) {
      _lastActiveIndex = -1;
      _loadLyrics();
    }
  }

  void _loadLyrics() {
    final url = widget.track.lyricsUrl;
    _lyricsFuture = url == null || url.isEmpty
        ? Future.value(null)
        : MusicCacheService.instance.loadLyrics(url);
  }

  void _scrollToActive(int activeIndex, double viewportHeight) {
    if (activeIndex < 0 || activeIndex == _lastActiveIndex) return;
    _lastActiveIndex = activeIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = (activeIndex * 48.0 - viewportHeight / 2 + 24)
          .clamp(0.0, _scrollController.position.maxScrollExtent)
          .toDouble();
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MusicLyrics?>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final lyrics = snapshot.data;
        if (lyrics == null || lyrics.lines.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lyrics_outlined,
                  size: 52,
                  color: AppColors.textSecondary(context),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.track.lyricsUrl == null ? '暂无歌词' : '歌词加载失败',
                  style: TextStyle(color: AppColors.textSecondary(context)),
                ),
              ],
            ),
          );
        }

        final activeIndex = lyrics.activeIndex(widget.position);
        return LayoutBuilder(
          builder: (context, constraints) {
            _scrollToActive(activeIndex, constraints.maxHeight);
            return ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                horizontal: 28,
                vertical: max(28.0, constraints.maxHeight / 2 - 30),
              ),
              itemCount: lyrics.lines.length,
              itemBuilder: (context, index) {
                final active = index == activeIndex;
                return AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    color: active
                        ? AppColors.text(context)
                        : AppColors.textSecondary(context),
                    fontSize: active ? 19 : 16,
                    height: 1.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      lyrics.lines[index].text,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PlayerControls extends StatelessWidget {
  final MusicPlayerState state;
  final bool isFavorite;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onShowPlaylist;
  final VoidCallback onPrevious;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onFavorite;

  const _PlayerControls({
    required this.state,
    required this.isFavorite,
    required this.onSeek,
    required this.onShowPlaylist,
    required this.onPrevious,
    required this.onToggle,
    required this.onNext,
    required this.onFavorite,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final durationMilliseconds = max(1, state.duration.inMilliseconds);
    final positionMilliseconds = state.position.inMilliseconds
        .clamp(0, durationMilliseconds)
        .toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            state.currentTrack?.title ?? '音乐',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 4),
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 6),
          Slider(
            value: positionMilliseconds,
            max: durationMilliseconds.toDouble(),
            onChanged: state.duration.inMilliseconds <= 0
                ? null
                : (value) => onSeek(Duration(milliseconds: value.round())),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(state.position)),
                Text(_formatDuration(state.duration)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onShowPlaylist,
                tooltip: '播放列表',
                iconSize: 28,
                icon: const Icon(Icons.queue_music_rounded),
              ),
              IconButton(
                onPressed: onPrevious,
                tooltip: '上一曲',
                iconSize: 34,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              SizedBox(
                width: 60,
                height: 60,
                child: FilledButton(
                  onPressed: state.loading ? null : onToggle,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
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
                          size: 36,
                        ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                tooltip: '下一曲',
                iconSize: 34,
                icon: const Icon(Icons.skip_next_rounded),
              ),
              IconButton(
                onPressed: onFavorite,
                tooltip: isFavorite ? '取消收藏' : '收藏',
                iconSize: 28,
                color: isFavorite ? Theme.of(context).colorScheme.primary : null,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackCover extends StatefulWidget {
  final MusicTrack track;
  final double size;

  const _TrackCover({required this.track, required this.size});

  @override
  State<_TrackCover> createState() => _TrackCoverState();
}

class _TrackCoverState extends State<_TrackCover> {
  MusicMetadata? _metadata;

  @override
  void initState() {
    super.initState();
    if (widget.track.coverArt == null) _loadMetadata();
  }

  @override
  void didUpdateWidget(covariant _TrackCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.url != widget.track.url) {
      _metadata = null;
      if (widget.track.coverArt == null) _loadMetadata();
    }
  }

  Future<void> _loadMetadata() async {
    final url = widget.track.url;
    final metadata = await MusicCacheService.instance.loadMetadata(url);
    if (mounted && widget.track.url == url) setState(() => _metadata = metadata);
  }

  @override
  Widget build(BuildContext context) {
    final coverArt = widget.track.coverArt ?? _metadata?.coverArt;
    final fallback = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(widget.size > 80 ? 22 : 10),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: widget.size * 0.38,
      ),
    );
    if (coverArt == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.size > 80 ? 22 : 10),
      child: Image.memory(
        coverArt,
        width: widget.size,
        height: widget.size,
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
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
