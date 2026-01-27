import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:unimate/models/file_attachment.dart';

class GeminiService {
  final String apiKey;

  GeminiService() : apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  Future<String> getReply({
    required List<Map<String, String>> messages,
    String model = 'gemini-2.5-flash',
    List<FileAttachment>? attachments,
  }) async {
    if (apiKey.trim().isEmpty) {
      return 'Gemini API key is empty.';
    }

    // Build a single prompt string
    final prompt = messages
        .map((m) {
          final role = m["role"] ?? "user";
          final content = m["content"] ?? "";
          return '$role: $content';
        })
        .join('\n');

    var finalPrompt = prompt;

    // Attachments handling
    // - Read .txt content
    // - For others, just list them
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

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final body = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": finalPrompt},
          ],
        },
      ],
    };

    final res = await http.post(
      uri,
      headers: {'x-goog-api-key': apiKey, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Gemini error ${res.statusCode}: ${res.body}');
    }

    final json = jsonDecode(res.body);

    final candidates = (json['candidates'] as List?) ?? [];
    if (candidates.isEmpty) return '(No candidates returned)';

    final content = candidates.first['content'];
    final parts = (content?['parts'] as List?) ?? [];

    final buffer = StringBuffer();
    for (final p in parts) {
      if (p is Map && p['text'] is String) {
        buffer.write(p['text']);
      }
    }

    final text = buffer.toString().trim();
    return text.isEmpty ? '(No text returned)' : text;
  }
}
