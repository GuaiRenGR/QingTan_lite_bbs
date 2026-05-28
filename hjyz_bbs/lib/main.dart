import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/utils/url_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 MediaKit 以支持视频播放
  MediaKit.ensureInitialized();

  // 初始化 HTTPS 设置
  await UrlHelper.init();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runApp(
    const ProviderScope(
      child: ForumXApp(),
    ),
  );
}
