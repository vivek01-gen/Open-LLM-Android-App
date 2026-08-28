import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class LlamaException implements Exception {
  const LlamaException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LlamaService {
  String endpoint;
  LlamaService({
    this.endpoint = 'http://127.0.0.1:8080',
    this.onNetworkRequest,
  });

  final Future<void> Function(String method, String url, int? statusCode)?
      onNetworkRequest;

  Stream<String> chat({required List<Map<String, String>> messages, double temperature = 0.7}) async* {
    final uri = Uri.tryParse('$endpoint/v1/chat/completions');
    if (uri == null || !_isLoopback(uri)) {
      throw const LlamaException('The endpoint must point to localhost, 127.0.0.1, or ::1.');
    }
    final client = http.Client();
    var networkRequestRecorded = false;

    Future<void> recordNetworkRequest(int? statusCode) async {
      if (networkRequestRecorded) return;
      networkRequestRecorded = true;
      try {
        await onNetworkRequest?.call('POST', uri.toString(), statusCode);
      } catch (_) {
        // A local audit log must never make a local chat request fail.
      }
    }

    try {
      final request = http.Request('POST', uri);
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode({'messages': messages, 'stream': true, 'temperature': temperature});
      final response = await client.send(request).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw const LlamaException('The local server did not respond within 20 seconds.'),
      );
      await recordNetworkRequest(response.statusCode);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LlamaException('Local llama-server returned HTTP ${response.statusCode}.');
      }
      var sawDone = false;
      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data == '[DONE]') {
          sawDone = true;
          break;
        }
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'];
          if (choices is! List || choices.isEmpty) {
            throw const FormatException('Missing choices');
          }
          final delta = choices.first['delta'];
          final token = delta is Map<String, dynamic> ? delta['content'] : null;
          if (token is String) yield token;
        } on FormatException {
          throw const LlamaException('The local server sent a malformed streaming response.');
        } catch (_) {
          throw const LlamaException('The local server sent an unexpected streaming response.');
        }
    }
      if (!sawDone) {
        throw const LlamaException('The local server closed the stream before completing the response.');
      }
    } on LlamaException {
      await recordNetworkRequest(null);
      rethrow;
    } on http.ClientException {
      await recordNetworkRequest(null);
      throw const LlamaException('Could not connect to the local llama-server. Check that it is running.');
    } on SocketException {
      await recordNetworkRequest(null);
      throw const LlamaException('Could not connect to the local llama-server. Check that it is running.');
    } on TimeoutException {
      await recordNetworkRequest(null);
      throw const LlamaException('The local llama-server did not respond within 20 seconds.');
    } on FormatException {
      await recordNetworkRequest(null);
      throw const LlamaException('The local server returned invalid JSON.');
    } finally {
      client.close();
    }
  }

  static bool _isLoopback(Uri uri) =>
      uri.scheme == 'http' && (uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1');
}