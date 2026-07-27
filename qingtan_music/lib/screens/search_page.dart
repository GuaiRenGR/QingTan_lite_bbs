import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/music_player_controller.dart';
import '../models/music.dart';
import '../services/music_api_service.dart';
import '../services/music_download_service.dart';
import '../widgets/music_artwork.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, required this.onOpenPlayer});

  final VoidCallback onOpenPlayer;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  MusicSource _source = MusicSource.all.first;
  List<MusicTrack> _results = const [];
  bool _loading = false;
  String? _error;
  int _generation = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty || _loading) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tracks = await MusicApiService.instance.search(
        source: _source,
        keyword: keyword,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = tracks;
        _loading = false;
      });
    } on MusicApiException catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = const [];
        _loading = false;
        _error = error.message;
      });
    }
  }

  void _selectSource(MusicSource source) {
    if (source.value == _source.value) return;
    _generation++;
    setState(() {
      _source = source;
      _results = const [];
      _loading = false;
      _error = null;
    });
    if (_controller.text.trim().isNotEmpty) _search();
  }

  Future<void> _play(MusicTrack track) async {
    await ref.read(musicPlayerProvider.notifier).selectTrack(track);
    if (mounted) widget.onOpenPlayer();
  }

  void _download(MusicTrack track) {
    final service = ref.read(musicDownloadProvider);
    unawaited(service.download(track));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('开始下载：${track.title}')),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: '轻听音乐',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.graphic_eq_rounded, size: 42),
      children: const [
        Text('多音源数据来自 GD 音乐台（music.gdstudio.xyz），仅供个人学习使用，禁止商业用途。'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(musicDownloadProvider);
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
                    '搜索音乐',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _showAbout,
                  tooltip: '关于',
                  icon: const Icon(Icons.info_outline_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MenuAnchor(
                  menuChildren: [
                    for (final source in MusicSource.all)
                      MenuItemButton(
                        leadingIcon: source.value == _source.value
                            ? const Icon(Icons.check_rounded)
                            : const SizedBox(width: 24),
                        onPressed: () => _selectSource(source),
                        child: Text(source.label),
                      ),
                  ],
                  builder: (context, menu, child) => OutlinedButton.icon(
                    onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                    icon: const Icon(Icons.library_music_outlined),
                    label: Text(_source.label),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '歌曲名、歌手或专辑',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _loading ? null : _search,
                  tooltip: '搜索',
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildResults(downloads),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(MusicDownloadService downloads) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _controller.text.trim().isEmpty ? '搜索${_source.label}' : '没有找到相关歌曲',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final track = _results[index];
        final entry = downloads.entryFor(track);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          leading: MusicArtwork(track: track, size: 52),
          title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (track.artist.isNotEmpty) track.artist,
              if (track.album.isNotEmpty) track.album,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: entry?.active == true ||
                        entry?.status == MusicDownloadStatus.completed
                    ? null
                    : () => _download(track),
                tooltip: entry?.status == MusicDownloadStatus.completed
                    ? '已下载'
                    : '下载标准音质',
                icon: entry?.active == true
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        entry?.status == MusicDownloadStatus.completed
                            ? Icons.download_done_rounded
                            : Icons.download_rounded,
                      ),
              ),
              IconButton(
                onPressed: () => _play(track),
                tooltip: '播放',
                icon: const Icon(Icons.play_circle_outline_rounded),
              ),
            ],
          ),
          onTap: () => _play(track),
        );
      },
    );
  }
}
