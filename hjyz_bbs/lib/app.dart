import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/notification_service.dart';
import 'core/utils/deep_link_helper.dart';
import 'features/auth/auth_controller.dart';
import 'router.dart';

class ForumXApp extends ConsumerStatefulWidget {
  const ForumXApp({super.key});

  static const fontFallback = <String>[
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'Segoe UI',
    'Roboto',
    'Arial',
  ];

  @override
  ConsumerState<ForumXApp> createState() => _ForumXAppState();
}

class _ForumXAppState extends ConsumerState<ForumXApp>
    with WidgetsBindingObserver {
  bool _wasLoggedIn = false;
  StreamSubscription<Uri>? _linkSub;
  String? _pendingDeepLink;
  bool _deepLinkNavigationScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 延迟初始化通知服务
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNotifications();
    });

    // 监听 deep link
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    NotificationService().stopPolling();
    super.dispose();
  }

  void _initDeepLinks() {
    final appLinks = AppLinks();

    _loadInitialLink(appLinks);

    _linkSub = appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri);
    }, onError: (_) {});
  }

  Future<void> _loadInitialLink(AppLinks appLinks) async {
    try {
      final uri = await appLinks.getInitialLink();
      if (uri != null) _handleLink(uri);
    } catch (_) {}
  }

  void _handleLink(Uri uri) {
    final location = DeepLinkHelper.locationFor(uri);
    if (location == null) return;

    _pendingDeepLink = location;
    if (_deepLinkNavigationScheduled) return;

    _deepLinkNavigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deepLinkNavigationScheduled = false;
      if (!mounted) return;

      final target = _pendingDeepLink;
      _pendingDeepLink = null;
      if (target == null) return;

      final currentLocation = router.routeInformationProvider.value.uri.path;
      if (currentLocation != target) {
        router.push(target);
      }
    });
  }

  Future<void> _initNotifications() async {
    await NotificationService().initialize();
    _checkAuthAndPoll();
  }

  void _checkAuthAndPoll() {
    final auth = ref.read(authControllerProvider);
    final isLoggedIn = auth.loggedIn;

    if (isLoggedIn && !_wasLoggedIn) {
      // 刚登录，启动轮询
      NotificationService().startPolling();
    } else if (!isLoggedIn && _wasLoggedIn) {
      // 刚退出登录，停止轮询
      NotificationService().reset();
    }

    _wasLoggedIn = isLoggedIn;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final auth = ref.read(authControllerProvider);
    if (!auth.loggedIn) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // 应用恢复前台，立即检查一次并恢复轮询
        NotificationService().checkNow();
        NotificationService().startPolling();
        break;
      case AppLifecycleState.paused:
        // 应用进入后台，停止轮询节省资源
        NotificationService().stopPolling();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听登录状态变化
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      _checkAuthAndPoll();
    });

    return MaterialApp.router(
      title: '轻坛',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [
        Locale('zh', 'CN'),
      ],
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFB7299),
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        fontFamily: null,
        textTheme: ThemeData.light().textTheme.apply(
              fontFamilyFallback: ForumXApp.fontFallback,
            ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 52,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
        listTileTheme: const ListTileThemeData(
          dense: true,
          minVerticalPadding: 6,
          contentPadding: EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFB7299),
        brightness: Brightness.dark,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        fontFamily: null,
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamilyFallback: ForumXApp.fontFallback,
            ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          toolbarHeight: 52,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
        listTileTheme: const ListTileThemeData(
          dense: true,
          minVerticalPadding: 6,
          contentPadding: EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}
