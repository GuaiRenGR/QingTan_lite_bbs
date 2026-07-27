import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/music_player_controller.dart';
import '../models/music.dart';
import '../services/music_api_service.dart';
import '../services/music_download_service.dart';
import '../services/music_player_settings_service.dart';
import '../utils/lrc.dart';
import '../widgets/dynamic_music_background.dart';
import '../widgets/music_artwork.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  var _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicPlayerProvider);
    final track = state.currentTrack;
    if (track == null) return const _EmptyPlayer();

    return Stack(
      fit: StackFit.expand,
      children: [
        _MusicBackgroundLayer(track: track),
        _NowPlayingForegroundTheme(
          track: track,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '音乐播放器',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showPlayerSettings(context),
                        tooltip: '播放器设置',
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    onPageChanged: (index) =>
                        setState(() => _pageIndex = index),
                    children: [
                      _ArtworkPage(track: track),
                      _LyricsPage(
                        key: ValueKey(track.key),
                        track: track,
                        position: state.position,
                      ),
                    ],
                  ),
                ),
                _PlayerPageIndicator(pageIndex: _pageIndex),
                _PlayerControls(
                  state: state,
                  onShowPlaylist: () => _showPlaylist(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
                      if (state.playlist.isNotEmpty)
                        TextButton(
                          onPressed: controller.clear,
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
                              leading: MusicArtwork(track: track, size: 44),
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

  Future<void> _showPlayerSettings(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return ValueListenableBuilder<MusicPlayerVisualSettings>(
            valueListenable: MusicPlayerSettingsService.settings,
            builder: (context, settings, _) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      '播放器设置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.blur_on_rounded),
                    title: const Text('高级模糊'),
                    value: settings.advancedBlur,
                    onChanged: MusicPlayerSettingsService.setAdvancedBlur,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.wallpaper_rounded),
                    title: const Text('正在播放模糊封面背景'),
                    subtitle: const Text('使用当前封面作为正在播放页面背景'),
                    value: settings.coverBlurBackground,
                    onChanged:
                        MusicPlayerSettingsService.setCoverBlurBackground,
                  ),
                  if (settings.coverBlurBackground) ...[
                    _EffectSliderTile(
                      title: '封面模糊强度',
                      valueLabel:
                          '当前模糊：${settings.coverBlurAmount.toStringAsFixed(1)}',
                      value: settings.coverBlurAmount,
                      max: 500,
                      divisions: 100,
                      onChanged:
                          MusicPlayerSettingsService.setCoverBlurAmount,
                    ),
                    _EffectSliderTile(
                      title: '背景调暗',
                      valueLabel:
                          '调暗强度：${settings.coverBlurDarken.toStringAsFixed(2)}',
                      value: settings.coverBlurDarken,
                      max: 0.8,
                      divisions: 16,
                      onChanged:
                          MusicPlayerSettingsService.setCoverBlurDarken,
                    ),
                  ],
                  SwitchListTile(
                    secondary: const Icon(Icons.graphic_eq_rounded),
                    title: const Text('正在播放音频律动'),
                    subtitle: Text(
                      settings.coverBlurBackground
                          ? '需关闭模糊封面背景'
                          : settings.dynamicBackground
                              ? '控制正在播放页面的音频律动效果'
                              : '需先开启正在播放动态背景',
                    ),
                    value: settings.musicReactive,
                    onChanged: settings.dynamicBackground &&
                            !settings.coverBlurBackground
                        ? MusicPlayerSettingsService.setMusicReactive
                        : null,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.animation_rounded),
                    title: const Text('正在播放动态背景'),
                    subtitle: Text(
                      settings.coverBlurBackground
                          ? '需关闭模糊封面背景'
                          : '控制正在播放页面的动态背景效果',
                    ),
                    value: settings.dynamicBackground,
                    onChanged: settings.coverBlurBackground
                        ? null
                        : MusicPlayerSettingsService.setDynamicBackground,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _MusicBackgroundLayer extends ConsumerWidget {
  const _MusicBackgroundLayer({required this.track});

  final MusicTrack track;

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
  const _NowPlayingForegroundTheme({
    required this.track,
    required this.child,
  });

  final MusicTrack track;
  final Widget child;

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
    if (oldWidget.track.key != widget.track.key ||
        oldWidget.track.coverUrl != widget.track.coverUrl) {
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
      ),
      child: widget.child,
    );
  }
}

class _PlayerPageIndicator extends StatelessWidget {
  const _PlayerPageIndicator({required this.pageIndex});

  final int pageIndex;

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

class _ArtworkPage extends StatelessWidget {
  const _ArtworkPage({required this.track});

  final MusicTrack track;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(
          math.max(180, constraints.maxWidth - 64),
          math.max(180, constraints.maxHeight - 52),
        );
        return Center(
          child: MusicArtwork(
            track: track,
            size: size.toDouble(),
            borderRadius: 22,
          ),
        );
      },
    );
  }
}

