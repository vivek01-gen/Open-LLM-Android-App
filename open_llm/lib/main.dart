import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/app_models.dart';
import 'services/app_state.dart';
import 'theme/app_theme.dart';

void main() => runApp(ChangeNotifierProvider(create: (_) => AppState()..load(), child: const OpenLlmApp()));

class OpenLlmApp extends StatelessWidget {
  const OpenLlmApp({super.key});
  @override
  Widget build(BuildContext context) => Consumer<AppState>(
        builder: (_, state, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Open LLM',
          theme: state.darkMode ? AppTheme.dark() : AppTheme.light(),
          home: !state.initialized
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : state.onboardingComplete
                  ? const ShellScreen()
                  : const OnboardingScreen(),
        ),
      );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}
class _OnboardingScreenState extends State<OnboardingScreen> {
  int page = 0; bool agreed = false; bool askTermux = false;
  final privacy = 'Open LLM is local-first. Your conversations, model files, settings, and history remain on this device. The app only talks to the local llama-server endpoint you configure. Optional Termux integration is disabled by default and never executes commands without your confirmation.';
  @override Widget build(BuildContext context) {
    final titles = ['Welcome to Open LLM', 'Privacy first', 'Choose your permissions'];
    return Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Spacer(), Icon(page == 0 ? Icons.offline_bolt : page == 1 ? Icons.shield_outlined : Icons.tune, size: 64, color: Colors.lightBlueAccent),
      const SizedBox(height: 24), Text(titles[page], style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 18),
      if (page == 0) const Text('Private AI that lives with you. Run quantized GGUF models on your phone with no account, no cloud, and no telemetry.'),
      if (page == 1) Expanded(child: SingleChildScrollView(child: Text(privacy, style: Theme.of(context).textTheme.bodyLarge))),
      if (page == 1) CheckboxListTile(contentPadding: EdgeInsets.zero, value: agreed, onChanged: (v) => setState(() => agreed = v ?? false), title: const Text('I have read and agree to the privacy policy')),
      if (page == 2) Column(children: [
        ListTile(leading: const Icon(Icons.folder_copy_outlined), title: const Text('App-private storage'), subtitle: const Text('The Android file picker grants access to the file you choose; model copies stay inside Open LLM storage.'), trailing: FilledButton(onPressed: () => context.read<AppState>().requestStorage(), child: const Text('Continue'))),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: askTermux, onChanged: (v) => setState(() => askTermux = v), title: const Text('Advanced — Optional'), subtitle: const Text('Enable Termux:API command execution. Every command will still ask before running.')),
      ]),
      const Spacer(), Row(children: [
        if (page > 0) TextButton(onPressed: () => setState(() => page--), child: const Text('Back')),
        const Spacer(), FilledButton(onPressed: (page == 1 && !agreed) ? null : () async { if (page < 2) { setState(() => page++); } else { await context.read<AppState>().setTermux(askTermux); await context.read<AppState>().finishOnboarding(); } }, child: Text(page == 2 ? 'Start privately' : 'Continue')),
      ]),
    ]))));
  }
}

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override State<ShellScreen> createState() => _ShellScreenState();
}
class _ShellScreenState extends State<ShellScreen> {
  int tab = 0;
  final pages = const [HomeScreen(), ModelHubScreen(), SettingsScreen()];
  @override Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: tab, children: pages),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
      NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chats'),
      NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: 'Model Hub'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
    ]),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (_, state, __) {
        if (state.models.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Open LLM')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.memory, size: 72, color: Colors.lightBlueAccent),
                    const SizedBox(height: 18),
                    Text('Your local AI space', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    const Text('Add a GGUF model to start a private conversation. Nothing leaves this device.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ModelHubScreen())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add a model'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Open LLM'),
            actions: [
              IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TerminalHistoryScreen())),
                icon: const Icon(Icons.terminal),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Conversations', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              ...state.chats.map(
                (chat) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.chat)),
                    title: Text(chat.title),
                    subtitle: Text(DateFormat.yMMMd().format(chat.createdAt)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chat: chat))),
                  ),
                ),
              ),
              if (state.chats.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('No conversations yet. Open a chat to begin.', textAlign: TextAlign.center),
                ),
              FilledButton.icon(
                onPressed: () async {
                  final id = await state.ensureChat();
                  final chat = state.chats.firstWhere((c) => c.id == id);
                  if (context.mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)));
                  }
                },
                icon: const Icon(Icons.add_comment),
                label: const Text('New chat'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chat}); final Chat chat;
  @override State<ChatScreen> createState() => _ChatScreenState();
}
class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController(); bool sending = false;
  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().openChat(widget.chat.id)); }
  Future<void> send() async { final text = input.text.trim(); if (text.isEmpty || sending) return; final attachment = context.read<AppState>().activeAttachment; input.clear(); context.read<AppState>().activeAttachment = null; setState(() => sending = true); await context.read<AppState>().sendMessage(widget.chat.id, text, attachmentPath: attachment); if (mounted) setState(() => sending = false); }
  @override void dispose() { input.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Consumer<AppState>(builder: (_, state, __) => Scaffold(
    appBar: AppBar(title: Text(widget.chat.title), actions: [Tooltip(message: state.llama.endpoint, child: const Icon(Icons.lan_outlined)), const SizedBox(width: 12)]),
    body: Column(children: [
          Expanded(child: state.activeMessages.isEmpty ? const Center(child: Text('Ask your local model anything.')) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: state.activeMessages.length + (state.activeMessages.length >= 100 ? 1 : 0), itemBuilder: (_, i) {
        if (state.activeMessages.length >= 100 && i == 0) return const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Showing the latest 100 messages.', textAlign: TextAlign.center));
        final messageIndex = state.activeMessages.length >= 100 ? i - 1 : i;
        final m = state.activeMessages[messageIndex]; final user = m.role == 'user';
        return GestureDetector(onLongPress: () => showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Wrap(children: [
          ListTile(leading: const Icon(Icons.copy), title: const Text('Copy'), onTap: () { Clipboard.setData(ClipboardData(text: m.content)); Navigator.pop(context); }),
          if (user) ListTile(leading: const Icon(Icons.refresh), title: const Text('Regenerate'), onTap: () { Navigator.pop(context); state.sendMessage(m.chatId, m.content); }),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete message'), onTap: () { Navigator.pop(context); state.deleteMessage(m); }),
        ]))), child: Align(alignment: user ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14), constraints: const BoxConstraints(maxWidth: 340), decoration: BoxDecoration(color: user ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.content), if (state.termuxEnabled && !user && m.content.contains('`')) _CommandCard(text: m.content)]))));
      })),
      if (state.activeAttachment != null) ListTile(dense: true, leading: const Icon(Icons.attach_file), title: Text(state.activeAttachment!.split('/').last), trailing: IconButton(onPressed: () => state.activeAttachment = null, icon: const Icon(Icons.close))),
      SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 12), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [IconButton(onPressed: state.pickAttachment, icon: const Icon(Icons.attach_file)), Expanded(child: TextField(controller: input, minLines: 1, maxLines: 5, decoration: const InputDecoration(hintText: 'Message your local model'))), IconButton(onPressed: send, icon: Icon(sending ? Icons.hourglass_top : Icons.send))]))),
    ]),
  ));
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({required this.text}); final String text;
  @override Widget build(BuildContext context) { final command = RegExp(r'`([^`]+)`').firstMatch(text)?.group(1) ?? text; return Card(color: Colors.black, child: ListTile(leading: const Icon(Icons.terminal, color: Colors.greenAccent), title: Text(command, style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent)), trailing: FilledButton(onPressed: () async { final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Run this command?'), content: Text(command), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Run'))])); if (ok == true && context.mounted) await context.read<AppState>().executeTerminal(command, confirmed: true); }, child: const Text('Run')))); }
}

