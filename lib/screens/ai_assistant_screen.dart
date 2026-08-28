import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_date.dart';
import '../core/app_theme.dart';
import '../db/chat_storage.dart';
import '../models/chat.dart';
import '../models/file_attachment.dart';
import '../providers/auth_provider.dart';
import '../providers/gemini_service.dart';
import '../services/study_context.dart';
import '../widgets/common.dart';

/// Chat with the study assistant.
///
/// Sessions are stored in the database (they used to live only in memory and
/// vanished on restart), and the assistant is given the student's real course
/// and task list as context.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const _suggestions = [
    'What should I work on today?',
    'Break my next assignment into steps',
    'Quiz me on my upcoming exam topics',
    'Draft a revision plan for this week',
  ];

  final _gemini = GeminiService();
  final _scrollController = ScrollController();
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();

  final List<ChatMessage> _messages = [];
  final List<FileAttachment> _attachments = [];

  List<ChatSession> _sessions = [];
  int? _openSessionId;
  bool _sending = false;
  bool _useStudyContext = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessions());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    _gemini.dispose();
    super.dispose();
  }

  int get _userId => context.read<AuthProvider>().userId;

  /// Title of the session currently loaded, or null for an unsaved chat.
  String? get _openSessionTitle {
    final id = _openSessionId;
    if (id == null) return null;
    for (final session in _sessions) {
      if (session.id == id) return session.title;
    }
    return null;
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await loadChatSessions(_userId);
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } catch (e) {
      debugPrint('Could not load chat sessions: $e');
    }
  }

  // -------------------------------------------------------------- sending

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _inputCtrl.text).trim();
    if (text.isEmpty || _sending) return;

    final userMessage = ChatMessage(
      role: 'user',
      content: text,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _messages.add(userMessage);
      _inputCtrl.clear();
      _sending = true;
    });
    _scrollToBottom();

    try {
      final studyContext = _useStudyContext
          ? await StudyContextBuilder.build(_userId)
          : null;

      final reply = await _gemini.getReply(
        messages: _messages,
        attachments: List.of(_attachments),
        studyContext: studyContext,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            content: reply,
            createdAtMillis: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        _attachments.clear();
        _sending = false;
      });
      _scrollToBottom();
      await _autoSave();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);

      final message = e is GeminiException ? e.message : 'Unexpected error: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'Retry', onPressed: () => _send(text)),
        ),
      );

      // Drop the message that failed so a retry does not duplicate it.
      setState(() {
        if (_messages.isNotEmpty && _messages.last.isUser) _messages.removeLast();
      });
    }
  }

  /// Keeps the open session in sync after each exchange.
  Future<void> _autoSave() async {
    final id = _openSessionId;
    if (id == null || _messages.isEmpty) return;

    try {
      await updateChatSession(sessionId: id, messages: _messages);
      await _loadSessions();
    } catch (e) {
      debugPrint('Could not autosave the session: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  // ----------------------------------------------------------- attachments

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'pdf', 'txt', 'md', 'csv', 'doc', 'docx', 'ppt', 'pptx',
          'xls', 'xlsx', 'jpg', 'jpeg', 'png', 'gif',
        ],
      );

      final picked = result?.files.single;
      final path = picked?.path;
      if (path == null) return;

      final file = File(path);
      if (!await file.exists()) {
        _snack('That file no longer exists.');
        return;
      }

      final attachment = FileAttachment(
        fileName: picked!.name,
        filePath: path,
        file: file,
        fileType: picked.name.split('.').last.toLowerCase(),
      );

      if (attachment.fileSizeBytes > 10 * 1024 * 1024) {
        _snack('Files must be smaller than 10 MB.');
        return;
      }
      if (!attachment.isSupportedType()) {
        _snack('That file type is not supported.');
        return;
      }
      if (!await attachment.isReadable()) {
        _snack('That file could not be read.');
        return;
      }

      if (!mounted) return;
      setState(() => _attachments.add(attachment));
    } catch (e) {
      _snack('Could not attach the file: $e');
    }
  }

  // -------------------------------------------------------------- sessions

  Future<void> _saveSessionAs() async {
    if (_messages.isEmpty) {
      _snack('There is nothing to save yet.');
      return;
    }

    final firstLine = _messages.first.content.split('\n').first;
    final suggested = firstLine.length > 40
        ? '${firstLine.substring(0, 40)}…'
        : firstLine;

    final title = await _promptForTitle(initial: suggested);
    if (title == null) return;

    try {
      final id = await saveChatSession(
        userId: _userId,
        title: title,
        messages: _messages,
      );
      if (!mounted) return;
      setState(() => _openSessionId = id);
      await _loadSessions();
      _snack('Saved "$title"');
    } catch (e) {
      _snack('Could not save the chat: $e');
    }
  }

  Future<String?> _promptForTitle({required String initial}) async {
    final ctrl = TextEditingController(text: initial);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save chat'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    ctrl.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  Future<void> _openSession(ChatSession session) async {
    try {
      final messages = await loadChatMessages(session.id!);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _openSessionId = session.id;
        _attachments.clear();
      });
      Navigator.of(context).pop();
      _scrollToBottom();
    } catch (e) {
      _snack('Could not open that chat: $e');
    }
  }

  Future<void> _deleteSession(ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chat'),
        content: Text('Delete "${session.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.high),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await deleteChatSession(session.id!);
    if (!mounted) return;
    if (_openSessionId == session.id) {
      setState(() => _openSessionId = null);
    }
    await _loadSessions();
  }

  void _newChat() {
    setState(() {
      _messages.clear();
      _attachments.clear();
      _openSessionId = null;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------------- ui

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Study assistant',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              _openSessionTitle ?? 'Unsaved chat',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _messages.isEmpty ? null : _newChat,
          ),
          IconButton(
            tooltip: 'Save chat',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _messages.isEmpty ? null : _saveSessionAs,
          ),
        ],
      ),
      endDrawer: _historyDrawer(),
      body: Column(
        children: [
          if (!_gemini.isConfigured) _missingKeyBanner(),
          Expanded(
            child: _messages.isEmpty ? _welcome() : _messageList(),
          ),
          if (_attachments.isNotEmpty) _attachmentBar(),
          if (_sending) _typingIndicator(),
          _composer(),
        ],
      ),
    );
  }

  Widget _missingKeyBanner() {
    return Container(
      width: double.infinity,
      color: AppTheme.medium.withValues(alpha: 0.14),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.key_off, size: 18, color: AppTheme.medium),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'No Gemini API key. Add GEMINI_API_KEY to .env and restart to '
              'use the assistant.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcome() {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.smart_toy, size: 32, color: scheme.primary),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Ask about your coursework',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'The assistant can see your courses and open tasks.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 22),
        ..._suggestions.map(
          (s) => AppTile(
            onTap: () => _send(s),
            child: Row(
              children: [
                Icon(Icons.bolt, size: 18, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(s)),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _messageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) => _bubble(_messages[i]),
    );
  }

  Widget _bubble(ChatMessage message) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: message.content));
              _snack('Message copied');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.content,
                    style: TextStyle(
                      color: isUser ? scheme.onPrimary : scheme.onSurface,
                      fontSize: 14.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppDate.formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser
                          ? scheme.onPrimary.withValues(alpha: 0.75)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typingIndicator() {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            height: 12,
            width: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Thinking…',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _attachmentBar() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      color: scheme.primary.withValues(alpha: 0.06),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(_attachments.length, (i) {
          final attachment = _attachments[i];
          return Chip(
            avatar: Icon(attachment.getFileIcon(), size: 16),
            label: Text(
              '${attachment.fileName} • ${attachment.getFormattedFileSize()}',
              style: const TextStyle(fontSize: 11),
            ),
            onDeleted: () => setState(() => _attachments.removeAt(i)),
            deleteIcon: const Icon(Icons.close, size: 16),
          );
        }),
      ),
    );
  }

  Widget _composer() {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                Tooltip(
                  message: _useStudyContext
                      ? 'The assistant can see your courses and tasks'
                      : 'The assistant answers without your data',
                  child: FilterChip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      _useStudyContext
                          ? Icons.auto_awesome
                          : Icons.auto_awesome_outlined,
                      size: 15,
                    ),
                    label: const Text(
                      'My courses',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: _useStudyContext,
                    onSelected: (v) => setState(() => _useStudyContext = v),
                  ),
                ),
                const Spacer(),
                Builder(
                  builder: (ctx) => TextButton.icon(
                    onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                    icon: const Icon(Icons.history, size: 16),
                    label: Text(
                      'History (${_sessions.length})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _sending ? null : _pickFile,
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'Attach a file',
                ),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    focusNode: _inputFocus,
                    enabled: !_sending,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Ask about a course, task or topic…',
                      fillColor: scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'ai-send',
                  onPressed: _sending ? null : () => _send(),
                  child: const Icon(Icons.send, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyDrawer() {
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Saved chats',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'New chat',
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      _newChat();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _sessions.isEmpty
                  ? const EmptyState(
                      icon: Icons.forum_outlined,
                      title: 'No saved chats',
                      message:
                          'Use the bookmark button to keep a conversation.',
                    )
                  : ListView.builder(
                      itemCount: _sessions.length,
                      itemBuilder: (ctx, i) {
                        final session = _sessions[i];
                        final isOpen = session.id == _openSessionId;

                        return ListTile(
                          selected: isOpen,
                          leading: Icon(
                            isOpen
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            size: 20,
                          ),
                          title: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            AppDate.formatDateTime(session.updatedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          onTap: () => _openSession(session),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _deleteSession(session),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
