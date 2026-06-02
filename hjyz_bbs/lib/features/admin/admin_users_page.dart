import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/safe_network_image.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  bool loadingMore = false;
  bool noMore = false;
  int page = 1;
  int total = 0;
  String keyword = '';
  List<Map<String, dynamic>> groups = [];

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
    _loadGroups();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadGroups() async {
    final result = await ApiClient.instance.get('admin/groups');
    if (!mounted) return;
    if (result.success && result.data is Map) {
      final data = result.data as Map;
      final list = (data['list'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() => groups = list);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load({required bool refresh}) async {
    if (refresh) {
      page = 1;
      noMore = false;
    }

    final result = await ApiClient.instance.get(
      'admin/users',
      query: {
        'page': page,
        'page_size': 20,
        if (keyword.isNotEmpty) 'keyword': keyword,
      },
    );

    if (!mounted) return;

    if (result.success && result.data is Map) {
      final data = result.data as Map;
      final list = (data['list'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      setState(() {
        if (refresh) items.clear();
        items.addAll(list);
        total = _toInt(data['total']);
        loading = false;
        loadingMore = false;
        noMore = list.isEmpty;
      });
    } else {
      setState(() {
        loading = false;
        loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (loading || loadingMore || noMore) return;
    setState(() => loadingMore = true);
    page++;
    await _load(refresh: false);
  }

  Future<void> _refresh() async {
    await _load(refresh: true);
  }

  void _onSearch() {
    keyword = _searchController.text.trim();
    _load(refresh: true);
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  void _showUserActions(Map<String, dynamic> user) {
    final userId = _toInt(user['id']);
    final nickname = user['nickname']?.toString() ?? '';
    final status = _toInt(user['status']);
    final groupId = _toInt(user['group_id']);
    final isBanned = status == 0;
    final isAdmin = groupId == 99;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  nickname,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined, color: Color(0xFFFB7299)),
                title: const Text('编辑资料'),
                subtitle: const Text('铭牌、认证标志'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditUserDialog(user);
                },
              ),
              if (!isAdmin) ...[
                ListTile(
                  leading: Icon(
                    isBanned ? Icons.lock_open : Icons.block,
                    color: isBanned ? Colors.green : Colors.orange,
                  ),
                  title: Text(isBanned ? '解封用户' : '封禁用户'),
                  onTap: () {
                    Navigator.pop(ctx);
                    isBanned ? _unbanUser(userId) : _banUser(userId);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('删除用户', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteUser(userId, nickname);
                  },
                ),
              ],
              if (isAdmin)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '管理员账户不可操作',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final userId = _toInt(user['id']);
    final currentGroupId = _toInt(user['group_id']);
    final badgeNameCtrl = TextEditingController(
      text: user['badge_name']?.toString() ?? '',
    );
    final badgeColorCtrl = TextEditingController(
      text: user['badge_color']?.toString() ?? '#FB7299',
    );
    int verifyLevel = _toInt(user['verify_level']);
    int selectedGroupId = currentGroupId;
    // 解析用户单独权限覆盖
    final userPerms = user['permissions'];
    Map<String, dynamic> permOverrides = {};
    if (userPerms is Map) {
      permOverrides = Map<String, dynamic>.from(userPerms);
    } else if (userPerms is String && userPerms.isNotEmpty) {
      try {
        final decoded = Map<String, dynamic>.from(
            const JsonDecoder().convert(userPerms) as Map);
        permOverrides = decoded;
      } catch (_) {}
    }
    // 常见权限列表
    final knownPerms = [
      _PermDef('thread.create', '发帖', true),
      _PermDef('post.create', '评论', true),
      _PermDef('thread.edit', '编辑帖子', true),
      _PermDef('thread.delete', '删除帖子', false),
      _PermDef('post.edit', '编辑评论', true),
      _PermDef('post.delete', '删除评论', false),
      _PermDef('user.follow', '关注用户', true),
      _PermDef('thread.report', '举报', true),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // 当前选中组的权限
          final selGroup = groups.firstWhere(
            (g) => _toInt(g['id']) == selectedGroupId,
            orElse: () => {},
          );
          final selGroupPerms = selGroup.isNotEmpty &&
                  selGroup['permissions'] is Map
              ? Map<String, dynamic>.from(selGroup['permissions'] as Map)
              : <String, dynamic>{};

          return AlertDialog(
            title: Text('编辑 ${user['nickname'] ?? ''}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 用户组选择
                  const Text('用户组',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (groups.isNotEmpty)
                    DropdownButtonFormField<int>(
                      initialValue: selectedGroupId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: groups.map((g) {
                        return DropdownMenuItem<int>(
                          value: _toInt(g['id']),
                          child: Text(
                              '${g['name']} (ID: ${g['id']})'),
                        );
                      }).toList(),
                      onChanged: currentGroupId == 99
                          ? null // 管理员用户组不可改
                          : (v) {
                              if (v != null) {
                                setDialogState(() {
                                  selectedGroupId = v;
                                  // 切换组时清除单独权限覆盖
                                  permOverrides.clear();
                                });
                              }
                            },
                    ),
                  if (currentGroupId == 99)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '管理员用户组不可更改',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 权限编辑
                  const Text('单独权限覆盖',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '覆盖用户组默认权限，留空则继承用户组设置',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  ...knownPerms.map((perm) {
                    // 有效权限 = 单独覆盖 > 组权限
                    final hasOverride = permOverrides.containsKey(perm.key);
                    final effectiveValue = hasOverride
                        ? permOverrides[perm.key] == true
                        : (selGroupPerms[perm.key] == true);
                    final groupValue = selGroupPerms[perm.key] == true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(perm.label,
                                    style: const TextStyle(fontSize: 14)),
                                Text(perm.key,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400)),
                              ],
                            ),
                          ),
                          // 当前值指示
                          if (hasOverride)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: effectiveValue
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                effectiveValue ? '允许' : '禁止',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: effectiveValue
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                '继承(${groupValue ? "允许" : "禁止"})',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400),
                              ),
                            ),
                          // 操作按钮
                          PopupMenuButton<String>(
                            onSelected: (action) {
                              setDialogState(() {
                                if (action == 'inherit') {
                                  permOverrides.remove(perm.key);
                                } else if (action == 'allow') {
                                  permOverrides[perm.key] = true;
                                } else if (action == 'deny') {
                                  permOverrides[perm.key] = false;
                                }
                              });
                            },
                            icon: Icon(Icons.tune,
                                size: 18, color: Colors.grey.shade500),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'inherit',
                                  child: Text('继承用户组')),
                              const PopupMenuItem(
                                  value: 'allow',
                                  child: Text('强制允许')),
                              const PopupMenuItem(
                                  value: 'deny',
                                  child: Text('强制禁止')),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('铭牌',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: badgeNameCtrl,
                    decoration: const InputDecoration(
                      labelText: '铭牌文字',
                      hintText: '2-5字，留空则清除',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: badgeColorCtrl,
                    decoration: const InputDecoration(
                      labelText: '铭牌颜色',
                      hintText: '#FB7299',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('认证标志',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _VerifyChip(
                        label: '无',
                        color: Colors.grey,
                        selected: verifyLevel == 0,
                        onTap: () =>
                            setDialogState(() => verifyLevel = 0),
                      ),
                      _VerifyChip(
                        label: '已认证',
                        color: const Color(0xFF4CAF50),
                        selected: verifyLevel == 1,
                        onTap: () =>
                            setDialogState(() => verifyLevel = 1),
                      ),
                      _VerifyChip(
                        label: '官方',
                        color: const Color(0xFF2196F3),
                        selected: verifyLevel == 2,
                        onTap: () =>
                            setDialogState(() => verifyLevel = 2),
                      ),
                      _VerifyChip(
                        label: '知名人物',
                        color: const Color(0xFFFFB300),
                        selected: verifyLevel == 3,
                        onTap: () =>
                            setDialogState(() => verifyLevel = 3),
                      ),
                    ],
                  ),
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
                  _updateUser(
                    userId,
                    badgeNameCtrl.text.trim(),
                    badgeColorCtrl.text.trim(),
                    verifyLevel,
                    groupId: selectedGroupId,
                    permissions: permOverrides,
                  );
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateUser(
    int userId,
    String badgeName,
    String badgeColor,
    int verifyLevel, {
    int? groupId,
    Map<String, dynamic>? permissions,
  }) async {
    final result = await ApiClient.instance.post(
      'admin/user/update',
      data: {
        'user_id': userId,
        'badge_name': badgeName,
        'badge_color': badgeColor,
        'verify_level': verifyLevel,
        'group_id': ?groupId,
        if (permissions != null && permissions.isNotEmpty)
          'permissions': permissions,
      },
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已更新')),
      );
      _load(refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _banUser(int userId) async {
    final result = await ApiClient.instance.post(
      'admin/user/ban',
      data: {'user_id': userId},
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已封禁')),
      );
      _load(refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _unbanUser(int userId) async {
    final result = await ApiClient.instance.post(
      'admin/user/unban',
      data: {'user_id': userId},
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已解封')),
      );
      _load(refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _deleteUser(int userId, String nickname) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除用户「$nickname」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await ApiClient.instance.post(
      'admin/user/delete',
      data: {'user_id': userId},
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除')),
      );
      _load(refresh: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  void _showCreateDialog() {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nicknameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增用户'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: '3-20位，中文/字母/数字/下划线',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nicknameCtrl,
              decoration: const InputDecoration(
                labelText: '昵称（可选）',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码',
                hintText: '8-32位',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _createUser(
                usernameCtrl.text.trim(),
                passwordCtrl.text,
                nicknameCtrl.text.trim(),
              );
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  Future<void> _createUser(
    String username,
    String password,
    String nickname,
  ) async {
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户名和密码不能为空')),
      );
      return;
    }

    final result = await ApiClient.instance.post(
      'admin/user/create',
      data: {
        'username': username,
        'password': password,
        if (nickname.isNotEmpty) 'nickname': nickname,
      },
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户创建成功')),
      );
      _load(refresh: true);
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
      appBar: AppBar(
        title: Text('管理中心 ($total)'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索用户名或昵称',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    if (keyword.isNotEmpty) {
                      keyword = '';
                      _load(refresh: true);
                    }
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                filled: true,
                fillColor: AppColors.inputFill(context),
              ),
              onSubmitted: (_) => _onSearch(),
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(
            child: loading && items.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : items.isEmpty
                    ? Center(
                        child: Text(
                          '暂无用户',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          controller: _scrollController,
                          itemCount: items.length + 1,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 0.5),
                          itemBuilder: (context, index) {
                            if (index == items.length) {
                              if (loadingMore) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }
                              if (noMore) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      '没有更多了',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox(height: 20);
                            }

                            final user = items[index];
                            return _UserRow(
                              user: user,
                              onTap: () => _showUserActions(user),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const _UserRow({required this.user, required this.onTap});

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _toInt(user['id']);
    final nickname = user['nickname']?.toString() ?? '';
    final username = user['username']?.toString() ?? '';
    final avatar = user['avatar']?.toString() ?? '';
    final groupId = _toInt(user['group_id']);
    final status = _toInt(user['status']);
    final createdAt = user['created_at']?.toString() ?? '';

    final isBanned = status == 0;
    final isAdmin = groupId == 99;

    return ListTile(
      onTap: onTap,
      leading: SafeNetworkImage(
        url: avatar,
        width: 44,
        height: 44,
        borderRadius: BorderRadius.circular(22),
        errorWidget: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.grey.shade200,
          child: Icon(Icons.person, color: Colors.grey.shade500),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFB7299).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '管理',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFFFB7299),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (isBanned) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '已封禁',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        'ID: $id · @$username · 注册于 ${_formatTime(createdAt)}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }
}

class _VerifyChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _VerifyChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.check, size: 14, color: color),
              ),
            if (color != Colors.grey && label != '无')
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  'V',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? color : Colors.grey.shade700,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermDef {
  final String key;
  final String label;
  final bool defaultValue;

  const _PermDef(this.key, this.label, this.defaultValue);
}
