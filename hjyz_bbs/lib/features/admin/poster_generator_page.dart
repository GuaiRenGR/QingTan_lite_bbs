import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/auth_controller.dart';

class PosterGeneratorPage extends ConsumerStatefulWidget {
  const PosterGeneratorPage({super.key});

  @override
  ConsumerState<PosterGeneratorPage> createState() => _PosterGeneratorPageState();
}

class _PosterGeneratorPageState extends ConsumerState<PosterGeneratorPage> {
  final _captureKey = GlobalKey();
  final _title = TextEditingController(text: '今天也要好好生活');
  final _body = TextEditingController(text: '把普通的日子过得热气腾腾，\n慢一点，也没有关系。');
  final _author = TextEditingController(text: '清谈小红书');
  final _highlight = TextEditingController(text: '好好生活,热气腾腾');
  int _template = 0;
  bool _autoScroll = true;
  bool _showTags = true;
  String _tags = '生活碎片  日常记录';
  bool _saving = false;

  static const _templates = [
    _PosterStyle('奶油纸张', Color(0xFFFFF8EF), Color(0xFF2B2520), Color(0xFFE86F51)),
    _PosterStyle('樱桃红', Color(0xFFB92745), Colors.white, Color(0xFFFFD166)),
    _PosterStyle('薄荷清透', Color(0xFFE8F4EF), Color(0xFF1D3B34), Color(0xFF4E9F8A)),
    _PosterStyle('夜色杂志', Color(0xFF15161B), Color(0xFFF6F2EA), Color(0xFFFF9F68)),
  ];

  @override
  void dispose() {
    for (final c in [_title, _body, _author, _highlight]) c.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() => _saving = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('预览尚未准备好');
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('图片生成失败');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qingtan_poster_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: '清谈海报');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final groupId = int.tryParse(auth.user?['group_id']?.toString() ?? '') ?? 0;
    if (!auth.loggedIn || groupId < 50) {
      return const Scaffold(body: Center(child: Text('仅管理组可使用此功能')));
    }
    final style = _templates[_template];
    return Scaffold(
      appBar: AppBar(title: const Text('小红书大字报生成器'), actions: [
        IconButton(onPressed: _saving ? null : _export, icon: const Icon(Icons.ios_share_outlined), tooltip: '生成并分享'),
      ]),
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 780;
        final editor = _editor(style);
        final preview = Center(child: SingleChildScrollView(padding: const EdgeInsets.all(18), child: RepaintBoundary(key: _captureKey, child: _poster(style))));
        return wide ? Row(children: [SizedBox(width: 360, child: editor), const VerticalDivider(width: 1), Expanded(child: preview)]) : ListView(children: [editor, const Divider(height: 1), preview]);
      })),
    );
  }

  Widget _editor(_PosterStyle style) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('内容', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      TextField(controller: _title, decoration: const InputDecoration(labelText: '大标题', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
      const SizedBox(height: 10),
      TextField(controller: _body, minLines: 5, maxLines: 9, decoration: const InputDecoration(labelText: '正文（支持换行）', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
      const SizedBox(height: 10),
      TextField(controller: _highlight, decoration: const InputDecoration(labelText: '标注词（逗号分隔）', helperText: '命中的词会自动使用强调色', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
      const SizedBox(height: 10),
      TextField(controller: _tags, decoration: const InputDecoration(labelText: '标签', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
      const SizedBox(height: 10),
      TextField(controller: _author, decoration: const InputDecoration(labelText: '署名', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
      const SizedBox(height: 18),
      Text('风格模板', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: List.generate(_templates.length, (i) => ChoiceChip(label: Text(_templates[i].name), selected: _template == i, onSelected: (_) => setState(() => _template = i)))),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('自动下滑排版'), subtitle: const Text('正文较长时缩小字号并增加留白，适合连续浏览'), value: _autoScroll, onChanged: (v) => setState(() => _autoScroll = v)),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('显示标签'), value: _showTags, onChanged: (v) => setState(() => _showTags = v)),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _export, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_outlined), label: Text(_saving ? '正在生成…' : '生成 PNG 并分享'))),
    ]),
  );

  Widget _poster(_PosterStyle style) {
    final words = _highlight.text.split(RegExp(r'[,，\s]+')).where((e) => e.isNotEmpty).toList();
    final body = _body.text;
    final baseSize = _autoScroll && body.length > 90 ? 22.0 : 28.0;
    return Container(width: 390, constraints: const BoxConstraints(minHeight: 520), padding: const EdgeInsets.fromLTRB(30, 34, 30, 26), decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 30, height: 30, decoration: BoxDecoration(color: style.accent, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17)), const SizedBox(width: 9), Text('小红书灵感笔记', style: TextStyle(color: style.foreground.withValues(alpha: .65), fontSize: 12, letterSpacing: 1))]),
      const SizedBox(height: 42),
      Text(_title.text, style: TextStyle(color: style.foreground, fontSize: 39, height: 1.12, fontWeight: FontWeight.w900)),
      const SizedBox(height: 24),
      Container(width: 48, height: 5, decoration: BoxDecoration(color: style.accent, borderRadius: BorderRadius.circular(4))),
      const SizedBox(height: 26),
      _highlighted(body, words, style, baseSize),
      const SizedBox(height: 54),
      if (_showTags && _tags.text.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 18), child: Text(_tags.text.trim().split(RegExp(r'\s+')).map((e) => '#$e').join('  '), style: TextStyle(color: style.accent, fontWeight: FontWeight.w700, fontSize: 14))),
      Row(children: [Expanded(child: Text('@${_author.text.trim()}', style: TextStyle(color: style.foreground.withValues(alpha: .65), fontSize: 13))), Icon(Icons.favorite_border, color: style.foreground.withValues(alpha: .7), size: 19), const SizedBox(width: 12), Icon(Icons.bookmark_border, color: style.foreground.withValues(alpha: .7), size: 19)]),
    ]));
  }

  Widget _highlighted(String text, List<String> words, _PosterStyle style, double size) {
    final spans = <TextSpan>[];
    var rest = text;
    while (rest.isNotEmpty) {
      final matches = words.map((w) => MapEntry(rest.indexOf(w), w)).where((e) => e.key >= 0).toList()..sort((a, b) => a.key.compareTo(b.key));
      if (matches.isEmpty) { spans.add(TextSpan(text: rest)); break; }
      final hit = matches.first;
      if (hit.key > 0) spans.add(TextSpan(text: rest.substring(0, hit.key)));
      spans.add(TextSpan(text: hit.value, style: TextStyle(color: style.accent, fontWeight: FontWeight.w900)));
      rest = rest.substring(hit.key + hit.value.length);
    }
    return RichText(text: TextSpan(style: TextStyle(color: style.foreground, fontSize: size, height: 1.55, fontWeight: FontWeight.w600), children: spans));
  }
}

class _PosterStyle {
  final String name;
  final Color background;
  final Color foreground;
  final Color accent;
  const _PosterStyle(this.name, this.background, this.foreground, this.accent);
}
