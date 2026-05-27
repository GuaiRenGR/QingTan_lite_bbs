import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class HomeChannel {
  final String label;
  final String value;

  const HomeChannel({
    required this.label,
    required this.value,
  });
}

class HomeChannelTabs extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const HomeChannelTabs({
    super.key,
    required this.current,
    required this.onChanged,
  });

  static const channels = [
    HomeChannel(label: '推荐', value: 'recommend'),
    HomeChannel(label: '热门', value: 'hot'),
    HomeChannel(label: '最新', value: 'latest'),
    HomeChannel(label: '精华', value: 'digest'),
    HomeChannel(label: '关注', value: 'follow'),
    HomeChannel(label: '图文', value: 'image'),
    HomeChannel(label: '问答', value: 'qa'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: AppColors.card(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (_, index) {
          final item = channels[index];
          final selected = current == item.value;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(item.value),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: selected ? 16 : 15,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? const Color(0xFFFB7299)
                            : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: selected ? 18 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFB7299),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemCount: channels.length,
      ),
    );
  }
}
