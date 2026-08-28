import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/chat.dart';
import '../models/file_attachment.dart';

/// Raised for anything the chat screen should show to the user.
class GeminiException implements Exception {
  final String message;

  const GeminiException(this.message);

  @override
  String toString() => message;
}

/// Thin Gemini client.
///
/// Improvements over the first version:
/// * real multi-turn `contents` instead of one flattened string,
/// * images and PDFs are uploaded as `inlineData` so the model can actually
///   read them rather than being told a file exists,
/// * a system instruction that carries the student's own courses and tasks,
/// * request timeout and readable error messages.
class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoint = 'https://generativelanguage.googleapis.com/v1beta';
  static const _timeout = Duration(seconds: 60);

  /// Inline uploads share the request body, so keep well under the API limit.
  static const _maxInlineBytes = 6 * 1024 * 1024;

  String get apiKey => dotenv.env['GEMINI_API_KEY']?.trim() ?? '';

  bool get isConfigured => apiKey.isNotEmpty;

  Future<String> getReply({
    required List<ChatMessage> messages,
    String model = 'gemini-2.5-flash',
    List<FileAttachment> attachments = const [],
    String? studyContext,
  }) async {
    if (!isConfigured) {
      throw const GeminiException(
        'No Gemini API key found. Add GEMINI_API_KEY to the .env file and '
        'restart the app.',
      );
    }
    if (messages.isEmpty) {
      throw const GeminiException('Nothing to send.');
    }

    final contents = <Map<String, Object?>>[];
    for (final message in messages) {
      contents.add({
        'role': message.isUser ? 'user' : 'model',
        'parts': [
          {'text': message.content},
        ],
      });
    }

    // Attachments ride along with the most recent user turn.
    if (attachments.isNotEmpty && contents.isNotEmpty) {
      final parts = (contents.last['parts'] as List).cast<Map<String, Object?>>();
      parts.addAll(await _attachmentParts(attachments));
    }

    final body = <String, Object?>{
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt(studyContext)},
        ],
      },
      'contents': contents,
      'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 2048},
    };

    late http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_endpoint/models/$model:generateContent'),
            headers: {
              'x-goog-api-key': apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (e) {
      throw GeminiException(
        'Could not reach Gemini. Check your connection and try again.\n($e)',
      );
    }

    if (response.statusCode != 200) {
      throw GeminiException(_errorMessage(response));
    }

    return _extractText(response.body);
  }

  /// Reads text files directly and uploads images/PDFs as base64 so the model
  /// can inspect their contents.
  Future<List<Map<String, Object?>>> _attachmentParts(
    List<FileAttachment> attachments,
  ) async {
    final parts = <Map<String, Object?>>[];
    var inlineBudget = _maxInlineBytes;

    for (final attachment in attachments) {
      final ext = attachment.fileType.toLowerCase();
      final inlineTypes = {'pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp'};

      try {
        if (ext == 'txt' || ext == 'md' || ext == 'csv') {
          final text = await attachment.file.readAsString();
          parts.add({
            'text':
                'Attached file "${attachment.fileName}":\n'
                '${text.length > 20000 ? '${text.substring(0, 20000)}\n…(truncated)' : text}',
          });
          continue;
        }

        if (inlineTypes.contains(ext)) {
          final bytes = await attachment.file.readAsBytes();
          if (bytes.length > inlineBudget) {
            parts.add({
              'text':
                  'Attached "${attachment.fileName}" '
                  '(${attachment.getFormattedFileSize()}) is too large to '
                  'upload; the student may describe it instead.',
            });
            continue;
          }
          inlineBudget -= bytes.length;
          parts.add({
            'inlineData': {
              'mimeType': attachment.getMimeType(),
              'data': base64Encode(bytes),
            },
          });
          continue;
        }

        // Formats Gemini cannot read inline: describe them.
        parts.add({
          'text':
              'The student attached "${attachment.fileName}" '
              '(${attachment.fileType}, ${attachment.getFormattedFileSize()}). '
              'Its contents cannot be read directly — ask for the relevant '
              'text if you need it.',
        });
      } catch (e) {
        debugPrint('Could not attach ${attachment.fileName}: $e');
        parts.add({
          'text': 'Attached "${attachment.fileName}" could not be read.',
        });
      }
    }

    return parts;
  }

  String _systemPrompt(String? studyContext) {
    final buffer = StringBuffer()
      ..writeln(
        'You are UniMate, a study assistant inside a university planner app.',
      )
      ..writeln(
        'Help the student plan work, understand course material, and prepare '
        'for assessments.',
      )
      ..writeln('Be concise and practical. Use short paragraphs or bullets.')
      ..writeln(
        'When the student asks what to work on, reason from the course and '
        'task list below: prefer what is overdue, then what is due soonest '
        'and highest priority.',
      )
      ..writeln(
        'Never invent courses, deadlines or grades that are not listed.',
      );

    if (studyContext != null && studyContext.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln("The student's current workload:")
        ..writeln(studyContext.trim());
    }

    return buffer.toString();
  }

  String _errorMessage(http.Response response) {
    String detail = response.body;
    try {
      final decoded = jsonDecode(response.body);
      detail = (decoded is Map && decoded['error'] is Map)
          ? '${decoded['error']['message']}'
          : response.body;
    } catch (_) {
      // Keep the raw body.
    }

    return switch (response.statusCode) {
      400 => 'Gemini rejected the request: $detail',
      401 || 403 => 'The Gemini API key was rejected. Check GEMINI_API_KEY.',
      429 => 'Rate limit reached. Wait a moment and try again.',
      >= 500 => 'Gemini is unavailable right now. Try again shortly.',
      _ => 'Gemini error ${response.statusCode}: $detail',
    };
  }

  String _extractText(String responseBody) {
    final json = jsonDecode(responseBody);
    final candidates = (json['candidates'] as List?) ?? const [];

    if (candidates.isEmpty) {
      final blocked = json['promptFeedback']?['blockReason'];
      if (blocked != null) {
        throw GeminiException('The request was blocked ($blocked).');
      }
      throw const GeminiException('Gemini returned no answer.');
    }

    final parts = (candidates.first['content']?['parts'] as List?) ?? const [];
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['text'] is String) buffer.write(part['text']);
    }

    final text = buffer.toString().trim();
    if (text.isEmpty) {
      final reason = candidates.first['finishReason'];
      throw GeminiException(
        reason == null
            ? 'Gemini returned an empty answer.'
            : 'Gemini stopped early ($reason).',
      );
    }
    return text;
  }

  void dispose() => _client.close();
}
