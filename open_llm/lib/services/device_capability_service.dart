import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

import '../models/device_models.dart';

class DeviceCapabilityService {
  static const _channel = MethodChannel('open_llm/device');
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<DeviceCapabilities> scan() async {
    var ramBytes = 0;
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        final dynamic dynamicInfo = info;
        ramBytes = (dynamicInfo.physicalRamSize as int?) ?? 0;
      }
    } catch (_) {
      ramBytes = 0;
    }

    var freeStorageBytes = 0;
    try {
      freeStorageBytes =
          (await _channel.invokeMethod<int>('freeStorageBytes')) ?? 0;
    } catch (_) {
      freeStorageBytes = 0;
    }

    final cpuCores = Platform.numberOfProcessors;
    final ramGb = ramBytes / (1024 * 1024 * 1024);
    final tier = ramGb >= 8
        ? DeviceTier.high
        : ramGb >= 4
            ? DeviceTier.mid
            : DeviceTier.low;
    return DeviceCapabilities(
      tier: tier,
      ramBytes: ramBytes,
      cpuCores: cpuCores,
      freeStorageBytes: freeStorageBytes,
    );
  }
}