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

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
    _scrollController.addListener(_onScroll);
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
