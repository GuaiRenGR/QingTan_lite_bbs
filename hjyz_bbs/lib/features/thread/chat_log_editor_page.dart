import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import 'chat_log_model.dart';

class ChatLogEditorPage extends StatefulWidget {
  final ChatLogDocument? initialDocument;
  final int depth;

  const ChatLogEditorPage({
    super.key,
    this.initialDocument,
    this.depth = 0,
  });

  @override
  State<ChatLogEditorPage> createState() => _ChatLogEditorPageState();
}

class _ChatLogEditorPageState extends State<ChatLogEditorPage> {
  late final TextEditingController _titleController;
  late List<ChatLogMessage> _messages;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialDocument?.title ?? '',
    );
    _messages = List.of(widget.initialDocument?.messages ?? const []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _addMessage() async {
    if (_messages.length >= chatLogMaxMessages) {
      _showMessage('一条聊天记录最多包含100条消息');
      return;
    }
    final message = await showDialog<ChatLogMessage>(
      context: context,
      builder: (_) => _ChatLogMessageDialog(depth: widget.depth),
    );
    if (message != null && mounted) {
      setState(() => _messages.add(message));
    }
  }

  Future<void> _editMessage(int index) async {
    final message = await showDialog<ChatLogMessage>(
      context: context,
      builder: (_) => _ChatLogMessageDialog(
        depth: widget.depth,
        initialMessage: _messages[index],
      ),
    );
    if (message != null && mounted) {
      setState(() => _messages[index] = message);
    }
  }

  void _save() {
    final document = ChatLogDocument(
      title: _titleController.text.trim(),
      createdAt: widget.initialDocument?.createdAt ??
          DateTime.now().toIso8601String(),
      messages: List.unmodifiable(_messages),
    );
    try {
      document.validate();
      Navigator.of(context).pop(document);
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.depth + 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.depth == 0 ? '编辑聊天记录' : '编辑嵌套聊天记录'),
        actions: [
          TextButton(onPressed: _save, child: const Text('完成')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '记录标题（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text('第 $level 层 · ${_messages.length}/$chatLogMaxMessages 条消息'),
          const SizedBox(height: 8),
          if (_messages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('还没有消息，点击下方添加')),
            ),
          for (var index = 0; index < _messages.length; index++)
            _MessageTile(
              message: _messages[index],
              onTap: () => _editMessage(index),
              onDelete: () => setState(() => _messages.removeAt(index)),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _addMessage,
            icon: const Icon(Icons.add),
            label: const Text('添加消息'),
          ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final ChatLogMessage message;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MessageTile({
    required this.message,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final detail = switch (message.type) {
      ChatLogMessageType.image => '图片消息',
      ChatLogMessageType.quote => '引用：${message.quote?.content ?? ''}',
      ChatLogMessageType.chatlog =>
        '聊天记录（${message.chatlog?.messages.length ?? 0} 条）',
      ChatLogMessageType.text => message.content,
    };
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text('${message.nickname} · ${message.time}'),
        subtitle: Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

class _ChatLogMessageDialog extends StatefulWidget {
  final int depth;
  final ChatLogMessage? initialMessage;

  const _ChatLogMessageDialog({required this.depth, this.initialMessage});

  @override
  State<_ChatLogMessageDialog> createState() => _ChatLogMessageDialogState();
}

class _ChatLogMessageDialogState extends State<_ChatLogMessageDialog> {
  late ChatLogMessageType _type;
  late final TextEditingController _nickname;
  late final TextEditingController _sender;
  late final TextEditingController _content;
  late final TextEditingController _time;
  late final TextEditingController _quoteNickname;
  late final TextEditingController _quoteSender;
  late final TextEditingController _quoteContent;
  late final TextEditingController _quoteTime;
  String _imageUrl = '';
  int _imageAttachmentId = 0;
  ChatLogDocument? _nested;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final message = widget.initialMessage;
    _type = message?.type ?? ChatLogMessageType.text;
    _nickname = TextEditingController(text: message?.nickname ?? '');
    _sender = TextEditingController(text: message?.sender ?? '');
    _content = TextEditingController(text: message?.content ?? '');
    _time = TextEditingController(
      text: message?.time.isNotEmpty == true
          ? message!.time
          : DateTime.now().toString().substring(0, 16),
    );
    _imageUrl = message?.imageUrl ?? '';
    _imageAttachmentId = message?.attachmentId ?? 0;
    _nested = message?.chatlog;
    final quote = message?.quote;
    _quoteNickname = TextEditingController(text: quote?.nickname ?? '');
    _quoteSender = TextEditingController(text: quote?.sender ?? '');
    _quoteContent = TextEditingController(text: quote?.content ?? '');
    _quoteTime = TextEditingController(text: quote?.time ?? '');
  }

  @override
  void dispose() {
    for (final controller in [
      _nickname,
      _sender,
      _content,
      _time,
      _quoteNickname,
      _quoteSender,
      _quoteContent,
      _quoteTime,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final result = await ApiClient.instance.uploadFile(
        'upload/media',
        file: File(picked.path),
        fields: const {'type': 'image'},
      );
      if (!mounted) return;
      if (!result.success || result.data is! Map) {
        _showMessage(result.message);
        return;
      }
      final url = ApiClient.instance.resolveUrl(
        (result.data as Map)['url']?.toString() ?? '',
      );
      if (url.isEmpty) {
        _showMessage('图片上传后没有返回地址');
      } else {
        setState(() {
          _imageUrl = url;
          _imageAttachmentId =
              int.tryParse((result.data as Map)['id']?.toString() ?? '') ?? 0;
        });
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _editNested() async {
    if (widget.depth >= chatLogMaxDepth) {
      _showMessage('聊天记录最多嵌套两层');
      return;
    }
    final nested = await Navigator.of(context).push<ChatLogDocument>(
      MaterialPageRoute(
        builder: (_) => ChatLogEditorPage(
          initialDocument: _nested,
          depth: widget.depth + 1,
        ),
      ),
    );
    if (nested != null && mounted) setState(() => _nested = nested);
  }

  void _submit() {
    if (_nickname.text.trim().isEmpty || _sender.text.trim().isEmpty) {
      _showMessage('请填写昵称和发送人');
      return;
    }
    final message = ChatLogMessage(
      type: _type,
      nickname: _nickname.text.trim(),
      sender: _sender.text.trim(),
      content: _content.text,
      time: _time.text.trim(),
      imageUrl: _imageUrl,
      attachmentId: _imageAttachmentId,
      quote: _type == ChatLogMessageType.quote
          ? ChatLogQuote(
              nickname: _quoteNickname.text.trim(),
              sender: _quoteSender.text.trim(),
              content: _quoteContent.text,
              time: _quoteTime.text.trim(),
            )
          : null,
      chatlog: _type == ChatLogMessageType.chatlog ? _nested : null,
    );
    try {
      message.validate(widget.depth);
      Navigator.of(context).pop(message);
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final canNest = widget.depth < chatLogMaxDepth;
    return AlertDialog(
      title: Text(widget.initialMessage == null ? '添加消息' : '编辑消息'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ChatLogMessageType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '消息类型'),
              items: [
                for (final type in ChatLogMessageType.values)
                  if (type != ChatLogMessageType.chatlog || canNest)
                    DropdownMenuItem(value: type, child: Text(_typeLabel(type))),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            TextField(controller: _nickname, decoration: const InputDecoration(labelText: '用户昵称')),
            TextField(controller: _sender, decoration: const InputDecoration(labelText: '发送人')),
            TextField(controller: _time, decoration: const InputDecoration(labelText: '发送时间')),
            if (_type == ChatLogMessageType.text || _type == ChatLogMessageType.quote)
              TextField(
                controller: _content,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '发送内容'),
              ),
            if (_type == ChatLogMessageType.image) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(_uploading ? '上传中…' : '选择并上传图片'),
                ),
              ),
              if (_imageUrl.isNotEmpty) Text(_imageUrl, maxLines: 2),
            ],
            if (_type == ChatLogMessageType.quote) ...[
              const Divider(),
              const Align(alignment: Alignment.centerLeft, child: Text('引用内容')),
              TextField(controller: _quoteNickname, decoration: const InputDecoration(labelText: '引用昵称')),
              TextField(controller: _quoteSender, decoration: const InputDecoration(labelText: '引用发送人')),
              TextField(controller: _quoteContent, decoration: const InputDecoration(labelText: '引用文字')),
              TextField(controller: _quoteTime, decoration: const InputDecoration(labelText: '引用时间')),
            ],
            if (_type == ChatLogMessageType.chatlog) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _editNested,
                icon: const Icon(Icons.forum_outlined),
                label: Text(_nested == null
                    ? '编辑嵌套聊天记录'
                    : '已添加 ${_nested!.messages.length} 条消息'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }

  String _typeLabel(ChatLogMessageType type) {
    switch (type) {
      case ChatLogMessageType.text:
        return '文字消息';
      case ChatLogMessageType.image:
        return '图片消息';
      case ChatLogMessageType.quote:
        return '引用消息';
      case ChatLogMessageType.chatlog:
        return '聊天记录';
    }
  }
}
