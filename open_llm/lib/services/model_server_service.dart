import 'package:flutter/services.dart';

import '../models/device_models.dart';

class ModelServerService {
  static const _channel = MethodChannel('open_llm/model_server');

  Future<bool> start({
    required String modelPath,
    required DeviceCapabilities capabilities,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('start', {
            'modelPath': modelPath,
            'threads': capabilities.threads,
            'contextSize': capabilities.tier.contextTokens,
            'endpoint': 'http://127.0.0.1:8080',
          }) ??
          false;
    } on Exception {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on Exception {
      // The server is optional; a manually managed local server remains valid.
    }
  }
}