import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/utils/url_helper.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // 后台通知检查任务
    if (task == 'checkNotificationsTask') {
      await NotificationService.checkNotificationsBackground();
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 MediaKit 以支持视频播放
  MediaKit.ensureInitialized();

  // 初始化 HTTPS 设置
  await UrlHelper.init();

  // 初始化 Workmanager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runApp(
    const ProviderScope(
      child: ForumXApp(),
    ),
  );
}
