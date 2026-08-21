import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';
import 'llama_service.dart';
import 'termux_service.dart';
import '../models/app_models.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final db = DatabaseService();
  final llama = LlamaService();
  final termux = TermuxService();
  List<LocalModel> models = [];
  List<Chat> chats = [];
  List<Message> activeMessages = [];
  List<TerminalEntry> terminalEntries = [];
  List<Map<String, Object?>> mcpServers = [];
  int? activeModelId;
  bool _isBackgrounded = false;
  bool onboardingComplete = false;
  bool initialized = false;
  bool termuxEnabled = false;
  bool darkMode = true;
  String? activeAttachment;

  AppState() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isBackgrounded = state == AppLifecycleState.paused || state == AppLifecycleState.detached;
    if (!_isBackgrounded) notifyListeners();
  }

  Future<void> load() async {
    models = await db.models();
    chats = await db.chats();
    terminalEntries = await db.terminalHistory();
    mcpServers = await db.mcpServers();
    onboardingComplete = await db.setting('onboarding') == 'true';
    termuxEnabled = await db.setting('termux') == 'true';
    darkMode = (await db.setting('darkMode')) != 'false';
    final storedEndpoint = await db.setting('endpoint');
    final storedUri = storedEndpoint == null ? null : Uri.tryParse(storedEndpoint);
    if (storedUri != null && storedUri.scheme == 'http' && ['localhost', '127.0.0.1', '::1'].contains(storedUri.host)) {
      llama.endpoint = storedEndpoint;
    }
    final storedModel = await db.setting('activeModelId');
    activeModelId = storedModel == null ? (models.isEmpty ? null : models.first.id) : int.tryParse(storedModel);
    if (activeModelId != null && !models.any((model) => model.id == activeModelId)) {
      activeModelId = models.isEmpty ? null : models.first.id;
    }
    initialized = true;
    notifyListeners();
  }
  Future<void> finishOnboarding() async { onboardingComplete = true; await db.setSetting('onboarding', 'true'); notifyListeners(); }
  Future<void> setDarkMode(bool value) async { darkMode = value; await db.setSetting('darkMode', '$value'); notifyListeners(); }
  Future<void> setTermux(bool value) async { termuxEnabled = value; await db.setSetting('termux', '$value'); notifyListeners(); }
  Future<bool> setEndpoint(String value) async {
    final normalized = value.trim().replaceAll(RegExp(r'/$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.scheme != 'http' || !['localhost', '127.0.0.1', '::1'].contains(uri.host)) return false;
    llama.endpoint = normalized;
    await db.setSetting('endpoint', llama.endpoint);
    notifyListeners();
    return true;
  }
  Future<void> selectModel(LocalModel model) async { activeModelId = model.id; await db.setSetting('activeModelId', '${model.id}'); notifyListeners(); }
  Future<void> addMcpServer(String name, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (name.trim().isEmpty || uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return;
    }
    await db.addMcpServer(name.trim(), url.trim());
    mcpServers = await db.mcpServers();
    notifyListeners();
  }
  Future<void> deleteMcpServer(int id) async { await db.deleteMcpServer(id); mcpServers = await db.mcpServers(); notifyListeners(); }
  Future<void> addModelFromFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['gguf']);
    final file = result?.files.single;
    if (file?.path == null) return;
    final storedPath = await _copyIntoModelDirectory(file.path!, file.name);
    await db.addModel(file.name, storedPath, file.size);
    models = await db.models();
    if (activeModelId == null) {
      activeModelId = models.first.id;
      await db.setSetting('activeModelId', '${activeModelId!}');
    }
    notifyListeners();
  }
  Future<void> addModelFromLink(String url, void Function(double) progress) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) throw Exception('Enter a direct download URL.');
    final dir = await getApplicationDocumentsDirectoryCompat();
    final name = uri.pathSegments.isEmpty ? 'download.gguf' : uri.pathSegments.last;
    if (!name.toLowerCase().endsWith('.gguf')) throw Exception('The direct link must point to a .gguf file.');
    final client = http.Client();
    late final http.StreamedResponse response;
    try {
      response = await client.send(http.Request('GET', uri)).timeout(const Duration(minutes: 10));
    } on Object {
      client.close();
      rethrow;
    }
    if (response.statusCode != 200) { client.close(); throw Exception('Download failed (${response.statusCode}).'); }
    final total = response.contentLength ?? 0; var received = 0;
    final file = File('$dir/${_safeFileName(name)}'); final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) { received += chunk.length; sink.add(chunk); if (total > 0) progress(received / total); }
      await sink.close(); client.close();
    } catch (_) {
      await sink.close();
      client.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
    await db.addModel(name, file.path, received);
    models = await db.models();
    if (activeModelId == null) {
      activeModelId = models.first.id;
      await db.setSetting('activeModelId', '${activeModelId!}');
    }
    notifyListeners();
  }
  Future<void> deleteModel(LocalModel model) async {
    await db.deleteModel(model.id);
    final file = File(model.path);
    if (await file.exists() && path.isWithin((await getApplicationDocumentsDirectory()).path, file.path)) await file.delete();
    models = await db.models();
    if (activeModelId == model.id) {
      activeModelId = models.isEmpty ? null : models.first.id;
      if (activeModelId == null) {
        await db.setSetting('activeModelId', '');
      } else {
        await db.setSetting('activeModelId', '${activeModelId!}');
      }
    }
    _responseGeneration++;
    notifyListeners();
  }
  Future<int> ensureChat() async { if (chats.isNotEmpty) return chats.first.id; final id = await db.createChat('New conversation'); chats = await db.chats(); notifyListeners(); return id; }
  Future<void> openChat(int chatId) async { activeMessages = await db.messages(chatId); notifyListeners(); }
  int _responseGeneration = 0;
  Future<void> sendMessage(int chatId, String content, {String? attachmentPath}) async {
    if (models.isEmpty || activeModelId == null) {
      await db.addMessage(chatId, 'assistant', 'Add a local GGUF model before starting a conversation.');
      activeMessages = await db.messages(chatId);
      notifyListeners();
      return;
    }
    final generation = ++_responseGeneration;
    await db.addMessage(chatId, 'user', content, attachmentPath: attachmentPath); activeMessages = await db.messages(chatId); notifyListeners();
    final history = activeMessages.map((m) => {'role': m.role, 'content': m.content}).toList();
    var answer = '';
    try {
      await for (final token in llama.chat(messages: history)) {
        if (generation != _responseGeneration) return;
        answer += token;
        activeMessages = [...activeMessages.where((m) => m.id != -1), Message(id: -1, chatId: chatId, role: 'assistant', content: answer, createdAt: DateTime.now())];
        notifyListeners();
      }
      if (generation != _responseGeneration) return;
      await db.addMessage(chatId, 'assistant', answer.isEmpty ? 'The local server returned an empty response.' : answer);
      activeMessages = await db.messages(chatId);
    } catch (e) {
      if (generation != _responseGeneration) return;
      final message = e.toString().replaceFirst('LlamaException: ', '');
      answer = 'Local model error: $message';
      await db.addMessage(chatId, 'assistant', answer);
      activeMessages = await db.messages(chatId);
    }
    notifyListeners();
  }
  Future<void> deleteMessage(Message message) async { if (message.id > 0) await db.deleteMessage(message.id); activeMessages = await db.messages(message.chatId); notifyListeners(); }
  Future<void> pickAttachment() async { final result = await FilePicker.platform.pickFiles(); activeAttachment = result?.files.single.path; notifyListeners(); }
  Future<bool> requestStorage() async => true;
  Future<void> executeTerminal(String command, {required bool confirmed}) async {
    if (!confirmed) return;
    if (!termuxEnabled || command.trim().isEmpty) return;
    final success = await termux.runCommand(command);
    await db.addTerminalEntry(command, success);
    terminalEntries = await db.terminalHistory();
    notifyListeners();
  }

  bool get isBackgrounded => _isBackgrounded;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

Future<String> getApplicationDocumentsDirectoryCompat() async => (await getApplicationDocumentsDirectory()).path;

Future<String> _copyIntoModelDirectory(String sourcePath, String originalName) async {
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory(path.join(root.path, 'models'));
  await directory.create(recursive: true);
  final destination = File(path.join(directory.path, _safeFileName(originalName)));
  return (await File(sourcePath).copy(destination.path)).path;
}

String _safeFileName(String name) {
  final base = path.basename(name).replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return base.toLowerCase().endsWith('.gguf') ? base : '$base.gguf';
}