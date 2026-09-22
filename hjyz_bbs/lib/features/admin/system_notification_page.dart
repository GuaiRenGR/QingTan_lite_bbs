import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';

class SystemNotificationPage extends StatefulWidget {
  const SystemNotificationPage({super.key});

  @override
  State<SystemNotificationPage> createState() => _SystemNotificationPageState();
}

class _SystemNotificationPageState extends State<SystemNotificationPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  String _audience = 'registered';
  bool _publishing = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入通知标题')));
      return;
    }
    setState(() => _publishing = true);
    final result = await ApiClient.instance.post(
      'admin/notifications/publish',
      data: {'title': title, 'content': content, 'audience': _audience},
    );
    if (!mounted) return;
    setState(() => _publishing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.success ? '系统通知已发布' : result.message)));
    if (result.success) {
      _title.clear();
      _content.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(title: const Text('发布系统通知')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('通知内容', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            maxLength: 100,
            decoration: const InputDecoration(labelText: '标题', hintText: '例如：版本更新说明', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 7,
            maxLines: 14,
            maxLength: 10000,
            decoration: const InputDecoration(labelText: '正文', hintText: '输入用户将在私信页看到的通知内容', alignLabelWithHint: true, border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          Text('发布范围', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          RadioListTile<String>(
            value: 'registered',
            groupValue: _audience,
            onChanged: (v) => setState(() => _audience = v!),
            title: const Text('仅对已注册用户发布'),
            subtitle: const Text('按当前已注册用户生成通知记录'),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            value: 'all',
            groupValue: _audience,
            onChanged: (v) => setState(() => _audience = v!),
            title: const Text('为所有用户发布'),
            subtitle: const Text('使用广播记录，新注册用户也可以看到'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _publishing ? null : _publish,
            icon: _publishing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_outlined),
            label: Text(_publishing ? '正在发布...' : '发布通知'),
          ),
        ],
      ),
    );
  }
}
