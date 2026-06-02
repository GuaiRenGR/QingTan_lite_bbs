import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import 'auth_controller.dart';

class AccountSecurityPage extends ConsumerStatefulWidget {
  const AccountSecurityPage({super.key});

  @override
  ConsumerState<AccountSecurityPage> createState() =>
      _AccountSecurityPageState();
}

class _AccountSecurityPageState extends ConsumerState<AccountSecurityPage> {
  bool loadingSessions = true;
  List<Map<String, dynamic>> sessions = [];

  // 修改密码
  final oldPwdController = TextEditingController();
  final newPwdController = TextEditingController();
  final confirmPwdController = TextEditingController();
  bool changingPwd = false;
  bool showOldPwd = false;
  bool showNewPwd = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    oldPwdController.dispose();
    newPwdController.dispose();
    confirmPwdController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final result = await ApiClient.instance.get('auth/sessions');
    if (!mounted) return;

    if (result.success && result.data is Map) {
      final data = result.data as Map<String, dynamic>;
      final list = data['sessions'] as List? ?? [];
      setState(() {
        sessions = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        loadingSessions = false;
      });
    } else {
      setState(() => loadingSessions = false);
    }
  }

  Future<void> _changePassword() async {
    final oldPwd = oldPwdController.text;
    final newPwd = newPwdController.text;
    final confirmPwd = confirmPwdController.text;

    if (oldPwd.isEmpty || newPwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整')),
      );
      return;
    }

    if (newPwd.length < 8 || newPwd.length > 32) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新密码长度需为 8-32 位')),
      );
      return;
    }

    if (newPwd != confirmPwd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次新密码不一致')),
      );
      return;
    }

    setState(() => changingPwd = true);

    final result = await ApiClient.instance.post(
      'auth/change-password',
      data: {
        'old_password': oldPwd,
        'new_password': newPwd,
        'confirm_password': confirmPwd,
      },
    );

    if (!mounted) return;
    setState(() => changingPwd = false);

    if (result.success) {
      oldPwdController.clear();
      newPwdController.clear();
      confirmPwdController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码已修改')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _revokeSession(int sessionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('撤销会话'),
        content: const Text('确定要撤销该设备的登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('撤销'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await ApiClient.instance.post(
      'auth/revoke-session',
      data: {'session_id': sessionId},
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        sessions.removeWhere((s) => s['id'] == sessionId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已撤销')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  String _parseUA(String ua) {
    if (ua.isEmpty) return '未知设备';
    if (ua.contains('Flutter')) return '轻坛 App';
    if (ua.contains('Android')) return 'Android 设备';
    if (ua.contains('iPhone') || ua.contains('iPad')) return 'iOS 设备';
    if (ua.contains('Windows')) return 'Windows';
    if (ua.contains('Mac')) return 'macOS';
    if (ua.contains('Linux')) return 'Linux';
    if (ua.contains('Chrome')) return 'Chrome 浏览器';
    if (ua.contains('Firefox')) return 'Firefox';
    if (ua.contains('Safari')) return 'Safari';
    return ua.length > 40 ? '${ua.substring(0, 40)}...' : ua;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final username = user?['username']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(title: const Text('账号与安全')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 账号信息
          _Section(
            title: '账号信息',
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('用户名'),
                subtitle: Text(username),
                trailing: const Icon(Icons.lock_outline, size: 18),
              ),
            ],
          ),

          // 修改密码
          _Section(
            title: '修改密码',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: oldPwdController,
                  obscureText: !showOldPwd,
                  decoration: InputDecoration(
                    labelText: '当前密码',
                    suffixIcon: IconButton(
                      icon: Icon(showOldPwd
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => showOldPwd = !showOldPwd),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: newPwdController,
                  obscureText: !showNewPwd,
                  decoration: InputDecoration(
                    labelText: '新密码',
                    suffixIcon: IconButton(
                      icon: Icon(showNewPwd
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => showNewPwd = !showNewPwd),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: confirmPwdController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '确认新密码',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: changingPwd ? null : _changePassword,
                    child: changingPwd
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('修改密码'),
                  ),
                ),
              ),
            ],
          ),

          // 登录设备
          _Section(
            title: '登录设备',
            children: loadingSessions
                ? const [
                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ]
                : sessions.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              '暂无登录记录',
                              style: TextStyle(
                                  color: Colors.grey.shade500),
                            ),
                          ),
                        ),
                      ]
                    : sessions.map((s) {
                        final ua =
                            (s['user_agent'] ?? '').toString();
                        final ip = (s['ip'] ?? '').toString();
                        final time =
                            (s['created_at'] ?? '').toString();

                        return ListTile(
                          leading: const Icon(
                              Icons.devices_other_outlined),
                          title: Text(_parseUA(ua)),
                          subtitle: Text(
                            '$ip · $time',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.close,
                                size: 18,
                                color: Colors.grey.shade400),
                            onPressed: () =>
                                _revokeSession(s['id'] as int),
                          ),
                        );
                      }).toList(),
          ),

          // 退出登录
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('退出登录'),
                    content: const Text('确定要退出当前账号吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('退出'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (mounted) context.go('/');
                }
              },
              child: const Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
