import 'dart:convert';

const int chatLogMaxMessages = 100;
const int chatLogMaxDepth = 2;

class ChatLogDocument {
  final String title;
  final String createdAt;
  final List<ChatLogMessage> messages;

  const ChatLogDocument({
    this.title = '',
    required this.createdAt,
    required this.messages,
  });

  factory ChatLogDocument.empty() {
    return ChatLogDocument(
      createdAt: DateTime.now().toIso8601String(),
      messages: const [],
    );
  }

  factory ChatLogDocument.fromJson(dynamic value) {
    return _fromJson(value, 0);
  }

  static ChatLogDocument _fromJson(dynamic value, int depth) {
    if (value is! Map) {
      throw const FormatException('聊天记录格式错误');
    }
    final messages = value['messages'];
    if (messages is! List) {
      throw const FormatException('聊天记录缺少消息列表');
    }
    final document = ChatLogDocument(
      title: value['title']?.toString() ?? '',
      createdAt: value['created_at']?.toString() ?? '',
      messages: messages
          .map((message) => ChatLogMessage.fromJson(message, depth: depth))
          .toList(),
    );
    document.validate(depth);
    return document;
  }

  factory ChatLogDocument.fromJsonString(String value) {
    return ChatLogDocument.fromJson(jsonDecode(value));
  }

  Map<String, dynamic> toJson() => {
        'schema': 'qingtan.chatlog',
        'version': 1,
        'title': title,
        'created_at': createdAt,
        'messages': messages.map((message) => message.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  Set<int> get attachmentIds {
    final ids = <int>{};
    for (final message in messages) {
      if (message.attachmentId > 0) ids.add(message.attachmentId);
      final nested = message.chatlog;
      if (nested != null) ids.addAll(nested.attachmentIds);
    }
    return ids;
  }

  void validate([int depth = 0]) {
    if (depth > chatLogMaxDepth) {
      throw const FormatException('聊天记录嵌套层级过深');
    }
    if (messages.length > chatLogMaxMessages) {
      throw const FormatException('一条聊天记录最多包含100条消息');
    }
    for (final message in messages) {
      message.validate(depth);
    }
  }
}

enum ChatLogMessageType { text, image, quote, chatlog }

class ChatLogMessage {
  final ChatLogMessageType type;
  final String nickname;
  final String sender;
  final String content;
  final String time;
  final String imageUrl;
  final int attachmentId;
  final ChatLogQuote? quote;
  final ChatLogDocument? chatlog;

  const ChatLogMessage({
    required this.type,
    required this.nickname,
    required this.sender,
    required this.content,
    required this.time,
    this.imageUrl = '',
    this.attachmentId = 0,
    this.quote,
    this.chatlog,
  });

  factory ChatLogMessage.fromJson(dynamic value, {int depth = 0}) {
    if (value is! Map) {
      throw const FormatException('聊天记录消息格式错误');
    }
    final type = ChatLogMessageType.values.firstWhere(
      (item) => item.name == value['type']?.toString(),
      orElse: () => throw const FormatException('未知的聊天记录消息类型'),
    );
    final quoteValue = value['quote'];
    final chatlogValue = value['chatlog'];
    return ChatLogMessage(
      type: type,
      nickname: value['nickname']?.toString() ?? '',
      sender: value['sender']?.toString() ?? '',
      content: value['content']?.toString() ?? '',
      time: value['time']?.toString() ?? '',
      imageUrl: value['image_url']?.toString() ?? '',
      attachmentId:
          int.tryParse(value['attachment_id']?.toString() ?? '') ?? 0,
      quote: quoteValue is Map ? ChatLogQuote.fromJson(quoteValue) : null,
      chatlog: chatlogValue is Map
          ? ChatLogDocument._fromJson(chatlogValue, depth + 1)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'nickname': nickname,
        'sender': sender,
        'content': content,
        'time': time,
        if (imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (attachmentId > 0) 'attachment_id': attachmentId,
        if (quote != null) 'quote': quote!.toJson(),
        if (chatlog != null) 'chatlog': chatlog!.toJson(),
      };

  void validate(int parentDepth) {
    if (nickname.trim().isEmpty || sender.trim().isEmpty) {
      throw const FormatException('聊天记录消息缺少昵称或发送人');
    }
    if (type == ChatLogMessageType.image && imageUrl.trim().isEmpty) {
      throw const FormatException('图片消息缺少图片地址');
    }
    if (type == ChatLogMessageType.quote && quote == null) {
      throw const FormatException('引用消息缺少引用内容');
    }
    if (type == ChatLogMessageType.chatlog) {
      if (chatlog == null || parentDepth >= chatLogMaxDepth) {
        throw const FormatException('聊天记录嵌套层级过深');
      }
      chatlog!.validate(parentDepth + 1);
    }
  }
}

class ChatLogQuote {
  final String nickname;
  final String sender;
  final String content;
  final String time;

  const ChatLogQuote({
    required this.nickname,
    required this.sender,
    required this.content,
    required this.time,
  });

  factory ChatLogQuote.fromJson(Map value) {
    return ChatLogQuote(
      nickname: value['nickname']?.toString() ?? '',
      sender: value['sender']?.toString() ?? '',
      content: value['content']?.toString() ?? '',
      time: value['time']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'sender': sender,
        'content': content,
        'time': time,
      };
}