class ModelHubScreen extends StatefulWidget {
  const ModelHubScreen({super.key});
  @override State<ModelHubScreen> createState() => _ModelHubScreenState();
}

class _ModelHubScreenState extends State<ModelHubScreen> {
  final url = TextEditingController();
  double progress = 0;
  String? error;
  bool downloading = false;

  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Model Hub')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Bring your own model', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Import a local .gguf file or paste a direct download link. Models stay on-device.'),
          const SizedBox(height: 18),
          TextField(controller: url, decoration: const InputDecoration(labelText: 'Direct GGUF download URL', prefixIcon: Icon(Icons.link))),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.icon(
                onPressed: downloading
                    ? null
                    : () async {
                        setState(() => error = null);
                        try {
                          await context.read<AppState>().addModelFromFile();
                        } catch (e) {
                          if (mounted) setState(() => error = 'Could not import model: $e');
                        }
                      },
                icon: const Icon(Icons.folder_open),
                label: const Text('Import file'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: downloading
                    ? null
                    : () async {
                        setState(() {
                          error = null;
                          progress = 0;
                          downloading = true;
                        });
                        try {
                          await context.read<AppState>().addModelFromLink(url.text, (value) {
                            if (mounted) setState(() => progress = value);
                          });
                        } catch (e) {
                          if (mounted) setState(() => error = 'Could not download model: $e');
                        } finally {
                          if (mounted) setState(() => downloading = false);
                        }
                      },
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            ],
          ),
          if (progress > 0 && progress < 1) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator(value: progress)),
          if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const Divider(height: 32),
          Text('Supported platforms', style: Theme.of(context).textTheme.titleLarge),
          for (final item in const [
            ('Hugging Face', 'Discover GGUF quantizations from the community', 'https://huggingface.co/models?search=gguf'),
            ('TheBloke archives', 'Browse popular llama.cpp-ready model releases', 'https://huggingface.co/TheBloke'),
          ])
            Card(
              child: ListTile(
                leading: const Icon(Icons.public),
                title: Text(item.$1),
                subtitle: Text(item.$2),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => launchExternal(item.$3),
              ),
            ),
          const SizedBox(height: 12),
          for (final model in state.models)
            ListTile(
              leading: Icon(model.id == state.activeModelId ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(model.name),
              subtitle: Text(model.path),
              onTap: () => state.selectModel(model),
              trailing: IconButton(onPressed: () => state.deleteModel(model), icon: const Icon(Icons.delete_outline)),
            ),
        ],
      ),
    );
  }
}

