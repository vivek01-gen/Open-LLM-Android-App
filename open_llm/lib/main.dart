import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/app_models.dart';
import 'models/device_models.dart';
import 'models/model_catalog.dart';
import 'screens/legal_screens.dart';
import 'services/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..load(),
      child: const OpenLlmApp(),
    ),
  );
}

class OpenLlmApp extends StatelessWidget {
  const OpenLlmApp({super.key});

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
        builder: (_, state, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Open LLM',
          theme: state.darkMode ? AppTheme.dark() : AppTheme.light(),
          home: !state.initialized
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              : state.appLocked
                  ? const LockScreen()
                  : state.onboardingComplete
                      ? const ShellScreen()
                      : const OnboardingScreen(),
        ),
      );
}

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline,
                      size: 72, color: Colors.lightBlueAccent),
                  const SizedBox(height: 20),
                  Text('Open LLM is locked',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  const Text(
                    'Authenticate to access your local chats and model files.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.read<AppState>().unlockApp(),
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int page = 0;
  bool privacyAgreed = false;
  bool termsAgreed = false;
  bool askTermux = false;

  Future<bool> _confirmPermission(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('$title permission'),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('I understand'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Welcome to Open LLM',
      'Privacy and terms',
      'Choose optional features',
    ];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Icon(
                page == 0
                    ? Icons.offline_bolt
                    : page == 1
                        ? Icons.shield_outlined
                        : Icons.tune,
                size: 64,
                color: Colors.lightBlueAccent,
              ),
              const SizedBox(height: 24),
              Text(
                titles[page],
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              if (page == 0)
                const Text(
                  'Private AI that lives with you. Run quantized GGUF models on your phone with no account, no cloud, and no telemetry.',
                ),
              if (page == 1)
                Expanded(
                  child: ListView(
                    children: [
                      const Text(
                        'Open LLM keeps chats, model files, and settings on this device. It does not send prompts, responses, analytics, or account data anywhere.',
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen()),
                        ),
                        icon: const Icon(Icons.policy_outlined),
                        label: const Text('Read the Privacy Policy'),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TermsScreen()),
                        ),
                        icon: const Icon(Icons.gavel_outlined),
                        label: const Text('Read Terms & Disclaimer'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: privacyAgreed,
                        onChanged: (value) =>
                            setState(() => privacyAgreed = value ?? false),
                        title: const Text('I agree to the Privacy Policy'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: termsAgreed,
                        onChanged: (value) =>
                            setState(() => termsAgreed = value ?? false),
                        title: const Text('I agree to the Terms & Disclaimer'),
                      ),
                    ],
                  ),
                ),
              if (page == 2)
                Expanded(
                  child: ListView(
                    children: [
                      const Text(
                        'Your device will be scanned after onboarding so the catalog can recommend models that fit its memory.',
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: askTermux,
                        onChanged: (value) async {
                          if (!value) {
                            setState(() => askTermux = false);
                            return;
                          }
                          final understood = await _confirmPermission(
                            'Termux',
                            'Only if you enable Advanced terminal features — lets the AI run commands you approve, one at a time.',
                          );
                          if (mounted && understood) {
                            setState(() => askTermux = true);
                          }
                        },
                        title: const Text('Advanced terminal features'),
                        subtitle: const Text(
                          'Optional. Every command still requires an explicit tap.',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PermissionsExplainerScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Explain permissions'),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  if (page > 0)
                    TextButton(
                      onPressed: () => setState(() => page--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: page == 1 && (!privacyAgreed || !termsAgreed)
                        ? null
                        : () async {
                            if (page < 2) {
                              setState(() => page++);
                            } else {
                              final state = context.read<AppState>();
                              await state.setPrivacyAgreed(privacyAgreed);
                              await state.setTermsAgreed(termsAgreed);
                              await state.setTermux(askTermux);
                              await state.finishOnboarding();
                            }
                          },
                    child: Text(page == 2 ? 'Start privately' : 'Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int tab = 0;
  final pages = const [HomeScreen(), ModelHubScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: tab, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Chats'),
            NavigationDestination(
                icon: Icon(Icons.download_outlined),
                selectedIcon: Icon(Icons.download),
                label: 'Model Hub'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings'),
          ],
        ),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
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
                      const Icon(Icons.memory,
                          size: 72, color: Colors.lightBlueAccent),
                      const SizedBox(height: 18),
                      Text('Your local AI space',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 10),
                      const Text(
                        'Choose a device-friendly GGUF model to start a private conversation.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ModelHubScreen()),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Choose a model'),
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
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TerminalHistoryScreen()),
                  ),
                  icon: const Icon(Icons.terminal),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Conversations',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                ...state.chats.map(
                  (chat) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.chat)),
                      title: Text(chat.title),
                      subtitle:
                          Text(DateFormat.yMMMd().format(chat.createdAt)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ChatScreen(chat: chat)),
                      ),
                    ),
                  ),
                ),
                if (state.chats.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Text('No conversations yet. Open a chat to begin.',
                        textAlign: TextAlign.center),
                  ),
                FilledButton.icon(
                  onPressed: () async {
                    final id = await state.ensureChat();
                    final chat =
                        state.chats.firstWhere((item) => item.id == id);
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ChatScreen(chat: chat)),
                      );
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

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chat});

  final Chat chat;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  bool sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<AppState>().openChat(widget.chat.id));
  }

  Future<void> send() async {
    final text = input.text.trim();
    final state = context.read<AppState>();
    if (text.isEmpty || sending || state.modelLoading) return;
    final attachment = state.activeAttachment;
    input.clear();
    state.activeAttachment = null;
    setState(() => sending = true);
    await state.sendMessage(widget.chat.id, text, attachmentPath: attachment);
    if (mounted) setState(() => sending = false);
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
        builder: (_, state, __) => Scaffold(
          appBar: AppBar(
            title: Text(widget.chat.title),
            actions: [
              Tooltip(
                  message: state.llama.endpoint,
                  child: const Icon(Icons.lan_outlined)),
              const SizedBox(width: 12),
            ],
          ),
          body: Column(
            children: [
              if (state.modelLoading || state.serverStatus.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      if (state.modelLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (state.modelLoading) const SizedBox(width: 10),
                      Expanded(child: Text(state.serverStatus)),
                    ],
                  ),
                ),
              Expanded(
                child: state.activeMessages.isEmpty
                    ? const Center(
                        child: Text('Ask your local model anything.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.activeMessages.length +
                            (state.activeMessages.length >= 100 ? 1 : 0),
                        itemBuilder: (_, index) {
                          if (state.activeMessages.length >= 100 &&
                              index == 0) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text('Showing the latest 100 messages.',
                                  textAlign: TextAlign.center),
                            );
                          }
                          final messageIndex =
                              state.activeMessages.length >= 100
                                  ? index - 1
                                  : index;
                          final message = state.activeMessages[messageIndex];
                          final user = message.role == 'user';
                          return GestureDetector(
                            onLongPress: () => showModalBottomSheet(
                              context: context,
                              builder: (_) => SafeArea(
                                child: Wrap(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.copy),
                                      title: const Text('Copy'),
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(
                                            text: message.content));
                                        Navigator.pop(context);
                                      },
                                    ),
                                    if (user)
                                      ListTile(
                                        leading: const Icon(Icons.refresh),
                                        title: const Text('Regenerate'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          state.sendMessage(
                                              message.chatId, message.content);
                                        },
                                      ),
                                    ListTile(
                                      leading:
                                          const Icon(Icons.delete_outline),
                                      title: const Text('Delete message'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        state.deleteMessage(message);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            child: Align(
                              alignment: user
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                constraints:
                                    const BoxConstraints(maxWidth: 340),
                                decoration: BoxDecoration(
                                  color: user
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(message.content),
                                    if (state.termuxEnabled &&
                                        !user &&
                                        message.content.contains('`'))
                                      _CommandCard(text: message.content),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (state.activeAttachment != null)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.attach_file),
                  title: Text(state.activeAttachment!.split('/').last),
                  trailing: IconButton(
                    onPressed: () => state.activeAttachment = null,
                    icon: const Icon(Icons.close),
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                          onPressed: state.modelLoading
                              ? null
                              : state.pickAttachment,
                          icon: const Icon(Icons.attach_file)),
                      Expanded(
                        child: TextField(
                          controller: input,
                          minLines: 1,
                          maxLines: 5,
                          enabled: !state.modelLoading,
                          decoration: const InputDecoration(
                              hintText: 'Message your local model'),
                        ),
                      ),
                      IconButton(
                          onPressed: send,
                          icon: Icon(sending
                              ? Icons.hourglass_top
                              : Icons.send)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final command =
        RegExp(r'`([^`]+)`').firstMatch(text)?.group(1) ?? text;
    return Card(
      color: Colors.black,
      child: ListTile(
        leading: const Icon(Icons.terminal, color: Colors.greenAccent),
        title: Text(command,
            style: const TextStyle(
                fontFamily: 'monospace', color: Colors.greenAccent)),
        trailing: FilledButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Run this command?'),
                content: Text(command),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Run')),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              await context
                  .read<AppState>()
                  .executeTerminal(command, confirmed: true);
            }
          },
          child: const Text('Run'),
        ),
      ),
    );
  }
}

class ModelHubScreen extends StatefulWidget {
  const ModelHubScreen({super.key});

  @override
  State<ModelHubScreen> createState() => _ModelHubScreenState();
}

class _ModelHubScreenState extends State<ModelHubScreen> {
  final url = TextEditingController();
  String? downloadingId;
  double progress = 0;
  int received = 0;
  int? total;
  String? error;

  @override
  void dispose() {
    url.dispose();
    super.dispose();
  }

  Future<void> _download(CatalogModel model) async {
    final state = context.read<AppState>();
    setState(() {
      downloadingId = model.id;
      progress = 0;
      received = 0;
      total = null;
      error = null;
    });
    try {
      final started = await state.downloadCatalogModel(model, (value, downloaded, size) {
        if (!mounted) return;
        setState(() {
          progress = value;
          received = downloaded;
          total = size;
        });
      });
      if (!mounted) return;
      final chatId = await state.ensureChat();
      final chat = state.chats.firstWhere((item) => item.id == chatId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(started
              ? 'Model installed. Ready to chat.'
              : 'Model installed. Start llama-server to begin chatting.'),
        ),
      );
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatScreen(chat: chat)));
    } catch (exception) {
      if (mounted) setState(() => error = '$exception');
    } finally {
      if (mounted) setState(() => downloadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final capabilities = state.deviceCapabilities;
    return Scaffold(
      appBar: AppBar(title: const Text('Model Hub')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Recommended for your device',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (capabilities != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.memory),
                title: Text(capabilities.tier.summary),
                subtitle: Text(
                    '${capabilities.tier.label} · ${capabilities.ramLabel} RAM · ${capabilities.cpuCores} CPU cores · ${capabilities.storageLabel} free'),
                trailing: IconButton(
                  tooltip: 'Rescan device',
                  onPressed: state.modelLoading ? null : state.scanDevice,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.showAllCatalogModels,
            onChanged: state.setShowAllCatalogModels,
            title: const Text('Show all models'),
            subtitle: const Text('May be slow or unstable on this device'),
          ),
          if (state.showAllCatalogModels)
            const Card(
              color: Color(0xFF4A3214),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                    'Warning: larger models can exhaust memory, heat the device, or make the app unstable.'),
              ),
            ),
          if (error != null)
            Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          for (final model in state.visibleCatalogModels)
            _CatalogCard(
              model: model,
              downloading: downloadingId == model.id,
              progress: progress,
              received: received,
              total: total,
              onDownload: () => _download(model),
              installed:
                  state.models.any((item) => item.name == model.name),
            ),
          const SizedBox(height: 8),
          const Divider(),
          ExpansionTile(
            leading: const Icon(Icons.tune),
            title: const Text('Add Custom Model'),
            subtitle: const Text('Advanced: import a file or paste a link'),
            children: [
              TextField(
                  controller: url,
                  decoration: const InputDecoration(
                      labelText: 'Direct GGUF download URL',
                      prefixIcon: Icon(Icons.link))),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: state.modelLoading
                        ? null
                        : () async {
                            setState(() => error = null);
                            try {
                              await state.addModelFromFile();
                            } catch (exception) {
                              if (mounted) {
                                setState(() => error =
                                    'Could not import model: $exception');
                              }
                            }
                          },
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Import file'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: state.modelLoading
                        ? null
                        : () async {
                            setState(() => error = null);
                            try {
                              await state.addModelFromLink(url.text, (value) {
                                if (mounted) setState(() => progress = value);
                              });
                            } catch (exception) {
                              if (mounted) {
                                setState(() => error =
                                    'Could not download model: $exception');
                              }
                            }
                          },
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Installed models',
              style: Theme.of(context).textTheme.titleLarge),
          for (final model in state.models)
            ListTile(
              leading: Icon(model.id == state.activeModelId
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(model.name),
              subtitle: Text(model.path),
              onTap: () => state.selectModel(model),
              trailing: IconButton(
                  onPressed: () => state.deleteModel(model),
                  icon: const Icon(Icons.delete_outline)),
            ),
          const SizedBox(height: 12),
          const Text(
              'Catalog links are bundled in the app. Downloads only begin after you tap a model.'),
        ],
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.model,
    required this.downloading,
    required this.progress,
    required this.received,
    required this.total,
    required this.onDownload,
    required this.installed,
  });

  final CatalogModel model;
  final bool downloading;
  final double progress;
  final int received;
  final int? total;
  final VoidCallback onDownload;
  final bool installed;

  String _size(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(model.name,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Chip(label: Text(model.tier.label.split(' · ').first)),
                ],
              ),
              Text('${model.sizeLabel} · ${model.ramLabel}'),
              const SizedBox(height: 6),
              Text(model.description),
              if (downloading) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                    value: total != null && total! > 0 ? progress : null),
                const SizedBox(height: 4),
                Text(total == null
                    ? '${_size(received)} downloaded'
                    : '${(progress * 100).toStringAsFixed(0)}% · ${_size(received)} / ${_size(total!)}'),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: downloading || installed ? null : onDownload,
                  icon: Icon(installed ? Icons.check : Icons.download),
                  label: Text(installed ? 'Installed' : 'Download & use'),
                ),
              ),
            ],
          ),
        ),
      );
}

