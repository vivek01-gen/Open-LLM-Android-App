import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_models.dart';

class DatabaseService {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(dir.path, 'open_llm.db'),
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Additive/idempotent migration: never drop user data on schema changes.
        await _createTables(db);
      },
    );
    return _db!;
  }

  Future<List<LocalModel>> models() async {
    final rows = await (await database).query('models', orderBy: 'added_at DESC');
    return rows.map((r) => LocalModel(id: r['id'] as int, name: r['name'] as String, path: r['path'] as String, sizeBytes: r['size_bytes'] as int, addedAt: DateTime.fromMillisecondsSinceEpoch(r['added_at'] as int))).toList();
  }

  Future<int> addModel(String name, String path, int size) async => (await database).insert('models', {'name': name, 'path': path, 'size_bytes': size, 'added_at': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> deleteModel(int id) async => (await database).delete('models', where: 'id = ?', whereArgs: [id]);

  Future<List<Chat>> chats() async {
    final rows = await (await database).query('chats', orderBy: 'created_at DESC');
    return rows.map((r) => Chat(id: r['id'] as int, title: r['title'] as String, createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int))).toList();
  }
  Future<int> createChat(String title) async => (await database).insert('chats', {'title': title, 'created_at': DateTime.now().millisecondsSinceEpoch});
  Future<List<Message>> messages(int chatId, {int limit = 100}) async {
    final rows = await (await database).query('messages', where: 'chat_id = ?', whereArgs: [chatId], orderBy: 'created_at DESC', limit: '$limit');
    rows.reverse();
    return rows.map((r) => Message(id: r['id'] as int, chatId: r['chat_id'] as int, role: r['role'] as String, content: r['content'] as String, attachmentPath: r['attachment_path'] as String?, createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int))).toList();
  }
  Future<int> addMessage(int chatId, String role, String content, {String? attachmentPath}) async => (await database).insert('messages', {'chat_id': chatId, 'role': role, 'content': content, 'attachment_path': attachmentPath, 'created_at': DateTime.now().millisecondsSinceEpoch});
  Future<void> deleteMessage(int id) async => (await database).delete('messages', where: 'id = ?', whereArgs: [id]);

  Future<String?> setting(String key) async { final row = await (await database).query('settings', where: 'key = ?', whereArgs: [key]); return row.isEmpty ? null : row.first['value'] as String; }
  Future<void> setSetting(String key, String value) async => (await database).insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<Map<String, Object?>>> mcpServers() async => (await database).query('mcp_servers', orderBy: 'name ASC');
  Future<int> addMcpServer(String name, String url) async => (await database).insert('mcp_servers', {'name': name, 'url': url}, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> deleteMcpServer(int id) async => (await database).delete('mcp_servers', where: 'id = ?', whereArgs: [id]);
  Future<List<TerminalEntry>> terminalHistory() async {
    final rows = await (await database).query('terminal_history', orderBy: 'created_at DESC');
    return rows.map((r) => TerminalEntry(id: r['id'] as int, command: r['command'] as String, createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int), success: r['success'] == 1)).toList();
  }
  Future<void> addTerminalEntry(String command, bool success) async => (await database).insert('terminal_history', {'command': command, 'created_at': DateTime.now().millisecondsSinceEpoch, 'success': success ? 1 : 0});
}

Future<void> _createTables(Database db) async {
  await db.execute('CREATE TABLE IF NOT EXISTS chats (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, created_at INTEGER NOT NULL)');
  await db.execute('CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY AUTOINCREMENT, chat_id INTEGER NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, attachment_path TEXT, created_at INTEGER NOT NULL)');
  await db.execute('CREATE TABLE IF NOT EXISTS models (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, path TEXT NOT NULL UNIQUE, size_bytes INTEGER NOT NULL, added_at INTEGER NOT NULL)');
  await db.execute('CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  await db.execute('CREATE TABLE IF NOT EXISTS mcp_servers (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, url TEXT NOT NULL UNIQUE)');
  await db.execute('CREATE TABLE IF NOT EXISTS terminal_history (id INTEGER PRIMARY KEY AUTOINCREMENT, command TEXT NOT NULL, created_at INTEGER NOT NULL, success INTEGER NOT NULL)');
}