import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/music_player_controller.dart';
import '../widgets/music_artwork.dart';
import 'downloads_page.dart';
import 'player_page.dart';
import 'search_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(musicPlayerProvider);
    final track = player.currentTrack;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                SearchPage(onOpenPlayer: () => setState(() => _index = 1)),
                const PlayerPage(),
                const DownloadsPage(),
              ],
            ),
          ),
          if (track != null && _index != 1)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: InkWell(
                onTap: () => setState(() => _index = 1),
                child: SizedBox(
                  height: 62,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        MusicArtwork(track: track, size: 44),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                track.artist.isEmpty ? '未知歌手' : track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: player.loading
                              ? null
                              : ref.read(musicPlayerProvider.notifier).toggle,
                          tooltip: player.playing ? '暂停' : '播放',
                          icon: player.loading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  player.playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.manage_search_rounded),
            label: '搜索',
          ),
          NavigationDestination(
            icon: Icon(Icons.headphones_outlined),
            selectedIcon: Icon(Icons.headphones_rounded),
            label: '播放器',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download_rounded),
            label: '下载',
          ),
        ],
      ),
    );
  }
}
