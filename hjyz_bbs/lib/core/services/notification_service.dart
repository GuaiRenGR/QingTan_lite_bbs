import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../storage/token_storage.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Timer? _pollTimer;
  bool _initialized = false;
  Map<String, int> _lastCounts = {};
  int _lastMessageUnread = 0;

  // 通知频道
  static const _channelId = 'qingtan_notifications';
  static const _channelName = '消息通知';
  static const _channelDesc = '轻坛消息通知';

  Future<void> initialize() async {
    if (_initialized) return;

    // Android 初始化
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Windows 初始化
    const windowsSettings = WindowsInitializationSettings(
      appName: '轻坛',
      appUserModelId: 'com.qingtan.hjyzbbs',
      guid: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    );

    final settings = InitializationSettings(
      android: androidSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android 13+ 请求通知权限
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
        // 创建通知渠道
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );
      }
    }

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // 通知被点击时的处理
    // 可以通过 response.payload 导航到对应页面
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      // payload 格式: "type:xxx" 或 "message"
      // 可以在这里处理导航逻辑
    }
  }

  /// 启动轮询（应用前台时调用）
  void startPolling() {
    stopPolling();

    // 立即检查一次
    _checkNewNotifications();

    // 每 60 秒检查一次
    _pollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _checkNewNotifications(),
    );
  }

  /// 停止轮询
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// 手动触发一次检查（例如应用恢复前台时）
  Future<void> checkNow() async {
    await _checkNewNotifications();
  }

  Future<void> _checkNewNotifications() async {
    // 检查是否已登录
    final token = await TokenStorage.instance.getToken();
    if (token == null || token.isEmpty) return;

    // 检查用户是否启用了原生通知
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('native_notifications') ?? true;
    if (!enabled) return;

    try {
      // 并行检查通知和私信
      final results = await Future.wait([
        ApiClient.instance.get('notifications/unread'),
        ApiClient.instance.get('messages/unread'),
      ]);

      // 处理通知未读数
      final notifResult = results[0];
      if (notifResult.success && notifResult.data is Map) {
        final data = notifResult.data as Map;
        final currentCounts = <String, int>{
          'reply': _toInt(data['reply']),
          'mention': _toInt(data['mention']),
          'like': _toInt(data['like']),
          'system': _toInt(data['system']),
        };

        // 检测新增通知
        _checkAndNotify('reply', currentCounts, '回复我的', '有人回复了你的帖子');
        _checkAndNotify('mention', currentCounts, '@我', '有人在帖子中@了你');
        _checkAndNotify('like', currentCounts, '收到的赞', '有人赞了你的帖子');
        _checkAndNotify('system', currentCounts, '系统通知', '你有新的系统通知');

        _lastCounts = currentCounts;
      }

      // 处理私信未读数
      final msgResult = results[1];
      if (msgResult.success && msgResult.data is Map) {
        final msgUnread = _toInt((msgResult.data as Map)['unread_count']);

        if (msgUnread > _lastMessageUnread && _lastMessageUnread >= 0 && msgUnread > 0) {
          _showNativeNotification(
            id: 100,
            title: '新私信',
            body: '你有 $msgUnread 条未读私信',
            payload: 'message',
          );
        }

        _lastMessageUnread = msgUnread;
      }
    } catch (_) {
      // 网络错误静默忽略
    }
  }

  void _checkAndNotify(
    String type,
    Map<String, int> current,
    String title,
    String body,
  ) {
    final currentCount = current[type] ?? 0;
    final lastCount = _lastCounts[type] ?? 0;

    // 只在数量增加时通知（且上次已初始化过）
    if (_lastCounts.isNotEmpty &&
        currentCount > lastCount &&
        currentCount > 0) {
      final id = _notificationId(type);
      _showNativeNotification(
        id: id,
        title: title,
        body: '$body（$currentCount 条未读）',
        payload: 'notification:$type',
      );
    }
  }

  int _notificationId(String type) {
    switch (type) {
      case 'reply':
        return 1;
      case 'mention':
        return 2;
      case 'like':
        return 3;
      case 'system':
        return 4;
      default:
        return 0;
    }
  }

  Future<void> _showNativeNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
    );

    const windowsDetails = WindowsNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      windows: windowsDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// 重置状态（退出登录时调用）
  void reset() {
    _lastCounts = {};
    _lastMessageUnread = 0;
    stopPolling();
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
