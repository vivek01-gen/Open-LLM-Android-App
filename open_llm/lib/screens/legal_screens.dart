import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalScaffold(
        title: 'Privacy Policy',
        sections: [
          LegalSection(
            title: 'What we collect',
            body:
                'Open LLM does not send analytics, account data, crash reports, advertising identifiers, prompts, responses, or model files anywhere. There is no cloud sync or telemetry.',
          ),
          LegalSection(
            title: 'What stays on this device',
            body:
                'The app stores chat history, imported model files, preferences, the device capability tier, optional MCP allowlist entries, and optional terminal history in the app-private storage area. This data is not written to public shared storage.',
          ),
          LegalSection(
            title: 'Permissions',
            body:
                'The file picker is used only when you choose a model or attachment. Model downloads are saved to app-private storage. Optional Termux access is used only for commands you explicitly approve. Optional biometric access is used only when you enable App Lock.',
          ),
          LegalSection(
            title: 'Your control',
            body:
                'You can turn off optional features and use Clear All Data in Settings to delete chats, model files, preferences, allowlists, and local history.',
          ),
        ],
      );
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalScaffold(
        title: 'Terms & Disclaimer',
        sections: [
          LegalSection(
            title: 'AI-generated content',
            body:
                'Local models can be inaccurate, incomplete, biased, or unsafe. You are responsible for checking important information and deciding whether an answer is suitable for your situation.',
          ),
          LegalSection(
            title: 'Terminal feature',
            body:
                'The optional Termux feature can execute real commands on your device. You are responsible for reviewing and confirming every command. Open LLM never executes a command without an explicit per-command tap confirmation.',
          ),
          LegalSection(
            title: 'Third-party models',
            body:
                'Catalog models are downloaded from third-party Hugging Face repositories. Open LLM does not control or guarantee the files, licenses, safety, availability, or content produced by those models. Review the model repository license before use.',
          ),
          LegalSection(
            title: 'No warranty',
            body:
                'Use the app, downloaded models, and optional integrations at your own risk. Do not rely on generated content for medical, legal, financial, safety-critical, or security-critical decisions.',
          ),
        ],
      );
}

class PermissionsExplainerScreen extends StatelessWidget {
  const PermissionsExplainerScreen({super.key});

  @override
  Widget build(BuildContext context) => const LegalScaffold(
        title: 'Permissions explained',
        sections: [
          LegalSection(
            title: 'Storage and file access',
            body: 'Needed to save AI models on your device so chat works offline.',
          ),
          LegalSection(
            title: 'Termux (optional)',
            body:
                'Only if you enable Advanced terminal features — lets the AI run commands you approve, one at a time.',
          ),
          LegalSection(
            title: 'Biometric (optional)',
            body:
                'Only if you enable App Lock — protects your chats from others opening the app.',
          ),
        ],
      );
}

class OpenSourceLicensesScreen extends StatelessWidget {
  const OpenSourceLicensesScreen({super.key});

  @override
  Widget build(BuildContext context) => LicensePage(
        applicationName: 'Open LLM',
        applicationVersion: '1.0.0',
        applicationLegalese: 'Offline-first. No accounts. No analytics.',
      );
}

class LegalScaffold extends StatelessWidget {
  const LegalScaffold({required this.title, required this.sections, super.key});

  final String title;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            for (final section in sections)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(section.body),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

class LegalSection {
  const LegalSection({required this.title, required this.body});

  final String title;
  final String body;
}