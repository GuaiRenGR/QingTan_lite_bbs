class ThreadModel {
  final int id;
  final int forumId;
  final int userId;
  final String title;
  final String summary;
  final String content;
  final String cover;
  final int viewCount;
  final int replyCount;
  final int likeCount;
  final int favoriteCount;
  final bool isTop;
  final bool isDigest;
  final String createdAt;

  final String authorName;
  final String authorAvatar;
  final String forumName;

  ThreadModel({
    required this.id,
    required this.forumId,
    required this.userId,
    required this.title,
    required this.summary,
    required this.content,
    required this.cover,
    required this.viewCount,
    required this.replyCount,
    required this.likeCount,
    required this.favoriteCount,
    required this.isTop,
    required this.isDigest,
    required this.createdAt,
    required this.authorName,
    required this.authorAvatar,
    required this.forumName,
  });

  factory ThreadModel.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return ThreadModel.empty();
    }

    final user = json['user'];
    final forum = json['forum'];

    return ThreadModel(
      id: _toInt(json['id']),
      forumId: _toInt(json['forum_id']),
      userId: _toInt(json['user_id']),
      title: _toString(json['title'], fallback: '无标题'),
      summary: _toString(json['summary']),
      content: _toString(json['content']),
      cover: _toString(json['cover']),
      viewCount: _toInt(json['view_count']),
      replyCount: _toInt(json['reply_count']),
      likeCount: _toInt(json['like_count']),
      favoriteCount: _toInt(json['favorite_count']),
      isTop: _toBool(json['is_top']),
      isDigest: _toBool(json['is_digest']),
      createdAt: _toString(json['created_at']),
      authorName: user is Map
          ? _toString(user['nickname'], fallback: '匿名用户')
          : _toString(json['nickname'], fallback: '匿名用户'),
      authorAvatar: user is Map
          ? _toString(user['avatar'])
          : _toString(json['avatar']),
      forumName: forum is Map
          ? _toString(forum['name'], fallback: '社区')
          : _toString(json['forum_name'], fallback: '社区'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'thread_id': id,
      'forum_id': forumId,
      'user_id': userId,
      'title': title,
      'summary': summary,
      'cover': cover,
      'like_count': likeCount,
      'reply_count': replyCount,
      'favorite_count': favoriteCount,
      'created_at': createdAt,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'is_top': isTop,
      'is_digest': isDigest,
    };
  }

  factory ThreadModel.empty() {
    return ThreadModel(
      id: 0,
      forumId: 0,
      userId: 0,
      title: '无标题',
      summary: '',
      content: '',
      cover: '',
      viewCount: 0,
      replyCount: 0,
      likeCount: 0,
      favoriteCount: 0,
      isTop: false,
      isDigest: false,
      createdAt: '',
      authorName: '匿名用户',
      authorAvatar: '',
      forumName: '社区',
    );
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  static String _toString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final str = value.toString();
    return str.isEmpty ? fallback : str;
  }
}
