import 'device_models.dart';

class CatalogModel {
  const CatalogModel({
    required this.id,
    required this.name,
    required this.filename,
    required this.downloadUrl,
    required this.tier,
    required this.approximateSizeBytes,
    required this.minimumRamBytes,
    required this.description,
    this.sha256,
  });

  final String id;
  final String name;
  final String filename;
  final String downloadUrl;
  final DeviceTier tier;
  final int approximateSizeBytes;
  final int minimumRamBytes;
  final String description;
  final String? sha256;

  String get sizeLabel {
    final gb = approximateSizeBytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(gb >= 10 ? 0 : 1)} GB';
  }

  String get ramLabel {
    final gb = minimumRamBytes / (1024 * 1024 * 1024);
    return '~${gb.toStringAsFixed(gb >= 10 ? 0 : 0)} GB RAM';
  }
}

/// Curated, direct Hugging Face resolve URLs. The catalog is bundled and is
/// never fetched from a remote catalog API.
const curatedModels = <CatalogModel>[
  CatalogModel(
    id: 'tinyllama-1.1b-q4km',
    name: 'TinyLlama 1.1B Chat',
    filename: 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    downloadUrl:
        'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf?download=true',
    tier: DeviceTier.low,
    approximateSizeBytes: 670 * 1024 * 1024,
    minimumRamBytes: 3 * 1024 * 1024 * 1024,
    description: 'Fast, lightweight, and good for quick chats.',
  ),
  CatalogModel(
    id: 'qwen2.5-1.5b-q4km',
    name: 'Qwen2.5 1.5B Instruct',
    filename: 'Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
    downloadUrl:
        'https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf?download=true',
    tier: DeviceTier.low,
    approximateSizeBytes: 1 * 1024 * 1024 * 1024,
    minimumRamBytes: 3 * 1024 * 1024 * 1024,
    description: 'Compact instruction model with strong everyday answers.',
  ),
  CatalogModel(
    id: 'gemma-2-2b-q4km',
    name: 'Gemma 2 2B IT',
    filename: 'gemma-2-2b-it-Q4_K_M.gguf',
    downloadUrl:
        'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf?download=true',
    tier: DeviceTier.mid,
    approximateSizeBytes: 1600 * 1024 * 1024,
    minimumRamBytes: 4 * 1024 * 1024 * 1024,
    description: 'Balanced quality for general-purpose local conversations.',
  ),
  CatalogModel(
    id: 'phi-3-mini-4b-q4km',
    name: 'Phi-3 Mini 4K 4B',
    filename: 'Phi-3-mini-4k-instruct-Q4_K_M.gguf',
    downloadUrl:
        'https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf?download=true',
    tier: DeviceTier.mid,
    approximateSizeBytes: 2400 * 1024 * 1024,
    minimumRamBytes: 6 * 1024 * 1024 * 1024,
    description: 'Smarter but slower, with good instruction following.',
  ),
  CatalogModel(
    id: 'mistral-7b-q4km',
    name: 'Mistral 7B Instruct',
    filename: 'mistral-7b-instruct-v0.2.Q4_K_M.gguf',
    downloadUrl:
        'https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/mistral-7b-instruct-v0.2.Q4_K_M.gguf?download=true',
    tier: DeviceTier.high,
    approximateSizeBytes: 4400 * 1024 * 1024,
    minimumRamBytes: 8 * 1024 * 1024 * 1024,
    description: 'High-quality answers with a larger memory footprint.',
  ),
  CatalogModel(
    id: 'llama-3.1-8b-q4km',
    name: 'Llama 3.1 8B Instruct',
    filename: 'Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf',
    downloadUrl:
        'https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf?download=true',
    tier: DeviceTier.high,
    approximateSizeBytes: 4900 * 1024 * 1024,
    minimumRamBytes: 8 * 1024 * 1024 * 1024,
    description: 'Capable, nuanced responses; best on high-memory devices.',
  ),
];