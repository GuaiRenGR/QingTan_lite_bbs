import 'package:flutter/material.dart';

import 'router.dart';

class ForumXApp extends StatelessWidget {
  const ForumXApp({super.key});

  static const fontFallback = <String>[
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'Segoe UI',
    'Roboto',
    'Arial',
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '获嘉一中论坛',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFB7299),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        // 关键：不要指定 fontFamily，让 Flutter 使用平台系统默认字体。
        fontFamily: null,
        textTheme: ThemeData.light().textTheme.apply(
              fontFamilyFallback: fontFallback,
            ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFB7299),
        brightness: Brightness.dark,
        fontFamily: null,
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamilyFallback: fontFallback,
            ),
      ),
    );
  }
}
