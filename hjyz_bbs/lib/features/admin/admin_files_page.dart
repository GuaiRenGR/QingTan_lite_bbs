import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';

class AdminFilesPage extends StatefulWidget {
  const AdminFilesPage({super.key});

  @override
  State<AdminFilesPage> createState() => _AdminFilesPageState();
}

class _AdminFilesPageState extends State<AdminFilesPage> {
  final List<Map<String, dynamic>> _folders = [];
  final List<Map<String, dynamic>> _files = [];

  bool _loading = true;
  bool _mutating = false;
  String? _error;
  int _folderId = 0;
  String _folderName = '文件管理';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiClient.instance.get(
      'admin/files',
      query: {'folder_id': _folderId},
    );
    if (!mounted) return;

    if (!result.success || result.data is! Map<String, dynamic>) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }

    final data = result.data as Map<String, dynamic>;
    setState(() {
      _folders
        ..clear()
        ..addAll(_mapList(data['folders']));
      _files
        ..clear()
        ..addAll(_mapList(data['files']));
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _openFolder(Map<String, dynamic>? folder) async {
    setState(() {
      _folderId = folder == null ? 0 : _toInt(folder['id']);
      _folderName = folder == null
          ? '文件管理'
          : folder['name']?.toString() ?? '文件夹';
    });
    await _load();
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建文件夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: '文件夹名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    await _runMutation(
      () => ApiClient.instance.post(
        'admin/files/folder/create',
        data: {'name': name},
      ),
    );
  }

  Future<void> _moveFile(Map<String, dynamic> file) async {
    final currentFolderId = _toInt(file['folder_id']);
    final targetFolderId = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                '移动到',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('根目录'),
              trailing: currentFolderId == 0
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.of(context).pop(0),
            ),
            for (final folder in _folders)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder['name']?.toString() ?? '文件夹'),
                trailing: currentFolderId == _toInt(folder['id'])
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(context).pop(_toInt(folder['id'])),
              ),
          ],
        );
      },
    );
    if (targetFolderId == null || targetFolderId == currentFolderId) return;

    await _runMutation(
      () => ApiClient.instance.post(
        'admin/files/move',
        data: {
          'id': _toInt(file['id']),
          'folder_id': targetFolderId,
        },
      ),
    );
  }

  Future<void> _deleteFile(Map<String, dynamic> file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除附件'),
        content: Text('确定永久删除“${file['name'] ?? '该附件'}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runMutation(
      () => ApiClient.instance.post(
        'admin/files/delete',
        data: {'id': _toInt(file['id'])},
      ),
    );
  }

  Future<void> _runMutation(Future<dynamic> Function() action) async {
    if (_mutating) return;
    setState(() => _mutating = true);

    try {
      final result = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      if (result.success) await _load();
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _openFile(Map<String, dynamic> file) async {
    final url = ApiClient.instance.resolveUrl(file['url']?.toString() ?? '');
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开附件')),
      );
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatSize(dynamic value) {
    final bytes = _toInt(value);
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  IconData _fileIcon(String type) {
    if (type.startsWith('audio/')) return Icons.audio_file_outlined;
    if (type.startsWith('video/')) return Icons.video_file_outlined;
    if (type.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (type.contains('zip') || type.contains('compressed')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _folderId > 0
            ? IconButton(
                onPressed: () => _openFolder(null),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: Text(_folderName),
        actions: [
          IconButton(
            onPressed: _mutating ? null : _createFolder,
            tooltip: '创建文件夹',
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    children: [
                      if (_folderId == 0 && _folders.isNotEmpty) ...[
                        const _SectionTitle('文件夹'),
                        for (final folder in _folders)
                          _FolderTile(
                            folder: folder,
                            onTap: () => _openFolder(folder),
                          ),
                        const SizedBox(height: 12),
                      ],
                      const _SectionTitle('附件'),
                      if (_files.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: Text('暂无附件')),
                        )
                      else
                        for (final file in _files)
                          _FileTile(
                            file: file,
                            icon: _fileIcon(file['type']?.toString() ?? ''),
                            sizeText: _formatSize(file['size']),
                            onOpen: () => _openFile(file),
                            onMove: () => _moveFile(file),
                            onDelete: () => _deleteFile(file),
                          ),
                    ],
                  ),
                ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final Map<String, dynamic> folder;
  final VoidCallback onTap;

  const _FolderTile({required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Icon(Icons.folder_rounded, color: Color(0xFFFFB74D)),
      title: Text(folder['name']?.toString() ?? '文件夹'),
      subtitle: Text('${folder['file_count'] ?? 0} 个附件'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _FileTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final IconData icon;
  final String sizeText;
  final VoidCallback onOpen;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const _FileTile({
    required this.file,
    required this.icon,
    required this.sizeText,
    required this.onOpen,
    required this.onMove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final uploader = file['uploader_name']?.toString() ?? '用户';
    final createdAt = file['created_at']?.toString() ?? '';

    return ListTile(
      tileColor: AppColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: const Color(0xFFFB7299)),
      title: Text(
        file['name']?.toString() ?? '未命名附件',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('$sizeText · $uploader${createdAt.isEmpty ? '' : ' · $createdAt'}'),
      onTap: onOpen,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'move') onMove();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'move',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.drive_file_move_outline),
              title: Text('移动'),
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }
}
