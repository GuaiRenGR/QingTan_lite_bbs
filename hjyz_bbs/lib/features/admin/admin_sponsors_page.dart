import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';

class AdminSponsorsPage extends StatefulWidget {
  const AdminSponsorsPage({super.key});

  @override
  State<AdminSponsorsPage> createState() => _AdminSponsorsPageState();
}

class _AdminSponsorsPageState extends State<AdminSponsorsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ApiClient.instance.get('sponsors/list');
    if (!mounted) return;
    setState(() {
      final raw = result.success && result.data is Map
          ? (result.data as Map)['list']
          : null;
      _items = raw is List
          ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : const [];
      _loading = false;
    });
    if (!result.success) _showMessage(result.message);
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final amount = TextEditingController(
      text: item?['amount']?.toString() ?? '',
    );
    final message = TextEditingController(
      text: item?['message']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item == null ? '添加赞助记录' : '编辑赞助记录'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: '留名'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请输入赞助人留名' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '赞助金额',
                    prefixText: '¥ ',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    return parsed == null || parsed <= 0 ? '请输入有效金额' : null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: message,
                  maxLength: 500,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '留言（可选）'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, {
                'name': name.text.trim(),
                'amount': amount.text.trim(),
                'message': message.text.trim(),
              });
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    name.dispose();
    amount.dispose();
    message.dispose();
    if (data == null || !mounted) return;

    if (item != null) data['id'] = item['id'].toString();
    final result = await ApiClient.instance.post(
      item == null ? 'admin/sponsors/create' : 'admin/sponsors/update',
      data: data,
    );
    if (!mounted) return;
    _showMessage(result.message);
    if (result.success) await _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除赞助记录'),
        content: Text('确定删除“${item['name']}”的赞助记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ApiClient.instance.post(
      'admin/sponsors/delete',
      data: {'id': item['id']},
    );
    if (!mounted) return;
    _showMessage(result.message);
    if (result.success) await _load();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(title: const Text('赞助名单管理')),
      floatingActionButton: FloatingActionButton(
        tooltip: '添加赞助记录',
        onPressed: _edit,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        Icon(Icons.volunteer_activism_outlined, size: 44),
                        SizedBox(height: 12),
                        Center(child: Text('暂无赞助记录')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            title: Text(item['name']?.toString() ?? ''),
                            subtitle: Text(
                              item['message']?.toString().isNotEmpty == true
                                  ? item['message'].toString()
                                  : '无留言',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            leading: Text(
                              '¥${item['amount'] ?? '0.00'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _edit(item);
                                if (value == 'delete') _delete(item);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('编辑')),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('删除'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
