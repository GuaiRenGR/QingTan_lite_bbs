import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/safe_network_image.dart';
import '../auth/auth_controller.dart';
import '../auth/login_page.dart';
import '../checkin/checkin_card.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (!auth.loggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('我的'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.grey.shade200,
                  child: Icon(
                    Icons.person_outline,
                    size: 44,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '当前为游客模式',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '登录后可发帖、回复、收藏、签到',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                  },
                  child: const Text('登录 / 注册'),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    context.push('/settings');
                  },
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('设置'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = auth.user ?? {};
    final userId = int.tryParse(user['id']?.toString() ?? '') ?? 0;
    final nickname = user['nickname']?.toString() ?? '用户';
    final score = user['score']?.toString() ?? '0';
    final avatar = user['avatar']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: userId > 0 ? () => context.push('/user/$userId') : null,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  SafeNetworkImage(
                    url: avatar,
                    width: 68,
                    height: 68,
                    borderRadius: BorderRadius.circular(34),
                    errorWidget: CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.pink.shade50,
                      child: const Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('积分：$score'),
                        const SizedBox(height: 4),
                        Text(
                          '点击进入个人主页',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const CheckinCard(),
          const SizedBox(height: 14),
          _MenuItem(
            icon: Icons.mail_outline,
            text: '消息',
            onTap: () {
              context.push('/messages');
            },
          ),
          _MenuItem(
            icon: Icons.article_outlined,
            text: '我的帖子',
            onTap: () {
              if (userId > 0) context.push('/user/$userId');
            },
          ),
          _MenuItem(
            icon: Icons.star_border,
            text: '我的收藏',
            onTap: () {
              if (userId > 0) context.push('/user/$userId');
            },
          ),
          _MenuItem(
            icon: Icons.dashboard_customize_outlined,
            text: '创作中心',
            onTap: () {
              context.push('/creator');
            },
          ),
          _MenuItem(
            icon: Icons.history_rounded,
            text: '浏览历史',
            onTap: () {
              context.push('/history');
            },
          ),
          if ((user['group_id'] ?? 0) >= 50)
            _MenuItem(
              icon: Icons.fact_check_outlined,
              text: '内容审核',
              onTap: () {
                context.push('/admin/review');
              },
            ),
          if ((user['group_id'] ?? 0) == 99)
            _MenuItem(
              icon: Icons.admin_panel_settings_outlined,
              text: '管理中心',
              onTap: () {
                context.push('/admin');
              },
            ),
          _MenuItem(
            icon: Icons.settings_outlined,
            text: '设置',
            onTap: () {
              context.push('/settings');
            },
          ),
          _MenuItem(
            icon: Icons.logout,
            text: '退出登录',
            onTap: () {
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.card(context),
      child: ListTile(
        leading: Icon(icon),
        title: Text(text),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
