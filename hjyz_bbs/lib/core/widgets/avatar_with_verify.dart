import 'package:flutter/material.dart';

import 'safe_network_image.dart';

/// 带认证标志的头像
/// 认证等级：0=无, 1=已认证(绿V), 2=官方(蓝V), 3=知名人物(金V)
class AvatarWithVerify extends StatelessWidget {
  final String avatarUrl;
  final double size;
  final int verifyLevel;
  final VoidCallback? onTap;

  const AvatarWithVerify({
    super.key,
    required this.avatarUrl,
    required this.size,
    this.verifyLevel = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeSize = size * 0.35;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SafeNetworkImage(
              url: avatarUrl,
              width: size,
              height: size,
              borderRadius: BorderRadius.circular(size / 2),
              errorWidget: CircleAvatar(
                radius: size / 2,
                backgroundColor: Colors.grey.shade200,
                child: Icon(
                  Icons.person,
                  size: size * 0.5,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            if (verifyLevel > 0)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    color: _badgeColor(verifyLevel),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: badgeSize * 0.12,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'V',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: badgeSize * 0.55,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Color _badgeColor(int level) {
    switch (level) {
      case 1:
        return const Color(0xFF4CAF50); // 绿V - 已认证
      case 2:
        return const Color(0xFF2196F3); // 蓝V - 官方
      case 3:
        return const Color(0xFFFFB300); // 金V - 知名人物
      default:
        return Colors.transparent;
    }
  }
}
