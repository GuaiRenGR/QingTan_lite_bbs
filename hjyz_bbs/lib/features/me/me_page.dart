import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_color_service.dart';
import '../../core/widgets/safe_network_image.dart';
import '../auth/auth_controller.dart';
import '../auth/login_page.dart';
import '../checkin/checkin_card.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  void _showThemeColors(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '主题色',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              ValueListenableBuilder<ThemeColorChoice>(
                valueListenable: ThemeColorService.selected,
                builder: (context, selected, _) => Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: ThemeColorService.choices.map((choice) {
                    final active = selected.id == choice.id;
                    return SizedBox(
                      width: 72,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          ThemeColorService.select(choice);
                          Navigator.pop(sheetContext);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: choice.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: active
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: active
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 7),
                              Text(
                                choice.label,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _appBarActions(BuildContext context) => [
    IconButton(
      tooltip: '主题色',
      onPressed: () => _showThemeColors(context),
      icon: const Icon(Icons.checkroom_outlined),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.offline,
      builder: (context, offline, _) =>
          _buildContent(context, ref, auth, offline),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AuthState auth,
    bool offline,
  ) {
    if (!auth.loggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('我的'),
          actions: _appBarActions(context),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '当前为游客模式',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '登录后可发帖、回复、收藏、签到',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
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
      if (groupId == 99)
        _MeAction(
          icon: Icons.view_stream_outlined,
          label: 'X 信息流',
          color: const Color(0xFF1D9BF0),
          onTap: () => context.push('/admin/x-feed'),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('我的'), actions: _appBarActions(context)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
        children: [
          if (offline) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFB7299).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 18,
                    color: Color(0xFFFB7299),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '离线模式 · 正在显示本地缓存信息',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.text(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          GestureDetector(
            onTap: userId > 0 ? () => context.push('/user/$userId') : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  SafeNetworkImage(
                    url: avatar,
                    width: 62,
                    height: 62,
                    borderRadius: BorderRadius.circular(31),
                    errorWidget: CircleAvatar(
                      radius: 31,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname,
                          style: const TextStyle(
                            fontSize: 18,
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
          const SizedBox(height: 10),
          const CheckinCard(),
          const SizedBox(height: 10),
          _QuickActionGrid(actions: actions),
          const SizedBox(height: 10),
          _MenuItem(
            icon: Icons.settings_outlined,
            text: '设置',
            onTap: () {
              context.push('/settings');
            },
          ),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.volunteer_activism_outlined,
            text: '赞助名单',
            onTap: () => context.push('/sponsors'),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisExtent: 76,
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
                const SizedBox(height: 5),
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
