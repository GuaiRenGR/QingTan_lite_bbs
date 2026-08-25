import 'package:flutter_test/flutter_test.dart';

import 'package:hjyz_bbs/features/thread/chat_log_model.dart';

void main() {
  test('serializes supported message types', () {
    final document = ChatLogDocument(
      createdAt: '2026-08-25T12:00:00Z',
      messages: [
        const ChatLogMessage(
          type: ChatLogMessageType.text,
          nickname: '小明',
          sender: '1001',
          content: '你好',
          time: '12:00',
        ),
        const ChatLogMessage(
          type: ChatLogMessageType.quote,
          nickname: '小红',
          sender: '1002',
          content: '收到',
          time: '12:01',
          quote: ChatLogQuote(
            nickname: '小明',
            sender: '1001',
            content: '你好',
            time: '12:00',
          ),
        ),
      ],
    );

    final restored = ChatLogDocument.fromJsonString(document.toJsonString());

    expect(restored.messages, hasLength(2));
    expect(restored.messages.last.quote?.sender, '1001');
  });

  test('rejects a third nested chat log', () {
    expect(
      () => ChatLogDocument.fromJsonString(
        '{"schema":"qingtan.chatlog","version":1,"messages":['
        '{"type":"chatlog","nickname":"a","sender":"1","chatlog":'
        '{"schema":"qingtan.chatlog","version":1,"messages":['
        '{"type":"chatlog","nickname":"a","sender":"1","chatlog":'
        '{"schema":"qingtan.chatlog","version":1,"messages":['
        '{"type":"chatlog","nickname":"a","sender":"1","chatlog":'
        '{"schema":"qingtan.chatlog","version":1,"messages":[]}'
        '}]}'
        '}]}'
        '}]}'
      ),
      throwsFormatException,
    );
  });
}
