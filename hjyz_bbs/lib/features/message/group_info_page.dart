import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/safe_network_image.dart';

class GroupInfoPage extends StatefulWidget {
  final int groupId;
  final String initialName;

  const GroupInfoPage({super.key, required this.groupId, required this.initialName});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  Map<String, dynamic> info = {};
  List<Map<String, dynamic>> members = [];
  bool loading = true;

  int _toInt(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      ApiClient.instance.get('groups/info', query: {'group_id': widget.groupId}),
      ApiClient.instance.get('groups/members', query: {'group_id': widget.groupId}),
    ]);
    if (!mounted) return;
    final groupResult = results[0];
    final memberResult = results[1];
    setState(() {
      if (groupResult.success && groupResult.data is Map) {
        info = Map<String, dynamic>.from(groupResult.data as Map);
      }
      if (memberResult.success && memberResult.data is Map) {
        members = ((memberResult.data as Map)['list'] as List? ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      loading = false;
    });
  }

  Future<void> _edit(String field, String title, String value, int maxLength) async {
    final controller = TextEditingController(text: value);
    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: field == 'announcement' ? 6 : 1,
          decoration: InputDecoration(labelText: title),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    controller.dispose();
    if (next == null || next == value || !mounted) return;
    final result = await ApiClient.instance.post('groups/update', data: {'group_id': widget.groupId, field: next});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) _load();
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final id = _toInt(member['user_id']);
    final result = await ApiClient.instance.post('groups/remove-member', data: {'group_id': widget.groupId, 'user_id': id});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) _load();
  }

  Future<void> _toggleMute(Map<String, dynamic> member) async {
    final muted = (member['muted_until']?.toString() ?? '').isNotEmpty;
    final minutes = muted ? 0 : 60;
    final result = await ApiClient.instance.post('groups/mute-member', data: {
      'group_id': widget.groupId,
      'user_id': _toInt(member['user_id']),
      'minutes': minutes,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) _load();
  }

  Future<void> _toggleAdmin(Map<String, dynamic> member) async {
    final isAdmin = member['role']?.toString() == 'admin';
    final result = await ApiClient.instance.post('groups/set-role', data: {
      'group_id': widget.groupId,
      'user_id': _toInt(member['user_id']),
      'role': isAdmin ? 'member' : 'admin',
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) _load();
  }

  Future<void> _leave() async {
    final result = await ApiClient.instance.post('groups/leave', data: {'group_id': widget.groupId});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) Navigator.pop(context, true);
  }

  Future<void> _dismiss() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('解散群聊'),
        content: const Text('解散后所有成员将无法继续访问群聊和历史消息。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('解散')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ApiClient.instance.post('groups/dismiss', data: {'group_id': widget.groupId});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final name = info['name']?.toString() ?? widget.initialName;
    final role = info['role']?.toString() ?? 'member';
    final canManage = role == 'owner' || role == 'admin';
    final isOwner = role == 'owner';
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(title: const Text('群聊资料')),
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  ListTile(
                    leading: CircleAvatar(child: Text(name.isEmpty ? '群' : name.substring(0, 1))),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('群号 ${info['group_no'] ?? '-'} · ${info['member_count'] ?? members.length} 人'),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_outlined),
                      tooltip: '复制群号',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: info['group_no']?.toString() ?? ''));
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('群号已复制')));
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.campaign_outlined),
                    title: const Text('群公告'),
                    subtitle: Text((info['announcement']?.toString() ?? '').isEmpty ? '暂无公告' : info['announcement'].toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
                    trailing: canManage ? const Icon(Icons.chevron_right) : null,
                    onTap: canManage ? () => _edit('announcement', '群公告', info['announcement']?.toString() ?? '', 2000) : null,
                  ),
                  if (canManage)
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('修改群名称'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _edit('name', '群名称', name, 80),
                    ),
                  const Divider(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text('群成员 (${members.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  ...members.map((member) {
                    final memberRole = member['role']?.toString() ?? 'member';
                    final nickname = member['nickname']?.toString() ?? member['username']?.toString() ?? '用户';
                    return ListTile(
                      leading: SafeNetworkImage(url: member['avatar']?.toString() ?? '', width: 42, height: 42, borderRadius: BorderRadius.circular(21), errorWidget: const CircleAvatar(child: Icon(Icons.person_outline))),
                      title: Text(nickname),
                      subtitle: memberRole == 'owner' ? const Text('群主') : (memberRole == 'admin' ? const Text('管理员') : null),
                      trailing: canManage && memberRole != 'owner' && !(memberRole == 'admin' && !isOwner)
                          ? PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'mute') {
                                  _toggleMute(member);
                                } else if (action == 'role') {
                                  _toggleAdmin(member);
                                } else {
                                  _removeMember(member);
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'mute', child: Text((member['muted_until']?.toString() ?? '').isEmpty ? '禁言 1 小时' : '解除禁言')),
                                if (isOwner) PopupMenuItem(value: 'role', child: Text(memberRole == 'admin' ? '取消管理员' : '设为管理员')),
                                const PopupMenuItem(value: 'remove', child: Text('移出群聊')),
                              ],
                            )
                          : null,
                    );
                  }),
                  const Divider(height: 8),
                  if (!isOwner)
                    ListTile(leading: const Icon(Icons.logout, color: Colors.orange), title: const Text('退出群聊'), onTap: _leave),
                  if (isOwner)
                    ListTile(leading: const Icon(Icons.delete_forever_outlined, color: Colors.red), title: const Text('解散群聊', style: TextStyle(color: Colors.red)), onTap: _dismiss),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
