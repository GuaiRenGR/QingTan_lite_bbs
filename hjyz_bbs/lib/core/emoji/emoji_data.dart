class EmojiItem {
  final String name;
  final int codepoint;
  final String assetPath;

  const EmojiItem({
    required this.name,
    required this.codepoint,
    required this.assetPath,
  });

  String get char => String.fromCharCode(codepoint);
}

class EmojiData {
  EmojiData._();

  // PUA range: U+E000 ~ U+F8FF
  // B站: U+E001 ~ U+E0C2 (194个)
  // QQ:  U+E0C3 ~ U+E11E (92个)
  static const int _biliStart = 0xE001;
  static const int _qqStart = 0xE0C3;

  static bool isEmojiCodepoint(int codepoint) {
    return codepoint >= _biliStart && codepoint <= _qqStart + 91;
  }

  static EmojiItem? findByCodepoint(int codepoint) {
    for (final emoji in allEmojis) {
      if (emoji.codepoint == codepoint) return emoji;
    }
    return null;
  }

  static final List<EmojiItem> bilibiliEmojis = List.generate(
    194,
    (i) => EmojiItem(
      name: 'b_${i + 1}',
      codepoint: _biliStart + i,
      assetPath: 'assets/emojis/bilibili/b_${i + 1}.png',
    ),
  );

  static final List<EmojiItem> qqEmojis = _qqEmojiNames.asMap().entries.map(
    (entry) {
      return EmojiItem(
        name: entry.value,
        codepoint: _qqStart + entry.key,
        assetPath: 'assets/emojis/qq/${entry.value}.gif',
      );
    },
  ).toList();

  static final List<EmojiItem> allEmojis = [...bilibiliEmojis, ...qqEmojis];

  static const List<String> _qqEmojiNames = [
    'OK',
    'aini',
    'aixin',
    'aoman',
    'baiyan',
    'bangbangtang',
    'baojin',
    'baoquan',
    'bishi',
    'bizui',
    'cahan',
    'caidao',
    'chi',
    'ciya',
    'dabing',
    'daku',
    'dan',
    'deyi',
    'doge',
    'fadai',
    'fanu',
    'fendou',
    'ganga',
    'gouyin',
    'guzhang',
    'haixiu',
    'hanxiao',
    'haobang',
    'haqian',
    'hecai',
    'hexie',
    'huaixiao',
    'jie',
    'jingkong',
    'jingxi',
    'jingya',
    'juhua',
    'keai',
    'kelian',
    'koubi',
    'ku',
    'kuaikule',
    'kulou',
    'kun',
    'lanqiu',
    'leiben',
    'lenghan',
    'liuhan',
    'liulei',
    'nanguo',
    'penxue',
    'piezui',
    'pijiu',
    'qiang',
    'qiaoda',
    'qinqin',
    'qiudale',
    'quantou',
    'saorao',
    'se',
    'shengli',
    'shouqiang',
    'shuai',
    'shui',
    'tiaopi',
    'touxiao',
    'tu',
    'tuosai',
    'weiqu',
    'weixiao',
    'woshou',
    'wozuimei',
    'wunai',
    'xia',
    'xiaojiujie',
    'xiaoku',
    'xiaoyanger',
    'xieyanxiao',
    'xigua',
    'xu',
    'yangtuo',
    'yinxian',
    'yiwen',
    'youhengheng',
    'youling',
    'yun',
    'zaijian',
    'zhayanjian',
    'zhemo',
    'zhouma',
    'zhuakuang',
    'zuohengheng',
  ];
}
