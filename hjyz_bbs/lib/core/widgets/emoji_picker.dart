import 'package:flutter/material.dart';

import '../emoji/emoji_data.dart';

class EmojiPicker extends StatelessWidget {
  final ValueChanged<String> onEmojiSelected;

  const EmojiPicker({super.key, required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: 260,
        child: Column(
          children: [
            Container(
              color: Colors.grey.shade100,
              child: TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: const [
                  Tab(text: 'B站'),
                  Tab(text: 'QQ'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _EmojiGrid(
                    emojis: EmojiData.bilibiliEmojis,
                    onSelected: onEmojiSelected,
                  ),
                  _EmojiGrid(
                    emojis: EmojiData.qqEmojis,
                    onSelected: onEmojiSelected,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  final List<EmojiItem> emojis;
  final ValueChanged<String> onSelected;

  const _EmojiGrid({required this.emojis, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        final emoji = emojis[index];
        return GestureDetector(
          onTap: () => onSelected(emoji.char),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              emoji.assetPath,
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.emoji_emotions_outlined,
                color: Colors.grey.shade400,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}
