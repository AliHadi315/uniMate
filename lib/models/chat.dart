/// A saved AI conversation and its messages.
class ChatSession {
  final int? id;
  final int userId;
  final String title;
  final int createdAtMillis;
  final int updatedAtMillis;

  const ChatSession({
    this.id,
    required this.userId,
    required this.title,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });

  DateTime get updatedAt =>
      DateTime.fromMillisecondsSinceEpoch(updatedAtMillis);

  ChatSession copyWith({int? id, String? title, int? updatedAtMillis}) {
    return ChatSession(
      id: id ?? this.id,
      userId: userId,
      title: title ?? this.title,
      createdAtMillis: createdAtMillis,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'createdAtMillis': createdAtMillis,
    'updatedAtMillis': updatedAtMillis,
  };

  factory ChatSession.fromMap(Map<String, Object?> map) => ChatSession(
    id: map['id'] as int?,
    userId: (map['userId'] as int?) ?? 0,
    title: map['title'] as String,
    createdAtMillis: map['createdAtMillis'] as int,
    updatedAtMillis: map['updatedAtMillis'] as int,
  );
}

class ChatMessage {
  final int? id;
  final int sessionId;

  /// Either `user` or `assistant`.
  final String role;
  final String content;
  final int createdAtMillis;

  const ChatMessage({
    this.id,
    this.sessionId = 0,
    required this.role,
    required this.content,
    required this.createdAtMillis,
  });

  bool get isUser => role == 'user';

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtMillis);

  ChatMessage copyWith({int? id, int? sessionId}) => ChatMessage(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    role: role,
    content: content,
    createdAtMillis: createdAtMillis,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'sessionId': sessionId,
    'role': role,
    'content': content,
    'createdAtMillis': createdAtMillis,
  };

  factory ChatMessage.fromMap(Map<String, Object?> map) => ChatMessage(
    id: map['id'] as int?,
    sessionId: map['sessionId'] as int,
    role: map['role'] as String,
    content: map['content'] as String,
    createdAtMillis: map['createdAtMillis'] as int,
  );
}
