import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_controller.dart';
import '../discover/discover_page.dart';
import '../dynamic/dynamic_page.dart';
import '../home/home_page.dart';
import '../me/me_page.dart';
import '../post/create_post_page.dart';
import 'main_tab_provider.dart';

class MainShellPage extends ConsumerStatefulWidget {
  const MainShellPage({super.key});

  @override
  ConsumerState<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends ConsumerState<MainShellPage> {
  final _homeKey = GlobalKey<HomePageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkOnStart(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainTabIndexProvider);

    final pages = [
      HomePage(key: _homeKey),
      const DynamicPage(),
      const CreatePostPage(),
      const DiscoverPage(),
      const MePage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _ForumBottomNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          final prev = ref.read(mainTabIndexProvider);
          ref.read(mainTabIndexProvider.notifier).state = index;
          if (index == 0 && prev != 0) {
            _homeKey.currentState?.refreshCurrentFeed();
          }
        },
        onCreateThread: () {
          final auth = ref.read(authControllerProvider);
          if (!auth.loggedIn) {
            context.push('/login');
            return;
          }
          context.push('/thread/create');
        },
      ),
    );
  }
}

class _ForumBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCreateThread;

  const _ForumBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.onCreateThread,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _NavItem(
            index: 0,
            currentIndex: currentIndex,
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: '首页',
            onTap: onTap,
          ),
          _NavItem(
            index: 1,
            currentIndex: currentIndex,
            icon: Icons.bubble_chart_outlined,
            activeIcon: Icons.bubble_chart,
            label: '动态',
            onTap: onTap,
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCreateThread,
              child: Center(
                child: Container(
                  width: 48,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB7299),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFB7299).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          _NavItem(
            index: 3,
            currentIndex: currentIndex,
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore,
            label: '发现',
            onTap: onTap,
          ),
          _NavItem(
            index: 4,
            currentIndex: currentIndex,
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: '我的',
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;
    final color = active ? const Color(0xFFFB7299) : Colors.grey.shade600;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              size: 24,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
