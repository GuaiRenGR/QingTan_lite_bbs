import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  Map<String, bool> dnd = {
    'reply': false,
    'mention': false,
    'like': false,
    'system': false,
  };
  bool loading = true;

  static const _typeLabels = {
    'reply': '回复我的',
    'mention': '@我',
    'like': '收到的赞',
    'system': '系统通知',
  };

  static const _typeIcons = {
    'reply': Icons.chat_bubble_outline,
    'mention': Icons.alternate_email,
    'like': Icons.favorite_border,
    'system': Icons.notifications_none,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ApiClient.instance.get('notifications/dnd/get');

    if (!mounted) return;

    if (result.success && result.data is Map) {
      final data = result.data as Map;
      setState(() {
        dnd = {
          'reply': data['reply'] == 1,
          'mention': data['mention'] == 1,
          'like': data['like'] == 1,
          'system': data['system'] == 1,
        };
        loading = false;
      });
    } else {
      setState(() => loading = false);
    }
  }

  Future<void> _setDnd(String type, bool value) async {
    setState(() {
      dnd[type] = value;
    });

    final result = await ApiClient.instance.post(
      'notifications/dnd/set',
      data: {
        'type': type,
        'dnd': value ? 1 : 0,
      },
    );

    if (!result.success && mounted) {
      // 回滚
      setState(() {
        dnd[type] = !value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        title: const Text('消息设置'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '免打扰设置',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      ...dnd.entries.map((entry) {
                        final type = entry.key;
                        final isDnd = entry.value;
                        return SwitchListTile(
                          secondary: Icon(_typeIcons[type]),
                          title: Text(_typeLabels[type] ?? type),
                          subtitle: Text(isDnd ? '已开启免打扰' : '接收通知'),
                          value: isDnd,
                          onChanged: (value) => _setDnd(type, value),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '开启免打扰后，对应类型的通知将不再显示未读数，但通知记录仍会保留。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
