import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/safe_network_image.dart';
import 'music_player_controller.dart';

class MusicLibraryPage extends ConsumerStatefulWidget {
  const MusicLibraryPage({super.key});

  @override
  ConsumerState<MusicLibraryPage> createState() => _MusicLibraryPageState();
}

class _MusicLibraryPageState extends ConsumerState<MusicLibraryPage> {
  final _searchController = TextEditingController();
  var _loading = false;
  List<Map<String, dynamic>> _items = const [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;
    setState(() => _loading = true);
    final result = await ApiClient.instance.get(
      'music/search',
      query: {'keyword': keyword, 'page_size': 50},
    );
    if (!mounted) return;
    final raw = result.success && result.data is Map<String, dynamic>
        ? (result.data as Map<String, dynamic>)['list']
        : null;
    setState(() {
      _loading = false;
      _items = raw is List
          ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : const [];
    });
  }

  Future<void> _play(Map<String, dynamic> item) async {
    final url = ApiClient.instance.resolveUrl(item['url']?.toString() ?? '');
    if (url.isEmpty) return;
    await ref.read(musicPlayerProvider.notifier).selectTrack(
          MusicTrack(
            uuid: item['uuid']?.toString(),
            url: url,
            title: item['title']?.toString() ?? '未知歌曲',
            artist: item['artist']?.toString() ?? '',
            coverUrl: item['cover_url']?.toString(),
            lyricsUrl: item['lyrics_url']?.toString(),
          ),
          autoplay: true,
        );
    if (mounted) context.push('/music-player');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('音乐管理器')),
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('搜索已上传的音乐'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final cover = item['cover_url']?.toString() ?? '';
                          final title = item['title']?.toString() ?? '未知歌曲';
                          final artist = item['artist']?.toString() ?? '';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: cover.isEmpty
                                ? const CircleAvatar(child: Icon(Icons.music_note_rounded))
                                : SafeNetworkImage(
                                    url: cover,
                                    width: 52,
                                    height: 52,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              artist.isEmpty ? '未知歌手' : artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: '播放',
                              onPressed: () => _play(item),
                              icon: const Icon(Icons.play_circle_outline_rounded),
                            ),
                            onTap: () => _play(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
