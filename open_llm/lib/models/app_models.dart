class Chat {
  const Chat({required this.id, required this.title, required this.createdAt});
  final int id;
  final String title;
  final DateTime createdAt;
}

class Message {
  const Message({
    required this.id,
    required this.chatId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.attachmentPath,
  });
  final int id;
  final int chatId;
  final String role;
  final String content;
  final DateTime createdAt;
  final String? attachmentPath;
}

class LocalModel {
  const LocalModel({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.addedAt,
  });
  final int id;
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime addedAt;
}

class TerminalEntry {
  const TerminalEntry({
    required this.id,
    required this.command,
    required this.createdAt,
    required this.success,
  });
  final int id;
  final String command;
  final DateTime createdAt;
  final bool success;
}