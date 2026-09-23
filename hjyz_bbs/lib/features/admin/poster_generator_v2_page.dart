import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/auth_controller.dart';

class PosterGeneratorV2Page extends ConsumerStatefulWidget {
  const PosterGeneratorV2Page({super.key});

  @override
  ConsumerState<PosterGeneratorV2Page> createState() => _PosterGeneratorV2PageState();
}

class _PosterGeneratorV2PageState extends ConsumerState<PosterGeneratorV2Page> {
  final _captureKey = GlobalKey();
  final _title = TextEditingController(text: '今天也要好好生活');
  final _body = TextEditingController(text: '把普通的日子过得热气腾腾，\n慢一点，也没有关系。');
  final _author = TextEditingController(text: '清谈小红书');
  final _tags = TextEditingController(text: '生活碎片  日常记录');
  int _template = 0;
  bool _showTags = true;
  bool _saving = false;

  static const _templates = [
    _PosterStyle('小红书红', Color(0xFFFFF9F7), Color(0xFF241C1C), Color(0xFFFF2442), Color(0xFF8D7777)),
    _PosterStyle('奶油纸张', Color(0xFFFFF2D8), Color(0xFF342719), Color(0xFFDF6A3B), Color(0xFF806955)),
    _PosterStyle('薄荷清透', Color(0xFFE8F4EF), Color(0xFF173D35), Color(0xFF2D9C83), Color(0xFF658B82)),
    _PosterStyle('黑白杂志', Color(0xFF171717), Color(0xFFF7F1E8), Color(0xFFFF6A4D), Color(0xFFBFB8AF)),
  ];

  @override
  void dispose() {
    for (final c in [_title, _body, _author, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _export() async {
    setState(() => _saving = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('预览尚未准备好');
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('图片生成失败');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qingtan_xhs_poster_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (mounted) await Share.shareXFiles([XFile(file.path)], text: '清谈小红书');
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
    if (!auth.loggedIn || groupId < 50) return const Scaffold(body: Center(child: Text('仅管理组可使用此功能')));
    final style = _templates[_template];
    return Scaffold(
      appBar: AppBar(title: const Text('小红书大字报生成器'), actions: [IconButton(onPressed: _saving ? null : _export, tooltip: '生成并分享', icon: const Icon(Icons.ios_share_outlined))]),
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final preview = Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: RepaintBoundary(key: _captureKey, child: _poster(style))));
        return wide ? Row(children: [SizedBox(width: 370, child: _editor()), const VerticalDivider(width: 1), Expanded(child: preview)]) : ListView(children: [_editor(), const Divider(height: 1), preview]);
      })),
    );
  }

  Widget _editor() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('内容', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(controller: _title, maxLength: 30, decoration: const InputDecoration(labelText: '标题', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          TextField(controller: _body, minLines: 5, maxLines: 10, maxLength: 260, decoration: const InputDecoration(labelText: '正文（支持换行）', alignLabelWithHint: true, border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          TextField(controller: _tags, decoration: const InputDecoration(labelText: '话题标签（空格分隔）', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          TextField(controller: _author, decoration: const InputDecoration(labelText: '发布者', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
          const SizedBox(height: 18),
          Text('视觉风格', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: List.generate(_templates.length, (i) => ChoiceChip(label: Text(_templates[i].name), selected: _template == i, onSelected: (_) => setState(() => _template = i)))),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('显示话题标签'), value: _showTags, onChanged: (v) => setState(() => _showTags = v)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _export, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_outlined), label: Text(_saving ? '正在生成...' : '生成 PNG 并分享'))),
        ]),
      );

  Widget _poster(_PosterStyle style) {
    final tags = _tags.text.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).map((e) => '#$e').join('  ');
    return Container(
      width: 390,
      height: 585,
      padding: const EdgeInsets.fromLTRB(30, 28, 30, 24),
      decoration: BoxDecoration(color: style.background, boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 22, offset: Offset(0, 10))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: style.accent, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.auto_awesome, color: Colors.white, size: 19)), const SizedBox(width: 10), Text('小红书灵感笔记', style: TextStyle(color: style.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)), const Spacer(), Text('01', style: TextStyle(color: style.muted, fontSize: 12, fontWeight: FontWeight.w700))]),
        const SizedBox(height: 38),
        Text(_title.text.trim().isEmpty ? '未命名笔记' : _title.text.trim(), style: TextStyle(color: style.foreground, fontSize: 39, height: 1.08, fontWeight: FontWeight.w900)),
        const SizedBox(height: 17),
        Container(width: 52, height: 5, decoration: BoxDecoration(color: style.accent, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 22),
        Expanded(child: Text(_body.text.trim().isEmpty ? '写下此刻的想法...' : _body.text.trim(), style: TextStyle(color: style.foreground, fontSize: _body.text.length > 130 ? 21 : _body.text.length > 80 ? 24 : 27, height: 1.52, fontWeight: FontWeight.w600))),
        if (_showTags && tags.isNotEmpty) ...[const SizedBox(height: 12), Text(tags, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: style.accent, fontSize: 13, height: 1.5, fontWeight: FontWeight.w800))],
        const SizedBox(height: 20),
        Row(children: [Container(width: 28, height: 28, decoration: BoxDecoration(color: style.accent.withValues(alpha: .16), shape: BoxShape.circle), child: Icon(Icons.person, size: 16, color: style.accent)), const SizedBox(width: 8), Expanded(child: Text('@${_author.text.trim().isEmpty ? '匿名用户' : _author.text.trim()}', overflow: TextOverflow.ellipsis, style: TextStyle(color: style.muted, fontSize: 12, fontWeight: FontWeight.w700))), Icon(Icons.favorite_border, color: style.muted, size: 18), const SizedBox(width: 12), Icon(Icons.bookmark_border, color: style.muted, size: 18)]),
      ]),
    );
  }
}

class _PosterStyle {
  final String name;
  final Color background;
  final Color foreground;
  final Color accent;
  final Color muted;
  const _PosterStyle(this.name, this.background, this.foreground, this.accent, this.muted);
}
