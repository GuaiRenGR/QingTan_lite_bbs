import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.qingtan.music.playback',
    androidNotificationChannelName: '音乐播放',
    androidNotificationOngoing: true,
  );
  runApp(const ProviderScope(child: QingTanMusicApp()));
}
