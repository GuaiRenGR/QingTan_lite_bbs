import 'package:flutter/material.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('私信'),
      ),
      body: const Center(
        child: Text('私信功能开发中'),
      ),
    );
  }
}
