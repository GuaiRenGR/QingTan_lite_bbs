import 'package:flutter/material.dart';

import '../../core/services/upload_manager.dart';
import '../../core/theme/app_colors.dart';

class UploadManagementPage extends StatefulWidget {
  const UploadManagementPage({super.key});

  @override
  State<UploadManagementPage> createState() => _UploadManagementPageState();
}

class _UploadManagementPageState extends State<UploadManagementPage> {
  @override
  void initState() {
    super.initState();
    UploadManager.instance.addListener(_changed);
  }

  @override
  void dispose() {
    UploadManager.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tasks = UploadManager.instance.activeTasks;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(title: const Text('上传管理')),
      body: tasks.isEmpty
          ? const Center(child: Text('暂无进行中的上传任务'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return ListTile(
                  tileColor: Theme.of(context).colorScheme.surface,
                  title: Text(task.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: LinearProgressIndicator(value: task.progress),
                  trailing: IconButton(
                    tooltip: task.paused ? '继续' : '暂停',
                    icon: Icon(task.paused ? Icons.play_arrow : Icons.pause),
                    onPressed: () => task.paused
                        ? UploadManager.instance.resume(task.id)
                        : UploadManager.instance.pause(task.id),
                  ),
                );
              },
            ),
    );
  }
}
