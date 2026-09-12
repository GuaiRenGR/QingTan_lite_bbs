import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/feed_display_service.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_controller.dart';
import '../discover/discover_page.dart';
import '../dynamic/dynamic_page.dart';
import '../home/home_page.dart';
import '../home/x_feed_page.dart';
import '../me/me_page.dart';
import '../message/messages_page.dart';
import '../post/create_post_page.dart';
import '../search/search_page.dart';
import 'main_tab_provider.dart';

class MainShellPage extends ConsumerStatefulWidget {
  const MainShellPage({super.key});

  @override
  ConsumerState<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends ConsumerState<MainShellPage> {
  final _homeKey = GlobalKey<HomePageState>();
  late List<Widget?> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget?>[HomePage(key: _homeKey), null, null, null, null];
    WidgetsBinding.instance.addPostFrameCallback((_) => UpdateService.checkOnStart(context));
  }

  Widget _createPage(int index, {required bool xMode}) {
    return switch (index) {
      0 => xMode ? const XFeedPage(adminOnly: false) : HomePage(key: _homeKey),
      1 => xMode ? const SearchPage() : const DynamicPage(),
      2 => const CreatePostPage(),
      3 => xMode ? const MessagesPage() : const DiscoverPage(),
      4 => const MePage(),
      _ => const SizedBox.shrink(),
    };
  }

  void _selectTab(int index) {
    final xMode = FeedDisplayService.xMode.value;
    _pages[index] ??= _createPage(index, xMode: xMode);
    final previousIndex = ref.read(mainTabIndexProvider);
    ref.read(mainTabIndexProvider.notifier).state = index;
    if (!xMode && index == 0 && previousIndex != 0) _homeKey.currentState?.refreshCurrentFeed();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: FeedDisplayService.xMode,
      builder: (context, xMode, _) {
        final currentIndex = ref.watch(mainTabIndexProvider);
        final expectedHome = xMode ? XFeedPage : HomePage;
        if (_pages[0].runtimeType != expectedHome) _pages = <Widget?>[null, null, null, null, null];
        _pages[currentIndex] ??= _createPage(currentIndex, xMode: xMode);
        return PopScope(
          canPop: currentIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && currentIndex != 0) ref.read(mainTabIndexProvider.notifier).state = 0;
          },
          child: Scaffold(
            body: IndexedStack(
              index: currentIndex,
              children: [for (var index = 0; index < _pages.length; index++) TickerMode(enabled: index == currentIndex, child: _pages[index] ?? const SizedBox.shrink())],
            ),
            bottomNavigationBar: _ForumBottomNavBar(
              currentIndex: currentIndex,
              xMode: xMode,
              onTap: _selectTab,
              onCreateThread: () {
                if (!ref.read(authControllerProvider).loggedIn) {
                  context.push('/login');
                } else {
                  context.push('/thread/create');
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class _ForumBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final bool xMode;
  final ValueChanged<int> onTap;
  final VoidCallback onCreateThread;

  const _ForumBottomNavBar({required this.currentIndex, required this.xMode, required this.onTap, required this.onCreateThread});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: AppColors.card(context), border: Border(top: BorderSide(color: AppColors.border(context), width: 0.5))),
      child: Row(
        children: [
          _NavItem(index: 0, currentIndex: currentIndex, icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: '首页', onTap: onTap),
          _NavItem(index: 1, currentIndex: currentIndex, icon: xMode ? Icons.search_outlined : Icons.bubble_chart_outlined, activeIcon: xMode ? Icons.search : Icons.bubble_chart, label: xMode ? '搜索' : '动态', onTap: onTap),
          Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onCreateThread, child: Center(child: Container(width: 44, height: 32, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 26))))),
          _NavItem(index: 3, currentIndex: currentIndex, icon: xMode ? Icons.notifications_none : Icons.build_outlined, activeIcon: xMode ? Icons.notifications : Icons.build_rounded, label: xMode ? '通知' : '工具', onTap: onTap),
          _NavItem(index: 4, currentIndex: currentIndex, icon: Icons.person_outline, activeIcon: Icons.person, label: '我的', onTap: onTap),
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

  const _NavItem({required this.index, required this.currentIndex, required this.icon, required this.activeIcon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;
    final color = active ? Theme.of(context).colorScheme.primary : AppColors.textSecondary(context);
    return Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onTap(index), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(active ? activeIcon : icon, size: 23, color: color), const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: active ? FontWeight.w600 : FontWeight.normal))])));
  }
}
