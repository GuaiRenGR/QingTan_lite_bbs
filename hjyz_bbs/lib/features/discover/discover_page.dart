import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      '热门话题',
      '热门版块',
      '热帖榜',
      '新帖榜',
      '签到榜',
      '推荐用户',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('发现'),
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
          return Container(
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                items[index],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
