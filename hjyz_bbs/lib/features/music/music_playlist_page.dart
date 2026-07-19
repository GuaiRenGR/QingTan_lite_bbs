import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/music_cache_service.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_controller.dart';
import 'music_favorites_controller.dart';
import 'music_player_controller.dart';

class MusicPlaylistPage extends ConsumerWidget {
  const MusicPlaylistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final userId = int.tryParse(auth.user?['id']?.toString() ?? '') ?? 0;
    final favorites = ref.watch(musicFavoritesProvider);
    final shouldLoadFavorites = userId > 0
        ? favorites.userId != userId || !favorites.initialized
        : favorites.userId != 0;
    if (shouldLoadFavorites && !favorites.loading) {
      Future.microtask(() => ref.read(musicFavoritesProvider.notifier).load(userId));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的歌单'),
        actions: [
          if (userId > 0)
            IconButton(
              onPressed: () => ref
                  .read(musicFavoritesProvider.notifier)
                  .load(userId, force: true),
              tooltip: '刷新',
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: userId <= 0
          ? _LoginRequired(onLogin: () => context.push('/login'))
          : favorites.loading && favorites.tracks.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(musicFavoritesProvider.notifier)
                      .load(userId, force: true),
                  child: favorites.tracks.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 180),
                            Icon(Icons.favorite_border_rounded, size: 60),
                            SizedBox(height: 12),
                            Center(child: Text('还没有收藏歌曲')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                          itemCount: favorites.tracks.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final track = favorites.tracks[index];
                            return _FavoriteTrackTile(track: track);
                          },
                        ),
                ),
    );
  }
}

class _FavoriteTrackTile extends ConsumerStatefulWidget {
  final MusicTrack track;

  const _FavoriteTrackTile({required this.track});

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
        url: widget.track.url,
        title: _metadata?.title ?? widget.track.title,
        coverArt: _metadata?.coverArt ?? widget.track.coverArt,
        lyricsUrl: widget.track.lyricsUrl,
      );

  @override
  Widget build(BuildContext context) {
    final cover = _track.coverArt;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: cover == null
            ? Container(
                width: 48,
                height: 48,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.music_note_rounded),
              )
            : Image.memory(cover, width: 48, height: 48, fit: BoxFit.cover),
      ),
      title: Text(
        _track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _track.lyricsUrl == null ? '已收藏' : '已收藏 · 含歌词',
        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
      ),
      trailing: IconButton(
        onPressed: () => ref.read(musicFavoritesProvider.notifier).toggle(_track),
        tooltip: '取消收藏',
        icon: const Icon(Icons.favorite_rounded),
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