Future<void> launchExternal(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (_, state, __) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Local connection', style: Theme.of(context).textTheme.titleLarge),
            ListTile(leading: const Icon(Icons.lan), title: const Text('llama-server endpoint'), subtitle: Text(state.llama.endpoint), onTap: () => _endpointDialog(context, state)),
            if (state.models.isNotEmpty)
              DropdownButtonFormField<int>(
                value: state.activeModelId,
                decoration: const InputDecoration(labelText: 'Active GGUF model'),
                items: [for (final model in state.models) DropdownMenuItem(value: model.id, child: Text(model.name, overflow: TextOverflow.ellipsis))],
                onChanged: (id) {
                  if (id != null) state.selectModel(state.models.firstWhere((model) => model.id == id));
                },
              ),
            const Divider(),
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            SwitchListTile(title: const Text('Dark theme'), value: state.darkMode, onChanged: state.setDarkMode),
            const Divider(),
            Text('Advanced — Optional', style: Theme.of(context).textTheme.titleLarge),
            SwitchListTile(title: const Text('Termux Integration'), subtitle: const Text('Allows confirmed commands to be sent to Termux:API. Off by default.'), value: state.termuxEnabled, onChanged: state.setTermux),
            ListTile(leading: const Icon(Icons.history), title: const Text('Terminal history'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TerminalHistoryScreen()))),
            const Divider(),
            Text('MCP Servers', style: Theme.of(context).textTheme.titleLarge),
            const Text('Only explicitly added server URLs are allowed. Adding a URL does not connect or trust it.'),
            ListTile(leading: const Icon(Icons.add_link), title: const Text('Add an allowlisted server'), onTap: () => _mcpDialog(context, state)),
            for (final server in state.mcpServers)
              ListTile(
                dense: true,
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(server['name'] as String),
                subtitle: Text(server['url'] as String),
                trailing: IconButton(onPressed: () => state.deleteMcpServer(server['id'] as int), icon: const Icon(Icons.delete_outline)),
              ),
            const SizedBox(height: 20),
            const AboutListTile(applicationName: 'Open LLM', applicationVersion: '1.0.0', applicationLegalese: 'Offline-first. No accounts. No analytics.', aboutBoxChildren: [Text('Open LLM runs quantized language models locally through llama.cpp.')]),
          ],
        ),
      ),
    );
  }
}
Future<void> _endpointDialog(BuildContext context, AppState state) async { final c = TextEditingController(text: state.llama.endpoint); String? error; await showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, setState) => AlertDialog(title: const Text('Local endpoint'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: c, decoration: const InputDecoration(hintText: 'http://127.0.0.1:8080')), if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () async { if (await state.setEndpoint(c.text)) { if (context.mounted) Navigator.pop(context); } else { setState(() => error = 'Use an http localhost endpoint only.'); } }, child: const Text('Save'))]))); c.dispose(); }
Future<void> _mcpDialog(BuildContext context, AppState state) async { final n = TextEditingController(); final u = TextEditingController(); await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Add MCP server'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'Name')), TextField(controller: u, decoration: const InputDecoration(labelText: 'https://…'))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { if (n.text.isNotEmpty && u.text.startsWith('https://')) state.addMcpServer(n.text, u.text); Navigator.pop(context); }, child: const Text('Allowlist'))])); }

class TerminalHistoryScreen extends StatelessWidget {
  const TerminalHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (_, state, __) => Scaffold(
        appBar: AppBar(title: const Text('Terminal history')),
        body: state.terminalEntries.isEmpty
            ? const Center(child: Text('No commands have been run.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.terminalEntries.length,
                itemBuilder: (_, i) {
                  final entry = state.terminalEntries[i];
                  return ListTile(
                    leading: Icon(entry.success ? Icons.check_circle : Icons.error, color: entry.success ? Colors.green : Colors.red),
                    title: Text(entry.command, style: const TextStyle(fontFamily: 'monospace')),
                    subtitle: Text(DateFormat.yMMMd().add_jm().format(entry.createdAt)),
                  );
                },
              ),
      ),
    );
  }
}