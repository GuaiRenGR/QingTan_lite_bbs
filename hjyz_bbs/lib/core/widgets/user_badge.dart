import 'package:flutter/material.dart';

/// 用户铭牌标签，显示在昵称后方
/// 类似 B 站粉丝勋章样式
class UserBadge extends StatelessWidget {
  final String name;
  final String color;

  const UserBadge({
    super.key,
    required this.name,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const SizedBox.shrink();

    final badgeColor = _parseColor(color);

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            badgeColor.withValues(alpha: 0.85),
            badgeColor,
          ],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }

  static Color _parseColor(String hex) {
    if (hex.isEmpty) return const Color(0xFFFB7299);
    var h = hex.replaceAll('#', '');
    if (h.length == 6) {
      h = 'FF$h';
    }
    final value = int.tryParse(h, radix: 16);
    if (value == null) return const Color(0xFFFB7299);
    return Color(value);
  }
}
