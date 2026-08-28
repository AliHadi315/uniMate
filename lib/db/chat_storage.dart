import 'package:unimate/db/db_provider.dart';
import 'package:unimate/db/tables.dart';

import '../models/chat.dart';

/// Chat sessions survive restarts, so the "Chat History" drawer is real
/// history rather than in-memory state.

Future<List<ChatSession>> loadChatSessions(int userId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(
    DbTables.chatSessions,
    where: 'userId = ?',
    whereArgs: [userId],
    orderBy: 'updatedAtMillis DESC',
  );
  return rows.map(ChatSession.fromMap).toList();
}

Future<List<ChatMessage>> loadChatMessages(int sessionId) async {
  final db = await DatabaseProvider.getDatabase();
  final rows = await db.query(
    DbTables.chatMessages,
    where: 'sessionId = ?',
    whereArgs: [sessionId],
    orderBy: 'createdAtMillis ASC, id ASC',
  );
  return rows.map(ChatMessage.fromMap).toList();
}

/// Creates a session and writes all of [messages] in one transaction.
Future<int> saveChatSession({
  required int userId,
  required String title,
  required List<ChatMessage> messages,
}) async {
  final db = await DatabaseProvider.getDatabase();
  final now = DateTime.now().millisecondsSinceEpoch;

  return db.transaction((txn) async {
    final sessionId = await txn.insert(DbTables.chatSessions, {
      'userId': userId,
      'title': title,
      'createdAtMillis': now,
      'updatedAtMillis': now,
    });

    for (final message in messages) {
      final map = message.copyWith(sessionId: sessionId).toMap()..remove('id');
      await txn.insert(DbTables.chatMessages, map);
    }

    return sessionId;
  });
}

/// Replaces the messages of an existing session.
Future<void> updateChatSession({
  required int sessionId,
  String? title,
  required List<ChatMessage> messages,
}) async {
  final db = await DatabaseProvider.getDatabase();
  final now = DateTime.now().millisecondsSinceEpoch;

  await db.transaction((txn) async {
    await txn.update(
      DbTables.chatSessions,
      {'updatedAtMillis': now, if (title != null) 'title': title},
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    await txn.delete(
      DbTables.chatMessages,
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );

    for (final message in messages) {
      final map = message.copyWith(sessionId: sessionId).toMap()..remove('id');
      await txn.insert(DbTables.chatMessages, map);
    }
  });
}

Future<int> renameChatSession(int sessionId, String title) async {
  final db = await DatabaseProvider.getDatabase();
  return db.update(
    DbTables.chatSessions,
    {'title': title},
    where: 'id = ?',
    whereArgs: [sessionId],
  );
}

Future<int> deleteChatSession(int sessionId) async {
  final db = await DatabaseProvider.getDatabase();
  return db.delete(
    DbTables.chatSessions,
    where: 'id = ?',
    whereArgs: [sessionId],
  );
}
