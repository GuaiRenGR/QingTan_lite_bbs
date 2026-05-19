import 'package:flutter/material.dart';

import 'router.dart';

class ForumXApp extends StatelessWidget {
  const ForumXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ForumX Lite',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFB7299),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
      ),
    );
  }
}
