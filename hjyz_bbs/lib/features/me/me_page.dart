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
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
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
    final groupId = int.tryParse(user['group_id']?.toString() ?? '') ?? 0;
    final nickname = user['nickname']?.toString() ?? '用户';
    final score = user['score']?.toString() ?? '0';
    final avatar = user['avatar']?.toString() ?? '';
    final actions = <_MeAction>[
      _MeAction(
        icon: Icons.mail_outline,
        label: '消息',
        color: const Color(0xFFFB7299),
        onTap: () => context.push('/messages'),
      ),
      _MeAction(
        icon: Icons.article_outlined,
        label: '我的帖子',
        color: const Color(0xFFFF9800),
        onTap: () => context.push('/user/$userId'),
      ),
      _MeAction(
        icon: Icons.star_border_rounded,
        label: '我的收藏',
        color: const Color(0xFFFFB300),
        onTap: () => context.push('/user/$userId'),
      ),
      _MeAction(
        icon: Icons.history_rounded,
        label: '浏览历史',
        color: const Color(0xFF42A5F5),
        onTap: () => context.push('/history'),
      ),
      _MeAction(
        icon: Icons.dashboard_customize_outlined,
        label: '创作中心',
        color: const Color(0xFFAB47BC),
        onTap: () => context.push('/creator'),
      ),
      _MeAction(
        icon: Icons.download_outlined,
        label: '下载管理',
        color: const Color(0xFF26A69A),
        onTap: () => context.push('/downloads'),
      ),
      _MeAction(
        icon: Icons.security_outlined,
        label: '账号安全',
        color: const Color(0xFF5C6BC0),
        onTap: () => context.push('/account-security'),
      ),
      _MeAction(
        icon: Icons.person_outline_rounded,
        label: '个人主页',
        color: const Color(0xFF66BB6A),
        onTap: () => context.push('/user/$userId'),
      ),
      if (groupId >= 50)
        _MeAction(
          icon: Icons.fact_check_outlined,
          label: '内容审核',
          color: const Color(0xFFEF5350),
          onTap: () => context.push('/admin/review'),
        ),
      if (groupId == 99)
        _MeAction(
          icon: Icons.admin_panel_settings_outlined,
          label: '管理中心',
          color: const Color(0xFFEC407A),
          onTap: () => context.push('/admin'),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          GestureDetector(
            onTap: userId > 0 ? () => context.push('/user/$userId') : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border(context)),
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
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                      ),
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
                        Text(
                          '积分 $score',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '点击进入个人主页',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
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
          _QuickActionGrid(actions: actions),
          const SizedBox(height: 14),
          _MenuItem(
            icon: Icons.settings_outlined,
            text: '设置',
            onTap: () {
              context.push('/settings');
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(text),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  final List<_MeAction> actions;

  const _QuickActionGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisExtent: 82,
          crossAxisSpacing: 2,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final action = actions[index];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: action.onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, color: action.color, size: 23),
                ),
                const SizedBox(height: 7),
                Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MeAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
