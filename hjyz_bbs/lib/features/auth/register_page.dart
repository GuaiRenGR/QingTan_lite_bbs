import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import 'auth_controller.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final usernameController = TextEditingController();
  final nicknameController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmController = TextEditingController();
  final captchaController = TextEditingController();

  late String captchaId;
  int captchaTs = DateTime.now().millisecondsSinceEpoch;

  bool obscure = true;

  @override
  void initState() {
    super.initState();
    captchaId = _newCaptchaId();
  }

  @override
  void dispose() {
    usernameController.dispose();
    nicknameController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    captchaController.dispose();
    super.dispose();
  }

  String _newCaptchaId() {
    return 'cap_${DateTime.now().microsecondsSinceEpoch}';
  }

  String get captchaUrl {
    return '${AppConfig.apiEntry}?route=captcha/image&captcha_id=$captchaId&t=$captchaTs';
  }

  void _refreshCaptcha() {
    setState(() {
      captchaId = _newCaptchaId();
      captchaTs = DateTime.now().millisecondsSinceEpoch;
      captchaController.clear();
    });
  }

  Future<void> _register() async {
    final username = usernameController.text.trim();
    final nickname = nicknameController.text.trim();
    final password = passwordController.text;
    final passwordConfirm = passwordConfirmController.text;
    final captcha = captchaController.text.trim();

    if (username.isEmpty ||
        password.isEmpty ||
        passwordConfirm.isEmpty ||
        captcha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整信息')),
      );
      return;
    }

    final ok = await ref.read(authControllerProvider.notifier).register(
          username: username,
          password: password,
          passwordConfirm: passwordConfirm,
          captchaId: captchaId,
          captcha: captcha,
          nickname: nickname.isEmpty ? null : nickname,
        );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
    } else {
      final error = ref.read(authControllerProvider).error ?? '注册失败';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      _refreshCaptcha();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('注册'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 24),
          const Text(
            '创建账号',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '注册后可发帖、回复、收藏和签到',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: usernameController,
            decoration: const InputDecoration(
              labelText: '用户名',
              hintText: '3-20位，字母、数字、下划线',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: nicknameController,
            decoration: const InputDecoration(
              labelText: '昵称',
              hintText: '可选，留空则显示用户名',
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
          const SizedBox(height: 14),
          TextField(
            controller: passwordConfirmController,
            obscureText: obscure,
            decoration: const InputDecoration(
              labelText: '确认密码',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: captchaController,
                  decoration: const InputDecoration(
                    labelText: '图片验证码',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _refreshCaptcha,
                child: Container(
                  width: 120,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    captchaUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return Center(
                        child: Text(
                          '点击刷新',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: auth.loading ? null : _register,
            child: auth.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('注册'),
          ),
        ],
      ),
    );
  }
}
