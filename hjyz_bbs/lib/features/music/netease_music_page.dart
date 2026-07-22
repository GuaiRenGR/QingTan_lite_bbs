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

class _NeteaseMusicPageState extends ConsumerState<NeteaseMusicPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _songs = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiClient.instance.get(
      'netease/search',
      query: {'keyword': keyword, 'limit': 40},
    );
    if (!mounted) return;

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
      appBar: AppBar(title: const Text('网易云音乐')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '搜索歌曲名或歌手',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: '搜索',
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
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
          '搜索网易云音乐',
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
            details.isEmpty ? '网易云音乐' : details,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _duration(song['duration_ms']),
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
