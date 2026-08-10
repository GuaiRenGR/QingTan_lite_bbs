import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/api/server_manager.dart';
import 'core/api/write_queue.dart';
import 'core/services/download_service.dart';
import 'core/services/feed_display_service.dart';
import 'core/services/music_player_settings_service.dart';
import 'core/services/sensitive_content_service.dart';
import 'core/theme/theme_color_service.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/url_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.qingtan.hjyzbbs.playback',
    androidNotificationChannelName: '音乐播放',
    androidNotificationOngoing: true,
  );

  // 初始化文件日志
  await AppLogger.init();

  // 初始化 MediaKit 以支持视频播放
  MediaKit.ensureInitialized();

  // 初始化 HTTPS 设置
  await UrlHelper.init();
  await SensitiveContentService.init();
  await DownloadService.instance.init();
  await FeedDisplayService.init();
  await MusicPlayerSettingsService.init();
  await ThemeColorService.init();

  // 初始化多服务器管理器
  await AppLogger.log('main', 'ServerManager.init start');
  await ServerManager.instance.init();
  await AppLogger.log(
    'main',
    'ServerManager.init end, currentServer=${ServerManager.instance.currentServer?.url}',
  );

  // 加载写队列
  await AppLogger.log('main', 'WriteQueue.load start');
  await WriteQueue.instance.load();
  await AppLogger.log(
    'main',
    'WriteQueue.load end, pending=${WriteQueue.instance.pendingCount}',
  );

  // 尝试重试队列中的请求
  WriteQueue.instance.retryAll();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  await AppLogger.log('main', 'runApp');

  runApp(const ProviderScope(child: ForumXApp()));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(ServerManager.instance.refreshInBackground());
  });
}
