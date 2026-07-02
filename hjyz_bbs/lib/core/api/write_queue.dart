import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'api_result.dart';

class QueuedRequest {
  final String route;
  final String method;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  int retryCount;

  QueuedRequest({
    required this.route,
    this.method = 'POST',
    this.data,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'route': route,
    'method': method,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory QueuedRequest.fromJson(Map<String, dynamic> json) {
    return QueuedRequest(
      route: json['route'] as String? ?? '',
      method: json['method'] as String? ?? 'POST',
      data: json['data'] as Map<String, dynamic>?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }
}

class WriteQueue {
  WriteQueue._();
  static final WriteQueue instance = WriteQueue._();

  final List<QueuedRequest> _queue = [];
  Timer? _retryTimer;
  bool _isLoading = false;
  bool _isRetrying = false;

  static const int _maxRetryAgeHours = 48;
  static const int _maxRetryCount = 100;
  static const Duration _retryInterval = Duration(seconds: 30);

  List<QueuedRequest> get pendingRequests => List.unmodifiable(_queue);
  int get pendingCount => _queue.length;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('write_queue');
      if (stored != null && stored.isNotEmpty) {
        final list = jsonDecode(stored) as List<dynamic>;
        _queue.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _queue.add(QueuedRequest.fromJson(item));
          }
        }
      }
    } catch (_) {}

    _pruneExpired();
    _isLoading = false;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_queue.map((e) => e.toJson()).toList());
      await prefs.setString('write_queue', jsonStr);
    } catch (_) {}
  }

  Future<void> enqueue(String route, {Map<String, dynamic>? data}) async {
    _queue.add(QueuedRequest(
      route: route,
      data: data,
    ));
    await _save();
    _startRetryTimer();
  }

  Future<void> retryAll() async {
    if (_isRetrying || _queue.isEmpty) return;
    _isRetrying = true;

    final remaining = <QueuedRequest>[];
    final now = DateTime.now();

    for (final request in _queue) {
      // 超过最大保留时间或重试次数则丢弃
      if (now.difference(request.createdAt).inHours > _maxRetryAgeHours ||
          request.retryCount >= _maxRetryCount) {
        continue;
      }

      final success = await _sendRequest(request);
      if (success) {
        continue;
      }

      request.retryCount++;
      remaining.add(request);
    }

    _queue.clear();
    _queue.addAll(remaining);
    await _save();

    _isRetrying = false;

    if (_queue.isNotEmpty) {
      _startRetryTimer();
    }
  }

  Future<bool> _sendRequest(QueuedRequest request) async {
    try {
      final client = ApiClient.instance;
      ApiResult result;

      if (request.method == 'POST') {
        result = await client.post(request.route, data: request.data);
      } else {
        result = await client.get(request.route, query: request.data);
      }

      return result.success;
    } catch (_) {
      return false;
    }
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(_retryInterval, (_) {
      retryAll();
    });
  }

  void _pruneExpired() {
    final now = DateTime.now();
    _queue.removeWhere((r) =>
        now.difference(r.createdAt).inHours > _maxRetryAgeHours ||
        r.retryCount >= _maxRetryCount);
  }

  void dispose() {
    _retryTimer?.cancel();
  }
}
