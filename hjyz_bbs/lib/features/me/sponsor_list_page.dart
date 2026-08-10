import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';

class SponsorListPage extends StatefulWidget {
  const SponsorListPage({super.key});

  @override
  State<SponsorListPage> createState() => _SponsorListPageState();
}

class _SponsorListPageState extends State<SponsorListPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sponsors = const [];

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
    final result = await ApiClient.instance.get('sponsors/list');
    if (!mounted) return;

    if (result.success && result.data is Map) {
      final raw = (result.data as Map)['list'];
      setState(() {
        _sponsors = raw is List
            ? raw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : const [];
        _loading = false;
      });
    } else {
      setState(() {
        _error = result.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(title: const Text('赞助名单')),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 160),
          Icon(Icons.cloud_off_outlined, size: 42, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ),
        ],
      );
    }
    if (_sponsors.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 180),
          Icon(Icons.volunteer_activism_outlined, size: 44),
          SizedBox(height: 12),
          Center(child: Text('暂无赞助记录')),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _sponsors.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final sponsor = _sponsors[index];
        final message = sponsor['message']?.toString() ?? '';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.favorite_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sponsor['name']?.toString() ?? '匿名赞助者',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '¥${sponsor['amount'] ?? '0.00'}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(message),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
