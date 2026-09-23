import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/services/music_cache_service.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_controller.dart';
import 'music_favorites_controller.dart';
import 'music_player_controller.dart';

class MusicPlaylistPage extends ConsumerStatefulWidget {
  const MusicPlaylistPage({super.key});

  @override
  ConsumerState<MusicPlaylistPage> createState() => _MusicPlaylistPageState();
}

class _MusicPlaylistPageState extends ConsumerState<MusicPlaylistPage> {
  List<Map<String, dynamic>> _playlists = const [];
  List<Map<String, dynamic>> _rows = const [];
  int? _selectedId;
  int _loadedUserId = 0;
  bool _loading = false;
  String? _error;

  Future<void> _load(int userId, {int? selectId}) async {
    if (userId <= 0) return;
    setState(() { _loading = true; _error = null; });
    final response = await ApiClient.instance.get('music/playlists');
    if (!mounted || _loadedUserId != userId) return;
    if (!response.success || response.data is! Map<String, dynamic>) {
      setState(() { _loading = false; _error = response.message; });
      return;
    }
    final data = response.data as Map<String, dynamic>;
    final list = (data['playlists'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final id = selectId ?? _selectedId;
    final selectedMatches = list.where((item) => item['playlist_id'] == id).toList();
    final selected = selectedMatches.isNotEmpty ? selectedMatches.first : (list.isEmpty ? null : list.first);
    setState(() { _playlists = list; _selectedId = selected?['playlist_id'] as int?; });
    if (selected != null) await _loadTracks(selected['playlist_id'] as int);
    else if (mounted) setState(() { _rows = const []; _loading = false; });
  }

  Future<void> _loadTracks(int id) async {
    setState(() { _selectedId = id; _loading = true; });
    final response = await ApiClient.instance.get('music/playlists/tracks', query: {'id': id});
    if (!mounted || _selectedId != id) return;
    final data = response.data;
    setState(() {
      _loading = false;
      _error = response.success ? null : response.message;
      _rows = data is Map<String, dynamic> && data['tracks'] is List
          ? (data['tracks'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : const [];
    });
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('新建歌单'),
      content: TextField(controller: controller, autofocus: true, maxLength: 100, decoration: const InputDecoration(labelText: '歌单名称')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('创建')),
      ],
    ));
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final result = await ApiClient.instance.post('music/playlists/create', data: {'name': name});
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }
    final playlist = (result.data as Map?)?['playlist'] as Map?;
    await _load(_loadedUserId, selectId: playlist?['playlist_id'] as int?);
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    final id = _selectedId;
    if (id == null) return;
    final result = await ApiClient.instance.post('music/playlists/remove', data: {
      'playlist_id': id, 'track_id': row['id'],
    });
    if (!mounted) return;
    if (result.success) await _loadTracks(id);
    else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final userId = int.tryParse(auth.user?['id']?.toString() ?? '') ?? 0;
    if (userId != _loadedUserId) {
      _loadedUserId = userId;
      _playlists = const [];
      _rows = const [];
      _selectedId = null;
      if (userId > 0) Future.microtask(() => _load(userId));
    }
    final tracks = _rows.map(MusicTrack.fromJson).whereType<MusicTrack>().toList();
    final selectedMatches = _playlists.where((item) => item['playlist_id'] == _selectedId).toList();
    final selected = selectedMatches.isNotEmpty ? selectedMatches.first : null;
    final isDefault = selected?['is_default'] == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的歌单'),
        actions: [
          if (userId > 0) IconButton(onPressed: _create, tooltip: '新建歌单', icon: const Icon(Icons.add_rounded)),
          if (tracks.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                await ref
                    .read(musicPlayerProvider.notifier)
                    .playTracks(tracks);
                if (context.mounted) context.push('/music-player');
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('全部播放'),
            ),
          if (userId > 0)
            IconButton(
              onPressed: () => _load(userId),
              tooltip: '刷新',
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: userId <= 0
          ? _LoginRequired(onLogin: () => context.push('/login'))
          : _loading && _playlists.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _load(userId),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      SizedBox(height: 52, child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _playlists.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, index) {
                          final item = _playlists[index];
                          final id = item['playlist_id'] as int;
                          return ChoiceChip(label: Text(item['name']?.toString() ?? '歌单'), selected: id == _selectedId, onSelected: (_) => _loadTracks(id));
                        },
                      )),
                      if (selected != null) Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('歌单号 ${selected['playlist_id']} · ${tracks.length} 首'),
                      ),
                      if (_error != null) ListTile(title: Text(_error!)),
                      if (_loading) const Center(child: CircularProgressIndicator())
                      else if (_rows.isEmpty) const Padding(padding: EdgeInsets.only(top: 100), child: Center(child: Text('歌单中还没有歌曲')))
                      else for (final row in _rows)
                        _FavoriteTrackTile(
                          track: MusicTrack.fromJson(row)!,
                          onRemove: isDefault
                              ? () => ref.read(musicFavoritesProvider.notifier).toggle(MusicTrack.fromJson(row)!).then((_) => _loadTracks(_selectedId!))
                              : () => _remove(row),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _FavoriteTrackTile extends ConsumerStatefulWidget {
  final MusicTrack track;
  final VoidCallback onRemove;

  const _FavoriteTrackTile({required this.track, required this.onRemove});

  @override
  ConsumerState<_FavoriteTrackTile> createState() => _FavoriteTrackTileState();
}

class _FavoriteTrackTileState extends ConsumerState<_FavoriteTrackTile> {
  MusicMetadata? _metadata;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final metadata = await MusicCacheService.instance.loadMetadata(widget.track.url);
    if (mounted) setState(() => _metadata = metadata);
  }

  MusicTrack get _track => MusicTrack(
        uuid: widget.track.uuid,
        url: widget.track.url,
        title: _metadata?.title ?? widget.track.title,
        artist: widget.track.artist,
        coverArt: _metadata?.coverArt ?? widget.track.coverArt,
        coverUrl: widget.track.coverUrl,
        lyricsUrl: widget.track.lyricsUrl,
      );

  @override
  Widget build(BuildContext context) {
    final cover = _track.coverArt;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: cover == null && (_track.coverUrl == null || _track.coverUrl!.isEmpty)
            ? Container(
                width: 48,
                height: 48,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.music_note_rounded),
              )
            : cover != null
                ? Image.memory(cover, width: 48, height: 48, fit: BoxFit.cover)
                : Image.network(
                    _track.coverUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.music_note_rounded),
                    ),
                  ),
      ),
      title: Text(
        _track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _track.artist.isNotEmpty
            ? _track.artist
            : (_track.lyricsUrl == null ? '已收藏' : '已收藏 · 含歌词'),
        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
      ),
      trailing: IconButton(
        onPressed: widget.onRemove,
        tooltip: '移出歌单',
        icon: const Icon(Icons.remove_circle_outline_rounded),
      ),
      onTap: () async {
        await ref.read(musicPlayerProvider.notifier).selectTrack(
              _track,
              autoplay: true,
            );
        if (context.mounted) context.push('/music-player');
      },
    );
  }
}

class _LoginRequired extends StatelessWidget {
  final VoidCallback onLogin;

  const _LoginRequired({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 58),
          const SizedBox(height: 12),
          const Text('登录后使用默认收藏歌单'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onLogin, child: const Text('去登录')),
        ],
      ),
    );
  }
}
