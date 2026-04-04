import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:unimate/providers/gemini_service.dart';
import 'dart:io';
import 'dart:math';
import '../models/file_attachment.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

// AI Assistant screen with chat interface
// allowing users to ask questions about their courses and tasks
// and attach relevant files for context
// Uses GeminiService to get AI-generated replies
// Can Save and load chat sessions
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with TickerProviderStateMixin {
  late final GeminiService _openai = GeminiService();
  late final ScrollController _scrollController = ScrollController();

  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final List<FileAttachment> _attachments = [];
  bool _loading = false;

  // in-memory chat session history
  final List<List<Map<String, dynamic>>> _sessions = [];
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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add({
        "role": "user",
        "content": text,
        "timestamp": DateTime.now(),
      });
      _controller.clear();
      _loading = true;
    });

    _scrollToBottom();

    try {
      // Convert messages to API format (string keys and values only)
      final messagesForApi = _messages
          .map(
            (m) => {
              "role": m["role"] as String,
              "content": m["content"] as String,
            },
          )
          .toList();

      final reply = await _openai.getReply(
        messages: messagesForApi,
        attachments: _attachments.isNotEmpty ? _attachments : null,
      );
      setState(() {
        _messages.add({
          "role": "assistant",
          "content": reply,
          "timestamp": DateTime.now(),
        });
        _attachments.clear(); // Clear attachments after sending
      });
      _scrollToBottom();
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

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowedExtensions: [
          'pdf',
          'txt',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'jpg',
          'jpeg',
          'png',
          'gif',
          'mp3',
          'mp4',
          'wav',
          'avi',
        ],
        type: FileType.custom,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final file = File(filePath);

        // Check if file exists and is readable
        if (!await file.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File does not exist')),
            );
          }
          return;
        }

        final attachment = FileAttachment(
          fileName: fileName,
          filePath: filePath,
          file: file,
          fileType: fileName.split('.').last.toLowerCase(),
        );

        // Check file size (max 10MB)
        if (attachment.fileSizeBytes > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File size must be less than 10MB')),
            );
          }
          return;
        }

        // Check if supported type
        if (!attachment.isSupportedType()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unsupported file type')),
            );
          }
          return;
        }

        // Check if readable
        if (!await attachment.isReadable()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File is not readable or corrupted'),
              ),
            );
          }
          return;
        }

        setState(() {
          _attachments.add(attachment);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File attached: $fileName (${attachment.getFormattedFileSize()})',
              ),
            ),
          );
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
    final copied = _messages.map((m) => Map<String, dynamic>.from(m)).toList();
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
        ..addAll(_sessions[index].map((m) => Map<String, dynamic>.from(m)));
    });
    _scrollToBottom();
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

  Widget _buildAnimatedTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('AI is typing', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          ...List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(milliseconds: 600 + (index * 200)),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: (sin(value * 3.14159 * 2) + 1) / 2,
                    child: child,
                  );
                },
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    int index,
    Map<String, dynamic> message,
    bool isUser,
  ) {
    final content = message["content"] ?? '';
    final timestamp = message["timestamp"] as DateTime?;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(
              parent: AlwaysStoppedAnimation(1.0),
              curve: Curves.elasticOut,
            ),
          ),
          child: GestureDetector(
            onLongPress: () {
              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(100, 100, 0, 0),
                items: [
                  PopupMenuItem(
                    child: const Text('Copy'),
                    onTap: () {
                      final data = ClipboardData(text: content);
                      Clipboard.setData(data);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Message copied!'),
                          duration: Duration(milliseconds: 800),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                color: isUser ? Colors.blue.shade400 : Colors.grey.shade300,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: isUser ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Study Assistant'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat',
            onPressed: _messages.isEmpty
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear all messages?'),
                        content: const Text(
                          'This will remove all current messages.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _messages.clear());
                              Navigator.pop(ctx);
                            },
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
          ),
        ],
      ),
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
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final m = _messages[i];
                      final isUser = m["role"] == "user";
                      return _buildMessageBubble(i, m, isUser);
                    },
                  ),
          ),
          // Display attached files
          if (_attachments.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(top: BorderSide(color: Colors.blue.shade200)),
              ),
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
                        avatar: Icon(
                          attachment.getFileIcon(),
                          size: 18,
                          color: Colors.blue.shade700,
                        ),
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attachment.fileName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              attachment.getFormattedFileSize(),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        onDeleted: () => _removeAttachment(index),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        backgroundColor: Colors.blue.shade50,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          if (_loading) _buildAnimatedTypingIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: _loading ? null : _pickFile,
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'Attach file',
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_loading,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText:
                          'Ask about your course, tasks, or study tips...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  mini: true,
                  onPressed: _loading ? null : _send,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