Future<void> launchExternal(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<bool> _explain(BuildContext context, String title) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PermissionsExplainerScreen()),
    );
    return true;
  }

  Future<void> _clearData(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all local data?'),
        content: const Text(
            'This permanently deletes chats, downloaded model files, settings, allowlists, and terminal/network history. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete everything')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await state.clearAllData();
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
        builder: (_, state, __) => Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Device',
                  style: Theme.of(context).textTheme.titleLarge),
              if (state.deviceCapabilities != null)
                ListTile(
                  leading: const Icon(Icons.speed),
                  title: Text(state.deviceCapabilities!.tier.summary),
                  subtitle: Text(
                      '${state.deviceCapabilities!.ramLabel} RAM · ${state.deviceCapabilities!.cpuCores} cores · ${state.deviceCapabilities!.storageLabel} free'),
                  trailing: TextButton(
                      onPressed:
                          state.modelLoading ? null : state.scanDevice,
                      child: const Text('Rescan')),
                ),
              const Divider(),
              Text('Local connection',
                  style: Theme.of(context).textTheme.titleLarge),
              ListTile(
                  leading: const Icon(Icons.lan),
                  title: const Text('llama-server endpoint'),
                  subtitle: Text(state.llama.endpoint),
                  onTap: () => _endpointDialog(context, state)),
              if (state.models.isNotEmpty)
                DropdownButtonFormField<int>(
                  value: state.activeModelId,
                  decoration:
                      const InputDecoration(labelText: 'Active GGUF model'),
                  items: [
                    for (final model in state.models)
                      DropdownMenuItem(
                          value: model.id,
                          child: Text(model.name,
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (id) {
                    if (id != null) {
                      state.selectModel(
                          state.models.firstWhere((model) => model.id == id));
                    }
                  },
                ),
              const Divider(),
              Text('Appearance',
                  style: Theme.of(context).textTheme.titleLarge),
              SwitchListTile(
                title: const Text('Dark theme'),
                value: state.darkMode,
                onChanged: state.setDarkMode,
              ),
              const Divider(),
              Text('Privacy and security',
                  style: Theme.of(context).textTheme.titleLarge),
              SwitchListTile(
                title: const Text('App Lock'),
                subtitle:
                    const Text('Require device authentication to open chats.'),
                value: state.appLockEnabled,
                onChanged: (enabled) async {
                  if (!enabled) {
                    await state.disableAppLock();
                    return;
                  }
                  await _explain(context, 'Biometric');
                  if (!context.mounted) return;
                  final success = await state.enableAppLock();
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Biometric or device authentication is unavailable.')));
                  }
                },
              ),
              SwitchListTile(
                title: const Text('Network Activity Log'),
                subtitle: const Text('Keep the last 50 explicit network requests.'),
                value: state.networkActivityLogEnabled,
                onChanged: state.setNetworkActivityLog,
              ),
              if (state.networkActivityLogEnabled)
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text('View network activity'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NetworkActivityLogScreen()),
                  ),
                ),
              const Divider(),
              Text('Advanced — Optional',
                  style: Theme.of(context).textTheme.titleLarge),
              SwitchListTile(
                title: const Text('Termux Integration'),
                subtitle: const Text(
                    'Allows confirmed commands to be sent to Termux:API. Off by default.'),
                value: state.termuxEnabled,
                onChanged: (enabled) async {
                  if (!enabled) {
                    await state.setTermux(false);
                    return;
                  }
                  await _explain(context, 'Termux');
                  if (context.mounted) await state.setTermux(true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Terminal history'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TerminalHistoryScreen()),
                ),
              ),
              const Divider(),
              Text('MCP Servers',
                  style: Theme.of(context).textTheme.titleLarge),
              const Text(
                  'Only explicitly added server URLs are allowed. Adding a URL does not connect or trust it.'),
              ListTile(
                leading: const Icon(Icons.add_link),
                title: const Text('Add an allowlisted server'),
                onTap: () => _mcpDialog(context, state),
              ),
              for (final server in state.mcpServers)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(server['name'] as String),
                  subtitle: Text(server['url'] as String),
                  trailing: IconButton(
                    onPressed: () =>
                        state.deleteMcpServer(server['id'] as int),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              const Divider(),
              Text('About & Legal',
                  style: Theme.of(context).textTheme.titleLarge),
              ListTile(
                leading: const Icon(Icons.policy_outlined),
                title: const Text('Privacy Policy'),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('Terms & Disclaimer'),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TermsScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Permissions Explainer'),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PermissionsExplainerScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Open Source Licenses'),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OpenSourceLicensesScreen())),
              ),
              const ListTile(
                  leading: Icon(Icons.apps),
                  title: Text('Open LLM'),
                  subtitle: Text('Version 1.0.0')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _clearData(context, state),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Clear All Data'),
              ),
            ],
          ),
        ),
      );
}

