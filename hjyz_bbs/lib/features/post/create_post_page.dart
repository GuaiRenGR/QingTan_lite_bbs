import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/login_page.dart';

class CreatePostPage extends ConsumerWidget {
  const CreatePostPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (!auth.loggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('发布'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 70,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  '登录后可以发布帖子',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '你仍然可以以游客身份浏览首页和发现内容',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
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
                  child: const Text('去登录'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('发布帖子'),
      ),
      body: const Center(
        child: Text('发帖编辑器开发中'),
      ),
    );
  }
}
