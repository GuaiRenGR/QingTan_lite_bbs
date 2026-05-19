import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final accountController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscure = true;

  @override
  void dispose() {
    accountController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final account = accountController.text.trim();
    final password = passwordController.text;

    if (account.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入账号和密码')),
      );
      return;
    }

    final ok = await ref.read(authControllerProvider.notifier).login(
          account: account,
          password: password,
        );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
    } else {
      final error = ref.read(authControllerProvider).error ?? '登录失败';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('登录'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 40),
          const Text(
            '欢迎回来',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '不登录也可以浏览社区内容',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: accountController,
            decoration: const InputDecoration(
              labelText: '用户名 / 邮箱',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: '密码',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    obscure = !obscure;
                  });
                },
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: auth.loading ? null : _login,
            child: auth.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('登录'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              context.push('/register');
            },
            child: const Text('没有账号？立即注册'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('先不登录，继续浏览'),
          ),
        ],
      ),
    );
  }
}
