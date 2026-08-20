import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_service.dart';
import 'llama_service.dart';
import 'termux_service.dart';
import '../models/app_models.dart';

class AppState extends ChangeNotifier {
  final db = DatabaseService();
  final llama = LlamaService();
  final termux = TermuxService();
  List<LocalModel> models = [];
  List<Chat> chats = [];
  List<Message> activeMessages = [];
  List<TerminalEntry> terminalEntries = [];
  List<Map<String, Object?>> mcpServers = [];
  bool onboardingComplete = false;
  bool termuxEnabled = false;
  bool darkMode = true;
  String? activeAttachment;

  Future<void> load() async {
    models = await db.models();
    chats = await db.chats();
    terminalEntries = await db.terminalHistory();
    mcpServers = await db.mcpServers();
    onboardingComplete = await db.setting('onboarding') == 'true';
    termuxEnabled = await db.setting('termux') == 'true';
    darkMode = (await db.setting('darkMode')) != 'false';
    llama.endpoint = await db.setting('endpoint') ?? llama.endpoint;
    notifyListeners();
  }
  Future<void> finishOnboarding() async { onboardingComplete = true; await db.setSetting('onboarding', 'true'); notifyListeners(); }
  Future<void> setDarkMode(bool value) async { darkMode = value; await db.setSetting('darkMode', '$value'); notifyListeners(); }
  Future<void> setTermux(bool value) async { termuxEnabled = value; await db.setSetting('termux', '$value'); notifyListeners(); }
  Future<void> setEndpoint(String value) async { llama.endpoint = value.trim().replaceAll(RegExp(r'/$'), ''); await db.setSetting('endpoint', llama.endpoint); notifyListeners(); }
  Future<void> addMcpServer(String name, String url) async { await db.addMcpServer(name, url); mcpServers = await db.mcpServers(); notifyListeners(); }
  Future<void> deleteMcpServer(int id) async { await db.deleteMcpServer(id); mcpServers = await db.mcpServers(); notifyListeners(); }
  Future<void> addModelFromFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['gguf']);
    final file = result?.files.single;
    if (file?.path == null) return;
    await db.addModel(file!.name, file.path!, file.size);
    models = await db.models(); notifyListeners();
  }
  Future<void> addModelFromLink(String url, void Function(double) progress) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) throw Exception('Enter a direct download URL.');
    final dir = await getApplicationDocumentsDirectoryCompat();
    final name = uri.pathSegments.isEmpty ? 'download.gguf' : uri.pathSegments.last;
    if (!name.toLowerCase().endsWith('.gguf')) throw Exception('The direct link must point to a .gguf file.');
    final response = await http.Client().send(http.Request('GET', uri));
    if (response.statusCode != 200) throw Exception('Download failed (${response.statusCode}).');
    final total = response.contentLength ?? 0; var received = 0;
    final file = File('$dir/$name'); final sink = file.openWrite();
    await for (final chunk in response.stream) { received += chunk.length; sink.add(chunk); if (total > 0) progress(received / total); }
    await sink.close(); await db.addModel(name, file.path, received); models = await db.models(); notifyListeners();
  }
  Future<void> deleteModel(LocalModel model) async { await db.deleteModel(model.id); models = await db.models(); notifyListeners(); }
  Future<int> ensureChat() async { if (chats.isNotEmpty) return chats.first.id; final id = await db.createChat('New conversation'); chats = await db.chats(); notifyListeners(); return id; }
  Future<void> openChat(int chatId) async { activeMessages = await db.messages(chatId); notifyListeners(); }
  Future<void> sendMessage(int chatId, String content) async {
    await db.addMessage(chatId, 'user', content); activeMessages = await db.messages(chatId); notifyListeners();
    final history = activeMessages.map((m) => {'role': m.role, 'content': m.content}).toList();
    var answer = '';
    try { await for (final token in llama.chat(messages: history)) { answer += token; activeMessages = [...activeMessages.where((m) => m.role != 'assistant' || m.id != -1), Message(id: -1, chatId: chatId, role: 'assistant', content: answer, createdAt: DateTime.now())]; notifyListeners(); } await db.addMessage(chatId, 'assistant', answer); activeMessages = await db.messages(chatId); }
    catch (e) { answer = 'Unable to reach local llama-server at ${llama.endpoint}. Start it locally, then try again.\n\n$e'; await db.addMessage(chatId, 'assistant', answer); activeMessages = await db.messages(chatId); }
    notifyListeners();
  }
  Future<void> deleteMessage(Message message) async { if (message.id > 0) await db.deleteMessage(message.id); activeMessages = await db.messages(message.chatId); notifyListeners(); }
  Future<void> pickAttachment() async { final result = await FilePicker.platform.pickFiles(); activeAttachment = result?.files.single.path; notifyListeners(); }
  Future<bool> requestStorage() async => (await Permission.storage.request()).isGranted;
  Future<void> executeTerminal(String command) async { final success = await termux.runCommand(command); await db.addTerminalEntry(command, success); terminalEntries = await db.terminalHistory(); notifyListeners(); }
}

Future<String> getApplicationDocumentsDirectoryCompat() async => (await getApplicationDocumentsDirectory()).path;