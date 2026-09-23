import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/database_backup_service.dart';
import '../../core/theme/app_colors.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  bool _busy = false;
  double _progress = 0;
  String? _path;

  Future<void> _download() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });
    final result = await DatabaseBackupService.instance.download(onProgress: (received, total) {
      if (mounted && total > 0) setState(() => _progress = (received / total).clamp(0, 1));
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.success) _path = result.data;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.success ? '数据库备份已保存：${result.data}' : result.message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('数据库备份', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('备份包含账号、帖子和系统配置等敏感数据，请妥善保管。恢复数据库请使用多服务器部署包中的安装脚本或服务器端工具。'),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _busy ? null : _download, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download), label: Text(_busy ? '正在下载 ${(100 * _progress).toStringAsFixed(0)}%' : '下载数据库备份')),
          if (_path != null) ...[const SizedBox(height: 8), Text(_path!, style: TextStyle(color: Colors.grey.shade600))],
          const Divider(height: 32),
          const Text('多服务器部署', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('生成包含服务端、安装脚本和数据库恢复文件的部署包。'),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => context.push('/admin/multi-server'), icon: const Icon(Icons.hub_outlined), label: const Text('生成多服务器配置')),
        ],
      ),
    );
  }
}
