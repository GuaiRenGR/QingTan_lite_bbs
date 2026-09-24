import 'package:flutter/material.dart';

import '../../core/services/api_cache_service.dart';
import '../../core/services/image_cache_service.dart';
import '../../core/services/local_chat_database.dart';
import '../../core/services/music_cache_service.dart';
import '../../core/theme/app_colors.dart';

class StorageManagementPage extends StatefulWidget {
  const StorageManagementPage({super.key});

  @override
  State<StorageManagementPage> createState() => _StorageManagementPageState();
}

class _StorageManagementPageState extends State<StorageManagementPage> {
  List<LocalChatConversation> _conversations = const [];
  bool _loading = true;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final rows = await LocalChatDatabase.instance.conversations();
    if (!mounted) return;
    setState(() {
      _conversations = rows;
      _loading = false;
    });
  }

  Future<void> _clearCaches() async {
    if (_clearing) return;
    setState(() => _clearing = true);
    await Future.wait([
      ApiCacheService.instance.clear(),
      ImageCacheService.instance.clearCache(),
      MusicCacheService.instance.clearCaches(),
    ]);
    if (!mounted) return;
    setState(() => _clearing = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('普通缓存已清理，聊天记录和下载文件未受影响')));
  }

  Future<void> _deleteConversation(LocalChatConversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除${conversation.title.isEmpty ? '聊天记录' : conversation.title}'),
        content: const Text('只删除本机保存的聊天记录，不会删除服务器上的消息。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    await LocalChatDatabase.instance.deleteConversation(conversation.key);
    if (mounted) _loadConversations();
  }

  Future<void> _deleteAllMessages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除全部本地聊天记录'),
        content: const Text('只删除本机数据库中的聊天记录，不会影响服务器。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('删除全部')),
        ],
      ),
    );
    if (confirmed != true) return;
    await LocalChatDatabase.instance.clearAll();
    if (mounted) _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(title: const Text('存储空间管理')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('清理普通缓存'),
              subtitle: const Text('清理图片、音乐和离线接口缓存，不会删除聊天记录或下载文件'),
              trailing: _clearing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
              onTap: _clearing ? null : _clearCaches,
            ),
          ),
          const SizedBox(height: 12),
          _SectionHeader(
            title: '本地聊天记录',
            action: _conversations.isEmpty ? null : TextButton(onPressed: _deleteAllMessages, child: const Text('全部删除')),
          ),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_conversations.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('暂无本地聊天记录')))
          else
            ..._conversations.map((conversation) => ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(conversation.title.isEmpty ? conversation.key : conversation.title),
                  subtitle: Text('${conversation.messageCount} 条本地消息'),
                  trailing: IconButton(onPressed: () => _deleteConversation(conversation), icon: const Icon(Icons.delete_outline), tooltip: '删除聊天记录'),
                )),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))), if (action != null) action!]);
  }
}
