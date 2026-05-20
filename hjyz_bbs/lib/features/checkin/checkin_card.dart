import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';

class CheckinCard extends StatefulWidget {
  const CheckinCard({super.key});

  @override
  State<CheckinCard> createState() => _CheckinCardState();
}

class _CheckinCardState extends State<CheckinCard> {
  bool checkedIn = false;
  int checkinDays = 0;
  int points = 0;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final result = await ApiClient.instance.get('checkin/status');
    if (!mounted) return;
    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      setState(() {
        checkedIn = data['checked_in'] == true;
        checkinDays = _toInt(data['checkin_days']);
        points = _toInt(data['points']);
      });
    }
  }

  Future<void> _doCheckin() async {
    if (checkedIn || loading) return;
    setState(() => loading = true);

    final result = await ApiClient.instance.post('checkin/do');
    if (!mounted) return;
    setState(() => loading = false);

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      setState(() {
        checkedIn = true;
        checkinDays = _toInt(data['checkin_days']);
        points = _toInt(data['points']);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('签到成功！已连续签到 $checkinDays 天')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message.isEmpty ? '签到失败' : result.message)),
        );
      }
    }
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFB7299), Color(0xFFFF9A9E)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkedIn ? '今日已签到' : '每日签到',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '连续 $checkinDays 天 · 积分 $points',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: checkedIn ? null : _doCheckin,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFFB7299),
              disabledBackgroundColor: Colors.white54,
              disabledForegroundColor: Colors.white70,
            ),
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(checkedIn ? '已签到' : '签到'),
          ),
        ],
      ),
    );
  }
}
