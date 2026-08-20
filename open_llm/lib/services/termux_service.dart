import 'package:flutter/services.dart';

class TermuxService {
  static const _channel = MethodChannel('open_llm/termux');
  Future<bool> runCommand(String command) async {
    try {
      return await _channel.invokeMethod<bool>('runCommand', {'command': command}) ?? false;
    } on PlatformException {
      return false;
    }
  }
}