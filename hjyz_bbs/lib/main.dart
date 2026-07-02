import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/api/server_manager.dart';
import 'core/api/write_queue.dart';
import 'core/utils/url_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 MediaKit 以支持视频播放
  MediaKit.ensureInitialized();

  // 初始化 HTTPS 设置
  await UrlHelper.init();

  // 初始化多服务器管理器
  await ServerManager.instance.init();

  // 加载写队列
  await WriteQueue.instance.load();

  // 尝试重试队列中的请求
  WriteQueue.instance.retryAll();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runApp(
    const ProviderScope(
      child: ForumXApp(),
    ),
  );
}
