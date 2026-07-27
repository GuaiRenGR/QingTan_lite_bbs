import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/safe_network_image.dart';
import 'music_player_controller.dart';

class NeteaseMusicPage extends ConsumerStatefulWidget {
  const NeteaseMusicPage({super.key});

  @override
  ConsumerState<NeteaseMusicPage> createState() => _NeteaseMusicPageState();
}

class _MusicSource {
  const _MusicSource(this.value, this.label);

  final String value;
  final String label;
}

class _NeteaseMusicPageState extends ConsumerState<NeteaseMusicPage> {
  static const _sources = [
    _MusicSource('netease', '网易云音乐'),
    _MusicSource('netease_official', '网易云音乐官方'),
    _MusicSource('tencent', 'QQ音乐'),
    _MusicSource('kuwo', '酷我音乐'),
    _MusicSource('tidal', 'Tidal'),
    _MusicSource('qobuz', 'Qobuz'),
    _MusicSource('joox', 'JOOX'),
    _MusicSource('bilibili', '哔哩哔哩'),
    _MusicSource('apple', 'Apple Music'),
    _MusicSource('ytmusic', 'Youtube Music'),
    _MusicSource('spotify', 'Spotify'),
  ];

  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _songs = const [];
  _MusicSource _source = _sources.first;
  bool _loading = false;
  String? _error;
  int _searchGeneration = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty || _loading) return;

    final generation = ++_searchGeneration;
    final source = _source;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiClient.instance.get(
      'netease/search',
      query: {'keyword': keyword, 'limit': 20, 'source': source.value},
    );
    if (!mounted || generation != _searchGeneration) return;

    final raw = result.success && result.data is Map<String, dynamic>
        ? (result.data as Map<String, dynamic>)['list']
        : null;
    setState(() {
      _loading = false;
      _songs = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : const [];
      _error = result.success ? null : result.message;
    });
  }

  void _selectSource(_MusicSource source) {
    if (source.value == _source.value) return;
    _searchGeneration++;
    setState(() {
      _source = source;
      _songs = const [];
      _loading = false;
      _error = null;
    });
    if (_searchController.text.trim().isNotEmpty) _search();
  }

  Future<void> _play(Map<String, dynamic> song) async {
    if (song['playable'] == false || song['playable'] == 0) return;
    final url = song['url']?.toString().trim() ?? '';
    if (url.isEmpty) return;
    await ref.read(musicPlayerProvider.notifier).selectTrack(
          MusicTrack(
            url: url,
            title: song['title']?.toString() ?? '未知歌曲',
            artist: song['artist']?.toString() ?? '',
            coverUrl: song['cover_url']?.toString(),
            lyricsUrl: song['lyrics_url']?.toString(),
          ),
          autoplay: true,
        );
    if (mounted) context.push('/music-player');
  }

  String _duration(dynamic value) {
    final milliseconds = int.tryParse(value?.toString() ?? '') ?? 0;
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索音乐')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MenuAnchor(
                  menuChildren: [
                    for (final source in _sources)
                      MenuItemButton(
                        leadingIcon: source.value == _source.value
                            ? const Icon(Icons.check_rounded)
                            : const SizedBox(width: 24),
                        onPressed: () => _selectSource(source),
                        child: Text(source.label),
                      ),
                  ],
                  builder: (context, controller, child) {
                    return OutlinedButton.icon(
                      onPressed: () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
                      icon: const Icon(Icons.library_music_outlined),
                      label: Text(_source.label),
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: '搜索歌曲名、歌手或专辑',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: '搜索',
                      onPressed: _search,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
        ),
      );
    }
    if (_songs.isEmpty) {
      return Center(
        child: Text(
          '搜索${_source.label}',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: _songs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final song = _songs[index];
        final title = song['title']?.toString() ?? '未知歌曲';
        final artist = song['artist']?.toString().trim() ?? '';
        final album = song['album']?.toString().trim() ?? '';
        final durationMs =
            int.tryParse(song['duration_ms']?.toString() ?? '') ?? 0;
        final playable = song['playable'] != false && song['playable'] != 0;
        final details = [
          if (artist.isNotEmpty) artist,
          if (album.isNotEmpty) album,
          if (!playable) '暂无播放版权',
        ].join(' · ');
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 3,
          ),
          leading: SafeNetworkImage(
            url: song['cover_url']?.toString(),
            width: 52,
            height: 52,
            borderRadius: BorderRadius.circular(7),
            errorWidget: Container(
              width: 52,
              height: 52,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.music_note_rounded),
            ),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            details.isEmpty ? _source.label : details,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (durationMs > 0)
                Text(
                  _duration(durationMs),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              IconButton(
                tooltip: playable ? '播放' : '暂不可播放',
                onPressed: playable ? () => _play(song) : null,
                icon: Icon(
                  playable
                      ? Icons.play_circle_outline_rounded
                      : Icons.block_rounded,
                ),
              ),
            ],
          ),
          onTap: playable ? () => _play(song) : null,
        );
      },
    );
  }
}