class _LyricsPage extends StatefulWidget {
  const _LyricsPage({
    super.key,
    required this.track,
    required this.position,
  });

  final MusicTrack track;
  final Duration position;

  @override
  State<_LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<_LyricsPage> {
  late Future<LyricsPayload> _lyricsFuture;

  @override
  void initState() {
    super.initState();
    _lyricsFuture = MusicApiService.instance.lyrics(widget.track);
  }

  @override
  void didUpdateWidget(covariant _LyricsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.key != widget.track.key) {
      _lyricsFuture = MusicApiService.instance.lyrics(widget.track);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LyricsPayload>(
      future: _lyricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final lines = parseLrc(snapshot.data?.preferred ?? '');
        if (lines.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lyrics_outlined,
                  size: 52,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  '暂无歌词',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return _SyncedLyrics(lines: lines, position: widget.position);
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
  static const _itemExtent = 58.0;
  final _controller = ScrollController();
  var _lastIndex = -2;
  var _scrollRequest = 0;

  void _scrollToActive(int index) {
    if (index < 0 || index == _lastIndex) return;
    _lastIndex = index;
    final request = ++_scrollRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || request != _scrollRequest || !_controller.hasClients) {
        return;
      }
      _controller.animateTo(
        (index * _itemExtent)
            .clamp(0, _controller.position.maxScrollExtent)
            .toDouble(),
        duration: const Duration(milliseconds: 320),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        _scrollToActive(active);
        final centerPadding = math.max(
          0,
          (constraints.maxHeight - _itemExtent) / 2,
        ).toDouble();
        return ListView.builder(
          controller: _controller,
          padding: EdgeInsets.fromLTRB(28, centerPadding, 28, centerPadding),
          itemExtent: _itemExtent,
          itemCount: widget.lines.length,
          itemBuilder: (context, index) {
            final selected = index == active;
            return AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: selected ? 19 : 16,
                height: 1.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              child: Center(
                child: Text(
                  widget.lines[index].text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PlayerControls extends ConsumerWidget {
  const _PlayerControls({required this.state, required this.onShowPlaylist});

  final MusicPlayerState state;
  final VoidCallback onShowPlaylist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(musicPlayerProvider.notifier);
    final downloads = ref.watch(musicDownloadProvider);
    final track = state.currentTrack!;
    final download = downloads.entryFor(track);
    final colors = Theme.of(context).colorScheme;
    final durationMilliseconds = math.max(1, state.duration.inMilliseconds);
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
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (track.artist.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 4),
            Text(
              state.error!,
              style: TextStyle(color: colors.error),
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
            ),
            child: Slider(
              value: positionMilliseconds,
              secondaryTrackValue: secondaryTrackValue,
              max: durationMilliseconds.toDouble(),
              onChanged: state.duration == Duration.zero
                  ? null
                  : (value) => controller.seek(
                        Duration(milliseconds: value.round()),
                      ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _duration(state.position),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                Text(
                  _duration(state.duration),
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
                onPressed: controller.previous,
                tooltip: '上一曲',
                iconSize: 34,
                color: colors.onSurface,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              SizedBox.square(
                dimension: 60,
                child: FilledButton(
                  onPressed: state.loading ? null : controller.toggle,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: state.loading
                      ? SizedBox.square(
                          dimension: 22,
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
                onPressed: controller.next,
                tooltip: '下一曲',
                iconSize: 34,
                color: colors.onSurface,
                icon: const Icon(Icons.skip_next_rounded),
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
                iconSize: 28,
                color: colors.onSurface,
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
            ],
          ),
        ],
      ),
    );
  }

  static String _duration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _EffectSliderTile extends StatelessWidget {
  const _EffectSliderTile({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String valueLabel;
  final double value;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_rounded, size: 64),
            SizedBox(height: 14),
            Text(
              '播放列表为空',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text('搜索歌曲并播放后，歌曲会自动加入这里'),
          ],
        ),
      ),
    );
  }
}
