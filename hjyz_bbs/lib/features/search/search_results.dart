import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../thread/widgets/thread_waterfall_grid.dart';

class SearchResults extends StatelessWidget {
  final List<Map<String, dynamic>> threads;
  final List<Map<String, dynamic>> music;

  const SearchResults({super.key, required this.threads, required this.music});

  @override
  Widget build(BuildContext context) {
    if (music.isEmpty) return ThreadWaterfallGrid(threads: threads);
    return Column(
      children: [
        SizedBox(
          height: 128,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            scrollDirection: Axis.horizontal,
            itemCount: music.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = music[index];
              return SizedBox(
                width: 180,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: const Icon(Icons.music_note_rounded),
                    title: Text(item['title']?.toString() ?? '未知歌曲', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(item['artist']?.toString().isEmpty == false ? item['artist'].toString() : '未知歌手', maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => context.push('/music-library'),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: threads.isEmpty
              ? const Center(child: Text('找到相关音乐'))
              : ThreadWaterfallGrid(threads: threads),
        ),
      ],
    );
  }
}
