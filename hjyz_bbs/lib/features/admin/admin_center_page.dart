import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/services/database_backup_service.dart';
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
  bool aiReviewEnabled = false;
  String aiReviewBaseUrl = '';
  String aiReviewApiKey = '';
  String aiReviewModel = 'gpt-4o-mini';
  Map<String, String> downloadLinks = {};
  String contactUrl = '';
  bool backupDownloading = false;
  double backupProgress = 0;
  String? lastBackupPath;
  bool directUpload = false;

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
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          requireReview = data['require_review'] == '1';
          aiReviewEnabled = data['ai_review_enabled'] == '1';
          aiReviewBaseUrl = (data['ai_review_base_url'] ?? '').toString();
          aiReviewApiKey = (data['ai_review_api_key'] ?? '').toString();
          aiReviewModel = (data['ai_review_model'] ?? 'gpt-4o-mini').toString();
          directUpload = prefs.getBool('admin_direct_upload') ?? false;
          contactUrl = (data['contact_url'] ?? '').toString();
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
        'settings': {'require_review': value ? '1' : '0'},
      },
    );

    if (!mounted) return;

    if (result.success) {
      setState(() => requireReview = value);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value ? '已开启审核功能' : '已关闭审核功能')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
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
    final contactCtrl = TextEditingController(text: contactUrl);
    final aiUrlCtrl = TextEditingController(text: aiReviewBaseUrl);
    final aiKeyCtrl = TextEditingController(text: aiReviewApiKey);
    final aiModelCtrl = TextEditingController(text: aiReviewModel);
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
                const Text('管理员文件上传链路', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('服务器中转')),
                    ButtonSegment(value: true, label: Text('OneDrive直传')),
                  ],
                  selected: {directUpload},
                  onSelectionChanged: (values) => setDialogState(() => directUpload = values.first),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('AI内容审核'),
                  subtitle: const Text('使用OpenAI兼容completions接口，关闭思考并要求JSON返回'),
                  value: aiReviewEnabled,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => aiReviewEnabled = v),
                ),
                TextField(
                  controller: aiUrlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'completions接口地址', hintText: 'https://api.example.com/v1'),
                ),
                TextField(
                  controller: aiKeyCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'API Key'),
                ),
                TextField(
                  controller: aiModelCtrl,
                  decoration: const InputDecoration(labelText: '模型'),
                ),
                const Divider(height: 24),
                const Text(
                  '联系我们',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contactCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '跳转链接',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
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
                _DownloadField(
                  label: 'Android',
                  controller: dlCtrls['android']!,
                ),
                const SizedBox(height: 8),
                _DownloadField(label: 'iOS', controller: dlCtrls['ios']!),
                const SizedBox(height: 8),
                _DownloadField(
                  label: 'Windows',
                  controller: dlCtrls['windows']!,
                ),
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
                _saveSystemLinks(contactCtrl, dlCtrls, aiUrlCtrl, aiKeyCtrl, aiModelCtrl);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSystemLinks(
    TextEditingController contactCtrl,
    Map<String, TextEditingController> ctrls,
    TextEditingController aiUrlCtrl,
    TextEditingController aiKeyCtrl,
    TextEditingController aiModelCtrl,
  ) async {
    final settings = <String, String>{
      'contact_url': contactCtrl.text.trim(),
      'ai_review_enabled': aiReviewEnabled ? '1' : '0',
      'ai_review_base_url': aiUrlCtrl.text.trim(),
      'ai_review_api_key': aiKeyCtrl.text.trim(),
      'ai_review_model': aiModelCtrl.text.trim(),
    };
    for (final entry in ctrls.entries) {
      settings['dl_${entry.key}'] = entry.value.text.trim();
    }

    final result = await ApiClient.instance.post(
      'admin/settings/update',
      data: {'settings': settings},
    );

    if (!mounted) return;

    if (result.success) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      await prefs.setBool('admin_direct_upload', directUpload);
      if (!mounted) return;
      setState(() {
        contactUrl = settings['contact_url'] ?? '';
        aiReviewBaseUrl = settings['ai_review_base_url'] ?? '';
        aiReviewApiKey = settings['ai_review_api_key'] ?? '';
        aiReviewModel = settings['ai_review_model'] ?? aiReviewModel;
        for (final entry in settings.entries) {
          if (!entry.key.startsWith('dl_')) continue;
          downloadLinks[entry.key.replaceFirst('dl_', '')] = entry.value;
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('系统链接已保存')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  Future<void> _confirmDownloadBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载数据库备份'),
        content: const Text('备份包含账号、内容和系统配置等敏感数据，请下载后妥善保管。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.download_rounded),
            label: const Text('下载'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _downloadBackup();
    }
  }

  Future<void> _downloadBackup() async {
    if (backupDownloading) return;

    setState(() {
      backupDownloading = true;
      backupProgress = 0;
    });

    try {
      final result = await DatabaseBackupService.instance.download(
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          final nextProgress = received / total;
          if (nextProgress - backupProgress >= 0.01 || nextProgress >= 1) {
            setState(() => backupProgress = nextProgress.clamp(0.0, 1.0));
          }
        },
      );

      if (!mounted) return;

      setState(() {
        backupDownloading = false;
        backupProgress = 0;
        if (result.success) lastBackupPath = result.data;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.success ? '数据库备份已下载' : result.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        backupDownloading = false;
        backupProgress = 0;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法保存备份，请检查存储空间后重试')));
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
                  onTap: () => context.push('/admin/threads'),
                ),
                _AdminEntry(
                  icon: Icons.fact_check_outlined,
                  title: '内容审核',
                  subtitle: '审核待处理的帖子',
                  onTap: () => context.push('/admin/review'),
                ),
                _AdminEntry(
                  icon: Icons.volunteer_activism_outlined,
                  title: '赞助名单',
                  subtitle: '添加、编辑和删除赞助记录',
                  onTap: () => context.push('/admin/sponsors'),
                ),
                _AdminEntry(
                  icon: Icons.auto_awesome_outlined,
                  title: '小红书大字报生成器',
                  subtitle: '本地制作小红书风格图文海报并分享',
                  onTap: () => context.push('/admin/poster-generator'),
                ),
                _AdminEntry(
                  icon: Icons.campaign_outlined,
                  title: '发布系统通知',
                  subtitle: '向已注册用户或所有用户发布通知',
                  onTap: () => context.push('/admin/system-notification'),
                ),
                _AdminEntry(
                  icon: Icons.forum_outlined,
                  title: '版块管理',
                  subtitle: '管理论坛分区和标签',
                  onTap: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('版块管理开发中')));
                  },
                ),
                _AdminEntry(
                  icon: Icons.settings_outlined,
                  title: '系统设置',
                  subtitle: '审核开关、联系与下载链接配置',
                  onTap: () => _showSettingsDialog(),
                ),
                _AdminEntry(
                  icon: Icons.cloud_download_outlined,
                  title: '下载数据库备份',
                  subtitle: backupDownloading
                      ? (backupProgress > 0
                            ? '正在下载 ${(backupProgress * 100).toStringAsFixed(0)}%'
                            : '正在生成备份...')
                      : (lastBackupPath ?? '仅管理员可下载，服务端文件下载后自动删除'),
                  loading: backupDownloading,
                  onTap: backupDownloading ? null : _confirmDownloadBackup,
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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
  final VoidCallback? onTap;
  final bool loading;

  const _AdminEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
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
        trailing: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}
