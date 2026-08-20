import 'dart:convert';
import 'package:http/http.dart' as http;

class LlamaService {
  String endpoint;
  LlamaService({this.endpoint = 'http://127.0.0.1:8080'});

  Stream<String> chat({required List<Map<String, String>> messages, double temperature = 0.7}) async* {
    final request = http.Request('POST', Uri.parse('$endpoint/v1/chat/completions'));
    request.headers['content-type'] = 'application/json';
    request.body = jsonEncode({'messages': messages, 'stream': true, 'temperature': temperature});
    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('llama-server returned ${response.statusCode}');
    }
    await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data == '[DONE]') break;
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final token = (json['choices'] as List).first['delta']['content'];
        if (token is String) yield token;
      } catch (_) {}
    }
  }
}