Future<void> _endpointDialog(BuildContext context, AppState state) async {
  final controller = TextEditingController(text: state.llama.endpoint);
  String? error;
  await showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Local endpoint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: controller,
                decoration:
                    const InputDecoration(hintText: 'http://127.0.0.1:8080')),
            if (error != null)
              Text(error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (await state.setEndpoint(controller.text)) {
                if (context.mounted) Navigator.pop(context);
              } else {
                setState(() => error = 'Use an http localhost endpoint only.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}

Future<void> _mcpDialog(BuildContext context, AppState state) async {
  final name = TextEditingController();
  final url = TextEditingController();
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Add MCP server'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name')),
          TextField(
              controller: url,
              decoration: const InputDecoration(labelText: 'https://…')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            state.addMcpServer(name.text, url.text);
            Navigator.pop(context);
          },
          child: const Text('Allowlist'),
        ),
      ],
    ),
  );
  name.dispose();
  url.dispose();
}

class NetworkActivityLogScreen extends StatelessWidget {
  const NetworkActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
        builder: (_, state, __) => Scaffold(
          appBar: AppBar(title: const Text('Network activity')),
          body: state.networkLogs.isEmpty
              ? const Center(child: Text('No logged requests yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.networkLogs.length,
                  itemBuilder: (_, index) {
                    final entry = state.networkLogs[index];
                    return ListTile(
                      leading: Icon(
                        entry.statusCode != null &&
                                entry.statusCode! >= 200 &&
                                entry.statusCode! < 400
                            ? Icons.check_circle
                            : Icons.info_outline,
                        color: entry.statusCode != null &&
                                entry.statusCode! >= 200 &&
                                entry.statusCode! < 400
                            ? Colors.green
                            : Colors.orange,
                      ),
                      title: Text('${entry.method} ${entry.statusCode ?? '—'}'),
                      subtitle: Text(entry.url),
                      trailing: Text(DateFormat.Hm().format(entry.createdAt)),
                    );
                  },
                ),
        ),
      );
}

class TerminalHistoryScreen extends StatelessWidget {
  const TerminalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
        builder: (_, state, __) => Scaffold(
          appBar: AppBar(title: const Text('Terminal history')),
          body: state.terminalEntries.isEmpty
              ? const Center(child: Text('No commands have been run.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.terminalEntries.length,
                  itemBuilder: (_, index) {
                    final entry = state.terminalEntries[index];
                    return ListTile(
                      leading: Icon(
                          entry.success ? Icons.check_circle : Icons.error,
                          color: entry.success ? Colors.green : Colors.red),
                      title: Text(entry.command,
                          style: const TextStyle(fontFamily: 'monospace')),
                      subtitle: Text(
                          DateFormat.yMMMd().add_jm().format(entry.createdAt)),
                    );
                  },
                ),
        ),
      );
}