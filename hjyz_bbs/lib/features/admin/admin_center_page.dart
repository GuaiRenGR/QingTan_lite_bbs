import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';

class AdminCenterPage extends StatefulWidget {
  const AdminCenterPage({super.key});

  @override
  State<AdminCenterPage> createState() => _AdminCenterPageState();
}

class _AdminCenterPageState extends State<AdminCenterPage> {
  bool loading = true;
  Map<String, dynamic> stats = {};
  bool requireReview = false;
  Map<String, String> downloadLinks = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadStats(), _loadSettings()]);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadSettings() async {
    final result = await ApiClient.instance.get('admin/settings/get');
    if (result.success && result.data is Map) {
      final data = result.data as Map;
      if (mounted) {
        setState(() {
          requireReview = data['require_review'] == '1';
          for (final key in ['android', 'ios', 'windows', 'macos', 'linux']) {
            downloadLinks[key] = (data['dl_$key'] ?? '').toString();
          }
        });
      }
    }
  }

  Future<void> _toggleReview(bool value) async {
    final result = await ApiClient.instance.post(
      'admin/settings/update',
      data: {
        'settings': {
          'require_review': value ? '1' : '0',
        },
      },
    );

    if (!mounted) return;

    if (result.success) {
      setState(() => requireReview = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? '已开启审核功能' : '已关闭审核功能')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _loadStats() async {
    final result = await ApiClient.instance.get('admin/stats');

    if (!mounted) return;

    if (result.success && result.data is Map) {
      setState(() {
        stats = Map<String, dynamic>.from(result.data as Map);
      });
    }
  }

  void _showSettingsDialog() {
    final dlCtrls = <String, TextEditingController>{};
    for (final key in ['android', 'ios', 'windows', 'macos', 'linux']) {
      dlCtrls[key] = TextEditingController(text: downloadLinks[key] ?? '');
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('系统设置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('发帖审核'),
                  subtitle: const Text('开启后普通用户发帖需审核'),
                  value: requireReview,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) {
                    _toggleReview(v);
                    setDialogState(() {});
                  },
                ),
                const Divider(height: 24),
                const Text(
                  '下载链接',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '配置后 download.php?os=xxx 将跳转到对应链接',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 12),
                _DownloadField(label: 'Android', controller: dlCtrls['android']!),
                const SizedBox(height: 8),
                _DownloadField(label: 'iOS', controller: dlCtrls['ios']!),
                const SizedBox(height: 8),
                _DownloadField(label: 'Windows', controller: dlCtrls['windows']!),
                const SizedBox(height: 8),
                _DownloadField(label: 'macOS', controller: dlCtrls['macos']!),
                const SizedBox(height: 8),
                _DownloadField(label: 'Linux', controller: dlCtrls['linux']!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _saveDownloadLinks(dlCtrls);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDownloadLinks(
      Map<String, TextEditingController> ctrls) async {
    final settings = <String, String>{};
    for (final entry in ctrls.entries) {
      settings['dl_${entry.key}'] = entry.value.text.trim();
    }

    final result = await ApiClient.instance.post(
      'admin/settings/update',
      data: {'settings': settings},
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        for (final entry in settings.entries) {
          downloadLinks[entry.key.replaceFirst('dl_', '')] = entry.value;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下载链接已保存')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(title: const Text('管理中心')),
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatsGrid(stats: stats, toInt: _toInt),
                const SizedBox(height: 20),
                _SectionTitle(title: '管理功能'),
                const SizedBox(height: 10),
                _AdminEntry(
                  icon: Icons.people_outline,
                  title: '用户管理',
                  subtitle: '查看、封禁、删除、新增用户',
                  onTap: () => context.push('/admin/users'),
                ),
                _AdminEntry(
                  icon: Icons.article_outlined,
                  title: '帖子管理',
                  subtitle: '查看、编辑、删除帖子',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('帖子管理开发中')),
                    );
                  },
                ),
                _AdminEntry(
                  icon: Icons.fact_check_outlined,
                  title: '内容审核',
                  subtitle: '审核待处理的帖子',
                  onTap: () => context.push('/admin/review'),
                ),
                _AdminEntry(
                  icon: Icons.forum_outlined,
                  title: '版块管理',
                  subtitle: '管理论坛分区和标签',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('版块管理开发中')),
                    );
                  },
                ),
                _AdminEntry(
                  icon: Icons.settings_outlined,
                  title: '系统设置',
                  subtitle: '审核开关、下载链接配置',
                  onTap: () => _showSettingsDialog(),
                ),
              ],
            ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  final int Function(dynamic) toInt;

  const _StatsGrid({required this.stats, required this.toInt});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(
        icon: Icons.people,
        label: '总用户',
        value: toInt(stats['user_count']),
        color: const Color(0xFFFB7299),
      ),
      _StatItem(
        icon: Icons.article,
        label: '总帖子',
        value: toInt(stats['thread_count']),
        color: const Color(0xFF4CAF50),
      ),
      _StatItem(
        icon: Icons.chat_bubble,
        label: '总评论',
        value: toInt(stats['post_count']),
        color: const Color(0xFF2196F3),
      ),
      _StatItem(
        icon: Icons.today,
        label: '今日新帖',
        value: toInt(stats['today_threads']),
        color: const Color(0xFFFF9800),
      ),
      _StatItem(
        icon: Icons.person_add,
        label: '今日注册',
        value: toInt(stats['today_users']),
        color: const Color(0xFF9C27B0),
      ),
      _StatItem(
        icon: Icons.block,
        label: '封禁用户',
        value: toInt(stats['banned_count']),
        color: const Color(0xFFF44336),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade700,
      ),
    );
  }
}

class _AdminEntry extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.card(context),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _DownloadField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _DownloadField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'https://...',
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
