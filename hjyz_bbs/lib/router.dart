import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/creator/creator_center_page.dart';
import 'features/history/history_page.dart';
import 'features/main/main_shell_page.dart';
import 'features/me/settings_page.dart';
import 'features/message/messages_page.dart';
import 'features/message/notification_list_page.dart';
import 'features/message/chat_page.dart';
import 'features/message/notification_settings_page.dart';
import 'features/search/search_page.dart';
import 'features/thread/create_thread_page.dart';
import 'features/thread/thread_detail_page.dart';
import 'features/thread/dv_redirect_page.dart';
import 'features/profile/edit_profile_page.dart';
import 'features/admin/admin_center_page.dart';
import 'features/admin/admin_review_page.dart';
import 'features/admin/admin_users_page.dart';
import 'features/download/download_page.dart';
import 'features/user/user_home_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const MainShellPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (_, _) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (_, _) => const RegisterPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const SettingsPage(),
    ),
    GoRoute(
      path: '/messages',
      builder: (_, _) => const MessagesPage(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (_, state) {
        final type = state.uri.queryParameters['type'] ?? 'reply';
        return NotificationListPage(type: type);
      },
    ),
    GoRoute(
      path: '/chat',
      builder: (_, state) {
        final convId =
            int.tryParse(state.uri.queryParameters['conv_id'] ?? '') ?? 0;
        final userId =
            int.tryParse(state.uri.queryParameters['user_id'] ?? '') ?? 0;
        final nickname = state.uri.queryParameters['nickname'] ?? '用户';
        return ChatPage(
          conversationId: convId,
          targetUserId: userId,
          targetNickname: nickname,
        );
      },
    ),
    GoRoute(
      path: '/notification-settings',
      builder: (_, _) => const NotificationSettingsPage(),
    ),
    GoRoute(
      path: '/thread/create',
      builder: (_, state) {
        final forumId =
            int.tryParse(state.uri.queryParameters['forum_id'] ?? '') ?? 1;
        return CreateThreadPage(forumId: forumId);
      },
    ),
    GoRoute(
      path: '/thread/:id',
      builder: (_, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return ThreadDetailPage(threadId: id);
      },
    ),
    GoRoute(
      path: '/user/:id',
      builder: (_, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return UserHomePage(userId: id);
      },
    ),
    GoRoute(
      path: '/thread/:id/edit',
      builder: (_, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return CreateThreadPage(editThreadId: id);
      },
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (_, _) => const EditProfilePage(),
    ),
    GoRoute(
      path: '/search',
      builder: (_, _) => const SearchPage(),
    ),
    GoRoute(
      path: '/history',
      builder: (_, _) => const HistoryPage(),
    ),
    GoRoute(
      path: '/creator',
      builder: (_, _) => const CreatorCenterPage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (_, _) => const AdminCenterPage(),
    ),
    GoRoute(
      path: '/admin/users',
      builder: (_, _) => const AdminUsersPage(),
    ),
    GoRoute(
      path: '/admin/review',
      builder: (_, _) => const AdminReviewPage(),
    ),
    GoRoute(
      path: '/downloads',
      builder: (_, _) => const DownloadPage(),
    ),
    GoRoute(
      path: '/dv/:code',
      builder: (_, state) {
        final code = state.pathParameters['code'] ?? '';
        return DvRedirectPage(dvCode: code);
      },
    ),
  ],
  errorBuilder: (_, _) {
    return const Scaffold(
      body: Center(
        child: Text('页面不存在'),
      ),
    );
  },
);
