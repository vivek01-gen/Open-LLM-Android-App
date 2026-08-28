import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/app_models.dart';
import '../models/device_models.dart';
import '../models/model_catalog.dart';
import 'database_service.dart';
import 'device_capability_service.dart';
import 'llama_service.dart';
import 'model_server_service.dart';
import 'security_service.dart';
import 'termux_service.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final db = DatabaseService();
  final termux = TermuxService();
  final deviceService = DeviceCapabilityService();
  final modelServer = ModelServerService();
  final security = SecurityService();
  late final LlamaService llama;

  List<LocalModel> models = [];
  List<Chat> chats = [];
  List<Message> activeMessages = [];
  List<TerminalEntry> terminalEntries = [];
  List<Map<String, Object?>> mcpServers = [];
  List<NetworkLogEntry> networkLogs = [];
  DeviceCapabilities? deviceCapabilities;
  int? activeModelId;
  bool _isBackgrounded = false;
  bool onboardingComplete = false;
  bool privacyAgreed = false;
  bool termsAgreed = false;
  bool initialized = false;
  bool termuxEnabled = false;
  bool darkMode = true;
  bool appLockEnabled = false;
  bool appLocked = false;
  bool networkActivityLogEnabled = false;
  bool showAllCatalogModels = false;
  bool modelLoading = false;
  String serverStatus = '';
  String? activeAttachment;
  int _responseGeneration = 0;

  AppState() {
    llama = LlamaService(onNetworkRequest: _recordNetworkRequest);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isBackgrounded =
        state == AppLifecycleState.paused || state == AppLifecycleState.detached;
    if (state == AppLifecycleState.resumed && appLockEnabled) {
      appLocked = true;
    }
    notifyListeners();
  }

  Future<void> load() async {
    models = await db.models();
    chats = await db.chats();
    terminalEntries = await db.terminalHistory();
    mcpServers = await db.mcpServers();
    networkLogs = await db.networkLogs();
    privacyAgreed = await db.setting('privacy') == 'true';
    termsAgreed = await db.setting('terms') == 'true';
    onboardingComplete = await db.setting('onboarding') == 'true' &&
        privacyAgreed &&
        termsAgreed;
    termuxEnabled = await db.setting('termux') == 'true';
    darkMode = (await db.setting('darkMode')) != 'false';
    appLockEnabled = await db.setting('appLock') == 'true';
    appLocked = appLockEnabled;
    networkActivityLogEnabled = await db.setting('networkLog') == 'true';
    showAllCatalogModels = await db.setting('showAllModels') == 'true';

    final storedEndpoint = await db.setting('endpoint');
    final storedUri =
        storedEndpoint == null ? null : Uri.tryParse(storedEndpoint);
    if (storedUri != null &&
        storedUri.scheme == 'http' &&
        ['localhost', '127.0.0.1', '::1'].contains(storedUri.host)) {
      llama.endpoint = storedEndpoint ?? llama.endpoint;
    }
    final storedModel = await db.setting('activeModelId');
    activeModelId = storedModel == null
        ? (models.isEmpty ? null : models.first.id)
        : int.tryParse(storedModel);
    if (activeModelId != null &&
        !models.any((model) => model.id == activeModelId)) {
      activeModelId = models.isEmpty ? null : models.first.id;
    }

    final storedTier = int.tryParse(await db.setting('deviceTier') ?? '');
    if (storedTier == null) {
      await scanDevice();
    } else {
      deviceCapabilities = DeviceCapabilities(
        tier: DeviceTier.fromLevel(storedTier),
        ramBytes: int.tryParse(await db.setting('deviceRam') ?? '') ?? 0,
        cpuCores: int.tryParse(await db.setting('deviceCores') ?? '') ?? 1,
        freeStorageBytes:
            int.tryParse(await db.setting('deviceFreeStorage') ?? '') ?? 0,
      );
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    if (!privacyAgreed || !termsAgreed) return;
    onboardingComplete = true;
    await db.setSetting('onboarding', 'true');
    notifyListeners();
  }

  Future<void> setPrivacyAgreed(bool value) async {
    privacyAgreed = value;
    await db.setSetting('privacy', '$value');
    notifyListeners();
  }

  Future<void> setTermsAgreed(bool value) async {
    termsAgreed = value;
    await db.setSetting('terms', '$value');
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    await db.setSetting('darkMode', '$value');
    notifyListeners();
  }

  Future<void> setTermux(bool value) async {
    termuxEnabled = value;
    await db.setSetting('termux', '$value');
    notifyListeners();
  }

  Future<void> setNetworkActivityLog(bool value) async {
    networkActivityLogEnabled = value;
    await db.setSetting('networkLog', '$value');
    if (value) networkLogs = await db.networkLogs();
    notifyListeners();
  }

  Future<void> setShowAllCatalogModels(bool value) async {
    showAllCatalogModels = value;
    await db.setSetting('showAllModels', '$value');
    notifyListeners();
  }

  Future<void> scanDevice() async {
    deviceCapabilities = await deviceService.scan();
    final capabilities = deviceCapabilities!;
    await db.setSetting('deviceTier', '${capabilities.tier.level}');
    await db.setSetting('deviceRam', '${capabilities.ramBytes}');
    await db.setSetting('deviceCores', '${capabilities.cpuCores}');
    await db.setSetting(
      'deviceFreeStorage',
      '${capabilities.freeStorageBytes}',
    );
    notifyListeners();
  }

  Future<bool> unlockApp() async {
    final unlocked = await security.authenticate();
    if (unlocked) {
      appLocked = false;
      notifyListeners();
    }
    return unlocked;
  }

  Future<bool> enableAppLock() async {
    if (!await security.canUseBiometrics()) return false;
    if (!await security.authenticate()) return false;
    appLockEnabled = true;
    appLocked = false;
    await db.setSetting('appLock', 'true');
    notifyListeners();
    return true;
  }

  Future<void> disableAppLock() async {
    appLockEnabled = false;
    appLocked = false;
    await db.setSetting('appLock', 'false');
    notifyListeners();
  }

  Future<bool> setEndpoint(String value) async {
    final normalized = value.trim().replaceAll(RegExp(r'/$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        uri.scheme != 'http' ||
        !['localhost', '127.0.0.1', '::1'].contains(uri.host)) {
      return false;
    }
    llama.endpoint = normalized;
    await db.setSetting('endpoint', llama.endpoint);
    notifyListeners();
    return true;
  }

  Future<void> selectModel(LocalModel model) async {
    activeModelId = model.id;
    await db.setSetting('activeModelId', '${model.id}');
    notifyListeners();
    await prepareModel(model);
  }

  Future<void> addMcpServer(String name, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (name.trim().isEmpty ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      return;
    }
    await db.addMcpServer(name.trim(), url.trim());
    mcpServers = await db.mcpServers();
    notifyListeners();
  }

  Future<void> deleteMcpServer(int id) async {
    await db.deleteMcpServer(id);
    mcpServers = await db.mcpServers();
    notifyListeners();
  }

  Future<void> addModelFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gguf'],
    );
    final file = result?.files.single;
    if (file == null || file.path == null) return;
    final storedPath = await _copyIntoModelDirectory(file.path!, file.name);
    await db.addModel(file.name, storedPath, file.size);
    models = await db.models();
    if (activeModelId == null) {
      activeModelId = models.first.id;
      await db.setSetting('activeModelId', '${activeModelId!}');
    }
    notifyListeners();
  }

  Future<void> addModelFromLink(
    String url,
    void Function(double) progress,
  ) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      throw Exception('Enter a direct download URL.');
    }
    final dir = await getApplicationDocumentsDirectoryCompat();
    final name =
        uri.pathSegments.isEmpty ? 'download.gguf' : uri.pathSegments.last;
    if (!name.toLowerCase().endsWith('.gguf')) {
      throw Exception('The direct link must point to a .gguf file.');
    }
    final client = http.Client();
    late final http.StreamedResponse response;
    try {
      response = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(minutes: 10));
      await _recordNetworkRequest('GET', uri.toString(), response.statusCode);
    } on Object {
      client.close();
      rethrow;
    }
    if (response.statusCode != 200) {
      client.close();
      throw Exception('Download failed (${response.statusCode}).');
    }
    final total = response.contentLength ?? 0;
    var received = 0;
    var header = <int>[];
    final file = File('$dir/${_safeFileName(name)}');
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream) {
        if (header.length < 4) {
          header = [...header, ...chunk].take(4).toList();
        }
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) progress(received / total);
      }
      await sink.close();
      client.close();
      if (total > 0 && received != total) {
        throw Exception('The download was incomplete ($received of $total bytes).');
      }
      if (received < 1024 * 1024 || !_isGgufHeader(header)) {
        throw Exception('The downloaded file is not a valid GGUF model.');
      }
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

  List<CatalogModel> get visibleCatalogModels {
    final tier = deviceCapabilities?.tier ?? DeviceTier.low;
    return curatedModels
        .where((model) => showAllCatalogModels || model.tier.level <= tier.level)
        .toList();
  }

  Future<bool> downloadCatalogModel(
    CatalogModel model,
    void Function(double progress, int received, int? total) onProgress,
  ) async {
    if (modelLoading) return false;
    final capabilities = deviceCapabilities;
    if (capabilities == null) throw Exception('Device scan is not complete.');
    if (capabilities.freeStorageBytes > 0 &&
        capabilities.freeStorageBytes <
            model.approximateSizeBytes + 256 * 1024 * 1024) {
      throw Exception(
        'Not enough app-private storage for this model. Free up space or choose a smaller model.',
      );
    }
    modelLoading = true;
    serverStatus = 'Downloading ${model.name}…';
    notifyListeners();

    final documents = await getApplicationDocumentsDirectoryCompat();
    final modelsDirectory = Directory(path.join(documents, 'models'));
    await modelsDirectory.create(recursive: true);
    final safeName = _safeFileName(model.filename);
    final temporaryFile = File(path.join(modelsDirectory.path, '$safeName.part'));
    final finalFile = File(path.join(modelsDirectory.path, safeName));
    final client = http.Client();
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(model.downloadUrl)))
          .timeout(const Duration(minutes: 30));
      await _recordNetworkRequest(
        'GET',
        model.downloadUrl,
        response.statusCode,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Download failed (${response.statusCode}).');
      }
      final total = response.contentLength;
      var received = 0;
      var header = <int>[];
      final digestSink = AccumulatorSink<Digest>();
      final digestInput = sha256.startChunkedConversion(digestSink);
      final sink = temporaryFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          if (header.length < 4) {
            header = [...header, ...chunk].take(4).toList();
          }
          digestInput.add(chunk);
          sink.add(chunk);
          received += chunk.length;
          onProgress(
            total != null && total > 0 ? received / total : 0,
            received,
            total,
          );
        }
        await sink.close();
        digestInput.close();
      } catch (_) {
        await sink.close();
        rethrow;
      }
      if (total != null && received != total) {
        throw Exception('The download was incomplete ($received of $total bytes).');
      }
      if (received < 1024 * 1024 || !_isGgufHeader(header)) {
        throw Exception('The downloaded file is not a valid GGUF model.');
      }
      final digest = digestSink.events.single.toString();
      if (model.sha256 != null &&
          digest.toLowerCase() != model.sha256!.toLowerCase()) {
        throw Exception('The model checksum did not match.');
      }
      if (await finalFile.exists()) await finalFile.delete();
      await temporaryFile.rename(finalFile.path);
      final id = await db.addModel(model.name, finalFile.path, received);
      models = await db.models();
      activeModelId = id;
      await db.setSetting('activeModelId', '$id');
       return await prepareModel(models.firstWhere((item) => item.id == id));
    } catch (error) {
      if (await temporaryFile.exists()) await temporaryFile.delete();
      rethrow;
    } finally {
      client.close();
      modelLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteModel(LocalModel model) async {
    await db.deleteModel(model.id);
    final file = File(model.path);
    final documents = await getApplicationDocumentsDirectory();
    if (await file.exists() &&
        path.isWithin(documents.path, file.path)) {
      await file.delete();
    }
    models = await db.models();
    if (activeModelId == model.id) {
      activeModelId = models.isEmpty ? null : models.first.id;
      await db.setSetting('activeModelId', '${activeModelId ?? ''}');
    }
    _responseGeneration++;
    notifyListeners();
  }

  Future<bool> prepareModel(LocalModel model) async {
    final capabilities = deviceCapabilities;
    if (capabilities == null) return false;
    modelLoading = true;
    serverStatus =
        'Loading ${model.name}… This may take 10–30 seconds on first load.';
    notifyListeners();
    final started = await modelServer.start(
      modelPath: model.path,
      capabilities: capabilities,
    );
    serverStatus = started
        ? 'Ready to chat.'
        : 'Model installed. Start llama-server at ${llama.endpoint} to chat.';
    modelLoading = false;
    notifyListeners();
    return started;
  }

  Future<int> ensureChat() async {
    if (chats.isNotEmpty) return chats.first.id;
    final id = await db.createChat('New conversation');
    chats = await db.chats();
    notifyListeners();
    return id;
  }

  Future<void> openChat(int chatId) async {
    activeMessages = await db.messages(chatId);
    notifyListeners();
  }

  Future<void> sendMessage(
    int chatId,
    String content, {
    String? attachmentPath,
  }) async {
    if (modelLoading) return;
    if (models.isEmpty || activeModelId == null) {
      await db.addMessage(
        chatId,
        'assistant',
        'Add a local GGUF model before starting a conversation.',
      );
      activeMessages = await db.messages(chatId);
      notifyListeners();
      return;
    }
    final generation = ++_responseGeneration;
    await db.addMessage(
      chatId,
      'user',
      content,
      attachmentPath: attachmentPath,
    );
    activeMessages = await db.messages(chatId);
    notifyListeners();
    final history = activeMessages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
    var answer = '';
    try {
      await for (final token in llama.chat(messages: history)) {
        if (generation != _responseGeneration) return;
        answer += token;
        activeMessages = [
          ...activeMessages.where((m) => m.id != -1),
          Message(
            id: -1,
            chatId: chatId,
            role: 'assistant',
            content: answer,
            createdAt: DateTime.now(),
          ),
        ];
        notifyListeners();
      }
      if (generation != _responseGeneration) return;
      await db.addMessage(
        chatId,
        'assistant',
        answer.isEmpty
            ? 'The local server returned an empty response.'
            : answer,
      );
      activeMessages = await db.messages(chatId);
    } catch (e) {
      if (generation != _responseGeneration) return;
      final message = e.toString().replaceFirst('LlamaException: ', '');
      await db.addMessage(chatId, 'assistant', 'Local model error: $message');
      activeMessages = await db.messages(chatId);
    }
    notifyListeners();
  }

  Future<void> deleteMessage(Message message) async {
    if (message.id > 0) await db.deleteMessage(message.id);
    activeMessages = await db.messages(message.chatId);
    notifyListeners();
  }

  Future<void> pickAttachment() async {
    final result = await FilePicker.platform.pickFiles();
    activeAttachment = result?.files.single.path;
    notifyListeners();
  }

  Future<bool> requestStorage() async => true;

  Future<void> executeTerminal(
    String command, {
    required bool confirmed,
  }) async {
    if (!confirmed || !termuxEnabled || command.trim().isEmpty) return;
    final success = await termux.runCommand(command);
    await db.addTerminalEntry(command, success);
    terminalEntries = await db.terminalHistory();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    final documents = await getApplicationDocumentsDirectory();
    final modelsDirectory = Directory(path.join(documents.path, 'models'));
    if (await modelsDirectory.exists()) {
      await modelsDirectory.delete(recursive: true);
    }
    await modelServer.stop();
    await db.clearAllData();
    models = [];
    chats = [];
    activeMessages = [];
    terminalEntries = [];
    mcpServers = [];
    networkLogs = [];
    activeModelId = null;
    deviceCapabilities = null;
    onboardingComplete = false;
    privacyAgreed = false;
    termsAgreed = false;
    termuxEnabled = false;
    darkMode = true;
    appLockEnabled = false;
    appLocked = false;
    networkActivityLogEnabled = false;
    showAllCatalogModels = false;
    serverStatus = '';
    notifyListeners();
  }

  Future<void> _recordNetworkRequest(
    String method,
    String url,
    int? statusCode,
  ) async {
    if (!networkActivityLogEnabled) return;
    await db.addNetworkLog(method, url, statusCode);
    networkLogs = await db.networkLogs();
    notifyListeners();
  }

  static bool _isGgufHeader(List<int> header) =>
      header.length == 4 &&
      header[0] == 0x47 &&
      header[1] == 0x47 &&
      header[2] == 0x55 &&
      header[3] == 0x46;

  bool get isBackgrounded => _isBackgrounded;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

Future<String> getApplicationDocumentsDirectoryCompat() async =>
    (await getApplicationDocumentsDirectory()).path;

Future<String> _copyIntoModelDirectory(
  String sourcePath,
  String originalName,
) async {
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory(path.join(root.path, 'models'));
  await directory.create(recursive: true);
  final destination = File(path.join(directory.path, _safeFileName(originalName)));
  return (await File(sourcePath).copy(destination.path)).path;
}

String _safeFileName(String name) {
  final base =
      path.basename(name).replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return base.toLowerCase().endsWith('.gguf') ? base : '$base.gguf';
}