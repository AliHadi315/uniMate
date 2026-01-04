import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:unimate/models/file_attachment.dart';

class OpenAIService {
  final String apiKey; 
  OpenAIService() : apiKey = dotenv.env['API_KEY'] ?? '';

  Future<String> getReply({
    required List<Map<String, String>> messages,
    String model = 'gpt-4.1-mini',
    List<FileAttachment>? attachments,
  }) async {
    if (apiKey.trim().isEmpty) {
      return 'OpenAI API key is empty.';
    }

    final prompt = messages
        .map((m) => '${m["role"]}: ${m["content"]}')
        .join('\n');
    var finalPrompt = prompt;

    // Attachments:
    // - .txt
    // - other types
    if (attachments != null && attachments.isNotEmpty) {
      finalPrompt += '\n\nAttached files:\n';
      for (final a in attachments) {
        if (a.fileType.toLowerCase() == 'txt') {
          try {
            final txt = await a.file.readAsString();
            finalPrompt += '\n- ${a.fileName} (txt content):\n${txt.trim()}\n';
          } catch (_) {
            finalPrompt += '\n- ${a.fileName} (txt) (could not read)\n';
          }
        } else {
          finalPrompt += '\n- ${a.fileName} (${a.fileType}) (not parsed)\n';
        }
      }
    }

    final uri = Uri.parse('https://api.openai.com/v1/responses');
    final body = {"model": model, "input": finalPrompt};

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('OpenAI error ${res.statusCode}: ${res.body}');
    }

    final json = jsonDecode(res.body);

    // Parse Responses API output_text
    final output = (json['output'] as List?) ?? [];
    final buffer = StringBuffer();

    for (final item in output) {
      final content = item['content'];
      if (content is List) {
        for (final c in content) {
          if (c is Map && c['type'] == 'output_text') {
            buffer.write(c['text'] ?? '');
          }
        }
      }
    }

    final text = buffer.toString().trim();
    return text.isEmpty ? '(No text returned)' : text;
  }
}
