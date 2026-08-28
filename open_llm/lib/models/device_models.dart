enum DeviceTier {
  low(1, 'Tier 1 · Low', 2, 2048),
  mid(2, 'Tier 2 · Mid', 4, 4096),
  high(3, 'Tier 3 · High', 7, 8192);

  const DeviceTier(this.level, this.label, this.maxModelBillions, this.contextTokens);

  final int level;
  final String label;
  final int maxModelBillions;
  final int contextTokens;

  String get summary => switch (this) {
        DeviceTier.low => 'Your device supports models up to ~2B parameters comfortably.',
        DeviceTier.mid => 'Your device supports models up to ~4B parameters comfortably.',
        DeviceTier.high => 'Your device supports models up to ~7B parameters comfortably.',
      };

  static DeviceTier fromLevel(int? level) => switch (level) {
        3 => DeviceTier.high,
        2 => DeviceTier.mid,
        _ => DeviceTier.low,
      };
}

class DeviceCapabilities {
  const DeviceCapabilities({
    required this.tier,
    required this.ramBytes,
    required this.cpuCores,
    required this.freeStorageBytes,
  });

  final DeviceTier tier;
  final int ramBytes;
  final int cpuCores;
  final int freeStorageBytes;

  int get threads => cpuCores > 1 ? cpuCores - 1 : 1;

  String get ramLabel => _formatBytes(ramBytes);
  String get storageLabel => _formatBytes(freeStorageBytes);

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return 'Unknown';
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(gb >= 10 ? 0 : 1)} GB';
  }
}

class NetworkLogEntry {
  const NetworkLogEntry({
    required this.id,
    required this.method,
    required this.url,
    required this.statusCode,
    required this.createdAt,
  });

  final int id;
  final String method;
  final String url;
  final int? statusCode;
  final DateTime createdAt;
}