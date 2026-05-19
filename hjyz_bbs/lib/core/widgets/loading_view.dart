import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  final String text;

  const LoadingView({
    super.key,
    this.text = '加载中...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
