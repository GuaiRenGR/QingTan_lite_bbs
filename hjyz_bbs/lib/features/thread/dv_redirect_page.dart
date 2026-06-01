import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/loading_view.dart';

/// 通过 DV 码跳转到帖子详情
class DvRedirectPage extends StatefulWidget {
  final String dvCode;

  const DvRedirectPage({super.key, required this.dvCode});

  @override
  State<DvRedirectPage> createState() => _DvRedirectPageState();
}

class _DvRedirectPageState extends State<DvRedirectPage> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final result = await ApiClient.instance.get(
      'threads/detail-by-dv',
      query: {'dv_code': widget.dvCode},
    );

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      // detail-by-dv 返回的就是帖子详情，直接用 thread ID 跳转
      final data = result.data as Map<String, dynamic>;
      final thread = data['thread'];
      final threadId = thread is Map ? (thread['id'] ?? 0) : 0;

      if (threadId > 0) {
        context.replace('/thread/$threadId');
        return;
      }
    }

    // 如果失败，显示错误
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const LoadingView(),
    );
  }
}
