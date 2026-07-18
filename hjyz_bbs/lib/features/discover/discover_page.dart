import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ToolItem(
        icon: Icons.cloud_download_outlined,
        label: '下载管理',
        onTap: () => context.push('/downloads'),
      ),
      _ToolItem(
        icon: Icons.queue_music_rounded,
        label: '音乐播放器',
        onTap: () => context.push('/music-player'),
      ),
      _ToolItem(
        icon: Icons.local_fire_department_outlined,
        label: '热门话题',
      ),
      _ToolItem(
        icon: Icons.forum_outlined,
        label: '热门版块',
      ),
      _ToolItem(
        icon: Icons.leaderboard_outlined,
        label: '热帖榜',
      ),
      _ToolItem(
        icon: Icons.fiber_new_outlined,
        label: '新帖榜',
      ),
      _ToolItem(
        icon: Icons.check_circle_outline_rounded,
        label: '签到榜',
      ),
      _ToolItem(
        icon: Icons.person_search_outlined,
        label: '推荐用户',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('工具'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 92,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (_, index) {
          final item = items[index];
          return Material(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: item.onTap,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 28, color: const Color(0xFFFB7299)),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToolItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ToolItem({required this.icon, required this.label, this.onTap});
}
