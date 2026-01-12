import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:unimate/providers/gemini_service.dart';
import 'dart:io';
import '../models/file_attachment.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  late final GeminiService _openai = GeminiService();

  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final List<FileAttachment> _attachments = [];
  bool _loading = false;

  // in-memory chat session history
  final List<List<Map<String, String>>> _sessions = [];
  final List<String> _sessionTitles = [];
  final TextEditingController _sessionTitleController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _sessionTitleController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add({"role": "user", "content": text});
      _controller.clear();
      _loading = true;
    });

    try {
      final reply = await _openai.getReply(
        messages: _messages,
        attachments: _attachments.isNotEmpty ? _attachments : null,
      );
      setState(() {
        _messages.add({"role": "assistant", "content": reply});
        _attachments.clear(); // Clear attachments after sending
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        type: FileType.custom,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final fileExtension = fileName.split('.').last.toLowerCase();

        final file = File(filePath);

        // Check file size (max 10MB)
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File size must be less than 10MB')),
            );
          }
          return;
        }

        final attachment = FileAttachment(
          fileName: fileName,
          filePath: filePath,
          file: file,
          fileType: fileExtension,
        );

        setState(() {
          _attachments.add(attachment);
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('File attached: $fileName')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  void _saveSession() {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No messages to save')));
      return;
    }

    final title = _sessionTitleController.text.trim().isEmpty
        ? 'Chat ${_sessions.length + 1}'
        : _sessionTitleController.text.trim();

    // Deep copy messages
    final copied = _messages.map((m) => Map<String, String>.from(m)).toList();
    setState(() {
      _sessions.add(copied);
      _sessionTitles.add(title);
      _sessionTitleController.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Session saved')));
  }

  void _loadSession(int index) {
    setState(() {
      _messages
        ..clear()
        ..addAll(_sessions[index].map((m) => Map<String, String>.from(m)));
    });
    Navigator.of(context).pop();
  }

  void _deleteSession(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text('This will remove the saved chat session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _sessions.removeAt(index);
                _sessionTitles.removeAt(index);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Study Assistant')),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'Chat History',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: TextField(
                  controller: _sessionTitleController,
                  decoration: const InputDecoration(
                    hintText: 'Session title (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveSession,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Current'),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: _sessions.isEmpty
                    ? const Center(child: Text('No saved sessions'))
                    : ListView.builder(
                        itemCount: _sessions.length,
                        itemBuilder: (ctx, i) {
                          final title = _sessionTitles[i];
                          // show a small preview: first user message
                          String preview = '';
                          for (final m in _sessions[i]) {
                            if (m['role'] == 'user' &&
                                (m['content'] ?? '').isNotEmpty) {
                              preview = m['content'] ?? '';
                              break;
                            }
                          }
                          return ListTile(
                            title: Text(title),
                            subtitle: preview.isNotEmpty
                                ? Text(
                                    preview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () => _loadSession(i),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteSession(i),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final m = _messages[i];
                final isUser = m["role"] == "user";
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isUser
                          ? Colors.blue.shade100
                          : Colors.grey.shade200,
                    ),
                    child: Text(m["content"] ?? ''),
                  ),
                );
              },
            ),
          ),
          // Display attached files
          if (_attachments.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.blue.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attached Files:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_attachments.length, (index) {
                      final attachment = _attachments[index];
                      return Chip(
                        label: Text(
                          attachment.fileName,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onDeleted: () => _removeAttachment(index),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        backgroundColor: Colors.blue.shade100,
                      );
                    }),
                  ),
                ],
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('AI is typing...'),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'Attach file',
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText:
                          'Ask about your course, tasks, or study tips...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
