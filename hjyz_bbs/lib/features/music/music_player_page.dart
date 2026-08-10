import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/music_cache_service.dart';
import '../../core/services/music_player_settings_service.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_controller.dart';
import 'dynamic_music_background.dart';
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
    final current = ref.watch(
      musicPlayerProvider.select((state) => state.currentTrack),
    );
    final auth = ref.watch(authControllerProvider);
    final userId = int.tryParse(auth.user?['id']?.toString() ?? '') ?? 0;
    final favorites = ref.watch(musicFavoritesProvider);
    final shouldLoadFavorites = userId > 0
        ? favorites.userId != userId || !favorites.initialized
        : favorites.userId != 0;
    if (shouldLoadFavorites && !favorites.loading) {
      Future.microtask(() => ref.read(musicFavoritesProvider.notifier).load(userId));
    }

    final isFavorite = current != null && favorites.contains(current);
    return Scaffold(
      extendBodyBehindAppBar: current != null,
      backgroundColor: current == null
          ? AppColors.scaffoldBg(context)
          : Colors.transparent,
      appBar: AppBar(
        title: const Text('音乐播放器'),
        backgroundColor: current == null ? null : Colors.transparent,
        foregroundColor: current == null ? null : Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle:
            current == null ? null : SystemUiOverlayStyle.light,
      ),
      body: current == null
          ? const _EmptyPlaylist()
          : Stack(
              fit: StackFit.expand,
              children: [
                _MusicBackgroundLayer(track: current),
                _NowPlayingForegroundTheme(
                  track: current,
                  child: SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: PageView(
                            onPageChanged: (index) =>
                                setState(() => _pageIndex = index),
                            children: [
                              _ArtworkPage(track: current),
                              _LiveLyricsPage(
                                key: ValueKey(current.url),
                                track: current,
                              ),
                            ],
                          ),
                        ),
                        _PlayerPageIndicator(pageIndex: _pageIndex),
                        _LivePlayerControls(
                          isFavorite: isFavorite,
                          onShowPlaylist: () => _showPlaylist(context),
                          onFavorite: () => _toggleFavorite(
                            context,
                            current,
                            userId,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                                subtitle: Text(
                                  selected
                                      ? '${track.artist.isEmpty ? '' : '${track.artist} · '}${state.playing ? '正在播放' : '已暂停'}'
                                      : track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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

class _MusicBackgroundLayer extends ConsumerWidget {
  final MusicTrack track;

  const _MusicBackgroundLayer({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(
      musicPlayerProvider.select((state) => state.playing),
    );
    return ValueListenableBuilder<MusicPlayerVisualSettings>(
      valueListenable: MusicPlayerSettingsService.settings,
      builder: (context, settings, _) {
        return DynamicMusicBackground(
          track: track,
          playing: playing,
          advancedBlur: settings.advancedBlur,
          musicReactive: settings.musicReactive,
          dynamicBackground: settings.dynamicBackground,
          coverBlurBackground: settings.coverBlurBackground,
          coverBlurAmount: settings.coverBlurAmount,
          coverBlurDarken: settings.coverBlurDarken,
        );
      },
    );
  }
}

class _NowPlayingForegroundTheme extends StatefulWidget {
  final MusicTrack track;
  final Widget child;

  const _NowPlayingForegroundTheme({
    required this.track,
    required this.child,
  });

  @override
  State<_NowPlayingForegroundTheme> createState() =>
      _NowPlayingForegroundThemeState();
}

class _NowPlayingForegroundThemeState
    extends State<_NowPlayingForegroundTheme> {
  Color? _coverSeed;
  var _loadRevision = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCoverSeed());
  }

  @override
  void didUpdateWidget(covariant _NowPlayingForegroundTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.url != widget.track.url ||
        oldWidget.track.coverUrl != widget.track.coverUrl ||
        oldWidget.track.coverArt != widget.track.coverArt) {
      unawaited(_loadCoverSeed());
    }
  }

  Future<void> _loadCoverSeed() async {
    final revision = ++_loadRevision;
    final seed = await loadMusicCoverSeedColor(widget.track);
    if (!mounted || revision != _loadRevision || seed == _coverSeed) return;
    setState(() => _coverSeed = seed);
  }

  @override
  Widget build(BuildContext context) {
    final inherited = Theme.of(context);
    final colors = ColorScheme.fromSeed(
      seedColor: _coverSeed ?? inherited.colorScheme.primary,
      brightness: Brightness.dark,
    );
    return AnimatedTheme(
      duration: const Duration(milliseconds: 420),
      curve: Curves.fastOutSlowIn,
      data: inherited.copyWith(
        brightness: Brightness.dark,
        colorScheme: colors,
        iconTheme: inherited.iconTheme.copyWith(color: colors.onSurface),
        textTheme: inherited.textTheme.apply(
          bodyColor: colors.onSurface,
          displayColor: colors.onSurface,
        ),
        primaryTextTheme: inherited.primaryTextTheme.apply(
          bodyColor: colors.onSurface,
          displayColor: colors.onSurface,
        ),
      ),
      child: widget.child,
    );
  }
}

class _PlayerPageIndicator extends StatelessWidget {
  final int pageIndex;

  const _PlayerPageIndicator({required this.pageIndex});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        2,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: index == pageIndex ? 16 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: index == pageIndex
                ? colors.primary
                : colors.onSurfaceVariant.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _LiveLyricsPage extends ConsumerWidget {
  final MusicTrack track;

  const _LiveLyricsPage({super.key, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(
      musicPlayerProvider.select((state) => state.position),
    );
    return _LyricsPage(track: track, position: position);
  }
}

class _LivePlayerControls extends ConsumerWidget {
  final bool isFavorite;
  final VoidCallback onShowPlaylist;
  final VoidCallback onFavorite;

  const _LivePlayerControls({
    required this.isFavorite,
    required this.onShowPlaylist,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);
    final controller = ref.read(musicPlayerProvider.notifier);
    return _PlayerControls(
      state: state,
      isFavorite: isFavorite,
      onSeek: controller.seek,
      onShowPlaylist: onShowPlaylist,
      onPrevious: controller.playPrevious,
      onToggle: controller.toggle,
      onNext: controller.playNext,
      onFavorite: onFavorite,
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

  const _LyricsPage({required this.track, required this.position});

  @override
  State<_LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<_LyricsPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  Future<MusicLyrics?>? _lyricsFuture;
  var _lastActiveIndex = -1;
  var _scrollRequest = 0;

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
      _scrollRequest++;
      _loadLyrics();
    }
  }

  void _loadLyrics() {
    final url = widget.track.lyricsUrl;
    _lyricsFuture = url == null || url.isEmpty
        ? Future.value(null)
        : MusicCacheService.instance.loadLyrics(url);
  }

  void _scrollToActive(int activeIndex, int lineCount) {
    if (activeIndex < 0 || activeIndex == _lastActiveIndex) return;
    final request = ++_scrollRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || request != _scrollRequest) return;
      final target = _lineKeys[activeIndex]?.currentContext;
      if (target != null) {
        _lastActiveIndex = activeIndex;
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
        return;
      }

      if (!_scrollController.hasClients || lineCount < 2) return;
      final position = _scrollController.position;
      final approximateOffset =
          position.maxScrollExtent * activeIndex / (lineCount - 1);
      _scrollController.jumpTo(
        approximateOffset
            .clamp(0.0, position.maxScrollExtent)
            .toDouble(),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || request != _scrollRequest) return;
        final visibleTarget = _lineKeys[activeIndex]?.currentContext;
        if (visibleTarget == null) return;
        _lastActiveIndex = activeIndex;
        Scrollable.ensureVisible(
          visibleTarget,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      });
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
            _scrollToActive(activeIndex, lyrics.lines.length);
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
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
                    key: _lineKeys.putIfAbsent(index, () => GlobalKey()),
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
    final colors = Theme.of(context).colorScheme;
    final durationMilliseconds = max(1, state.duration.inMilliseconds);
    final positionMilliseconds = state.position.inMilliseconds
        .clamp(0, durationMilliseconds)
        .toDouble();
    final bufferedMilliseconds = state.bufferedPosition.inMilliseconds
        .clamp(0, durationMilliseconds)
        .toDouble();
    final secondaryTrackValue = bufferedMilliseconds >= positionMilliseconds
        ? bufferedMilliseconds
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            state.currentTrack?.title ?? '音乐',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (state.currentTrack?.artist.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              state.currentTrack!.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 4),
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colors.primary,
              inactiveTrackColor: colors.onSurface.withValues(alpha: 0.24),
              secondaryActiveTrackColor:
                  colors.primary.withValues(alpha: 0.42),
              thumbColor: colors.primary,
              overlayColor: colors.primary.withValues(alpha: 0.16),
              disabledActiveTrackColor:
                  colors.onSurface.withValues(alpha: 0.38),
              disabledInactiveTrackColor:
                  colors.onSurface.withValues(alpha: 0.12),
              disabledThumbColor: colors.onSurface.withValues(alpha: 0.38),
            ),
            child: Slider(
              value: positionMilliseconds,
              secondaryTrackValue: secondaryTrackValue,
              max: durationMilliseconds.toDouble(),
              onChanged: state.duration.inMilliseconds <= 0
                  ? null
                  : (value) => onSeek(Duration(milliseconds: value.round())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(state.position),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                Text(
                  _formatDuration(state.duration),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
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
                color: colors.onSurface,
                icon: const Icon(Icons.queue_music_rounded),
              ),
              IconButton(
                onPressed: onPrevious,
                tooltip: '上一曲',
                iconSize: 34,
                color: colors.onSurface,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              SizedBox(
                width: 60,
                height: 60,
                child: FilledButton(
                  onPressed: state.loading ? null : onToggle,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    disabledBackgroundColor:
                        colors.onSurface.withValues(alpha: 0.12),
                    disabledForegroundColor:
                        colors.onSurface.withValues(alpha: 0.38),
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: state.loading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
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
                color: colors.onSurface,
                icon: const Icon(Icons.skip_next_rounded),
              ),
              IconButton(
                onPressed: onFavorite,
                tooltip: isFavorite ? '取消收藏' : '收藏',
                iconSize: 28,
                color: isFavorite ? colors.primary : colors.onSurface,
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
    if (coverArt == null && (widget.track.coverUrl == null || widget.track.coverUrl!.isEmpty)) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.size > 80 ? 22 : 10),
      child: coverArt != null
          ? Image.memory(
              coverArt,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : Image.network(
              widget.track.coverUrl!,
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
