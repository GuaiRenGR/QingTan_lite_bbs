import 'package:flutter/material.dart';

import '../../core/services/multi_server_package_service.dart';
import '../../core/theme/app_colors.dart';

class MultiServerGeneratorPage extends StatefulWidget {
  const MultiServerGeneratorPage({super.key});

  @override
  State<MultiServerGeneratorPage> createState() => _MultiServerGeneratorPageState();
}

class _ServerRow {
  final name = TextEditingController();
  final url = TextEditingController();
  final weight = TextEditingController(text: '10');

  void dispose() {
    name.dispose();
    url.dispose();
    weight.dispose();
  }
}

class _MultiServerGeneratorPageState extends State<MultiServerGeneratorPage> {
  final _dbName = TextEditingController();
  final _dbPassword = TextEditingController();
  final _rows = <_ServerRow>[_ServerRow()];
  bool _busy = false;
  double _progress = 0;

  @override
  void dispose() {
    _dbName.dispose();
    _dbPassword.dispose();
    for (final row in _rows) row.dispose();
    super.dispose();
  }

  void _addRow() {
    if (_rows.length >= 32) return;
    setState(() => _rows.add(_ServerRow()));
  }

  Future<void> _generate() async {
    final servers = <Map<String, dynamic>>[];
    for (final row in _rows) {
      final url = row.url.text.trim();
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty || !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
        _show('请填写有效的 HTTP/HTTPS 服务器地址');
        return;
      }
      servers.add({
        'name': row.name.text.trim(),
        'url': url,
        'weight': int.tryParse(row.weight.text.trim()) ?? 1,
      });
    }
    setState(() {
      _busy = true;
      _progress = 0;
    });
    final result = await MultiServerPackageService.instance.download(
      data: {
        'servers': servers,
        'db_name': _dbName.text.trim(),
        'db_password': _dbPassword.text,
      },
      onProgress: (received, total) {
        if (!mounted || total <= 0) return;
        setState(() => _progress = (received / total).clamp(0, 1));
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _show(result.success ? '部署包已保存：${result.data}' : result.message);
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(title: const Text('生成多服务器部署包')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('服务器节点', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('部署包包含当前数据库备份、服务端和安装脚本。每个节点都使用同一份配置。', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          ..._rows.asMap().entries.map((entry) => _rowCard(entry.key, entry.value)),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(onPressed: _busy ? null : _addRow, icon: const Icon(Icons.add), label: const Text('添加服务器')),
          ),
          const Divider(height: 28),
          const Text('数据库（可选）', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('留空时在目标服务器安装页面输入；密码不会写入客户端日志。', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          TextField(controller: _dbName, decoration: const InputDecoration(labelText: '数据库名', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _dbPassword, obscureText: true, decoration: const InputDecoration(labelText: '数据库密码', border: OutlineInputBorder())),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _generate,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.archive_outlined),
            label: Text(_busy ? (_progress > 0 ? '正在生成 ${(100 * _progress).toStringAsFixed(0)}%' : '正在生成部署包...') : '一键生成并下载'),
          ),
        ],
      ),
    );
  }

  Widget _rowCard(int index, _ServerRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [Text('服务器 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)), const Spacer(), if (_rows.length > 1) IconButton(onPressed: _busy ? null : () => setState(() { final removed = _rows.removeAt(index); removed.dispose(); }), icon: const Icon(Icons.delete_outline), tooltip: '移除')]),
          TextField(controller: row.name, decoration: const InputDecoration(labelText: '名称（可选）')),
          TextField(controller: row.url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: '服务器地址', hintText: 'https://bbs.example.com')),
          TextField(controller: row.weight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '权重')),
        ]),
      ),
    );
  }
}
