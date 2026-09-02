import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../db/resource_storage.dart';
import '../db/task_storage.dart';
import '../models/course.dart';
import '../models/resource.dart';
import '../models/task.dart';
import '../providers/data_refresh.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';
import '../widgets/task_tile.dart';
import 'phone_frame.dart';
import 'task_form_screen.dart';

enum TaskFilter { all, pending, completed, overdue, today, thisWeek }

enum TaskSortField { dueDate, priority, title, type }

enum ResourceTypeFilter { all, note, link, file }

enum ResourceSortField { title, type }

/// Tasks and resources for a single course.
class CourseDetailsScreen extends StatefulWidget {
  const CourseDetailsScreen({super.key, required this.course});

  final Course course;

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<Task> _tasks = [];
  List<Resource> _resources = [];
  bool _loading = true;
  String? _error;

  TaskFilter _taskFilter = TaskFilter.all;
  TaskSortField _taskSort = TaskSortField.dueDate;
  bool _taskAsc = true;
  final _taskSearchCtrl = TextEditingController();
  String _taskQuery = '';

  ResourceTypeFilter _resourceTypeFilter = ResourceTypeFilter.all;
  ResourceSortField _resourceSort = ResourceSortField.title;
  bool _resourceAsc = true;

  Color get _accent => AppTheme.courseColor(
    widget.course.colorValue,
    seedIndex: widget.course.id ?? 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _taskSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final id = widget.course.id;
    if (id == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tasks = await loadTasksByCourse(id);
      final resources = await loadResourcesByCourse(id);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _resources = resources;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _notifyChanged() {
    if (mounted) context.read<DataRefresh>().bump();
  }

  // ---------------------------------------------------------------- tasks

  Future<void> _openTaskForm({Task? task}) async {
    final id = widget.course.id;
    if (id == null) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          courseId: id,
          existingTask: task,
          courseCode: widget.course.code,
        ),
      ),
    );

    if (saved == true) {
      await _loadAll();
      _notifyChanged();
    }
  }

  Future<void> _toggleComplete(Task task, bool value) async {
    final id = task.id;
    if (id == null) return;

    await setTaskCompleted(id, value);

    // A finished task should stop nagging; an un-finished one gets its
    // reminder back.
    if (value) {
      await NotificationService.instance.cancelForTask(id);
    } else {
      final refreshed = await loadTaskById(id);
      if (refreshed != null) {
        await NotificationService.instance.scheduleForTask(
          refreshed,
          courseCode: widget.course.code,
        );
      }
    }

    await _loadAll();
    _notifyChanged();
  }

  /// Deletes immediately and offers Undo instead of asking first — the
  /// less-interruptive pattern now that tasks can be swiped away.
  Future<void> _deleteTask(Task task) async {
    final id = task.id;
    if (id == null) return;

    await deleteTaskById(id);
    await NotificationService.instance.cancelForTask(id);
    await _loadAll();
    _notifyChanged();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${task.title}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _restoreTask(task),
          ),
        ),
      );
  }

  /// Re-inserts a just-deleted task (with a fresh id) and re-arms its reminder.
  Future<void> _restoreTask(Task task) async {
    final newId = await insertTask(
      Task(
        courseId: task.courseId,
        title: task.title,
        type: task.type,
        dueDateMillis: task.dueDateMillis,
        priority: task.priority,
        isCompleted: task.isCompleted,
        notes: task.notes,
        reminderMinutesBefore: task.reminderMinutesBefore,
        completedAtMillis: task.completedAtMillis,
      ),
    );
    await NotificationService.instance.scheduleForTask(
      task.copyWith(id: newId),
      courseCode: widget.course.code,
    );
    await _loadAll();
    _notifyChanged();
  }

  List<Task> _visibleTasks() {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final query = _taskQuery.trim().toLowerCase();

    final filtered = _tasks.where((t) {
      final due = t.dueDate;
      final completed = t.completed;

      final matchesFilter = switch (_taskFilter) {
        TaskFilter.all => true,
        TaskFilter.pending => !completed,
        TaskFilter.completed => completed,
        TaskFilter.overdue => !completed && due.isBefore(now),
        TaskFilter.today =>
          !completed &&
              due.year == now.year &&
              due.month == now.month &&
              due.day == now.day,
        TaskFilter.thisWeek =>
          !completed && !due.isBefore(weekStart) && due.isBefore(weekEnd),
      };

      final matchesQuery =
          query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          t.notes.toLowerCase().contains(query) ||
          t.type.toLowerCase().contains(query);

      return matchesFilter && matchesQuery;
    }).toList();

    int rank(String p) => switch (p) {
      'High' => 0,
      'Medium' => 1,
      'Low' => 2,
      _ => 9,
    };
    int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

    filtered.sort((a, b) {
      final res = switch (_taskSort) {
        TaskSortField.dueDate => a.dueDateMillis.compareTo(b.dueDateMillis),
        TaskSortField.priority => rank(a.priority).compareTo(rank(b.priority)),
        TaskSortField.title => cmp(a.title, b.title),
        TaskSortField.type => cmp(a.type, b.type),
      };
      return _taskAsc ? res : -res;
    });

    return filtered;
  }

  // ------------------------------------------------------------ resources

  Future<void> _openResourceDialog({Resource? existing}) async {
    final id = widget.course.id;
    if (id == null) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ResourceDialog(courseId: id, existing: existing),
    );

    if (saved == true) {
      await _loadAll();
      _notifyChanged();
    }
  }

  Future<void> _deleteResource(Resource resource) async {
    final id = resource.id;
    if (id == null) return;

    final confirmed = await _confirm(
      title: 'Delete resource',
      message: 'Delete "${resource.title}"?',
    );
    if (!confirmed) return;

    await deleteResourceById(id);
    await _loadAll();
    _notifyChanged();
  }

  /// Opens a link in the browser, a file in its default app, or shows a note.
  Future<void> _openResource(Resource resource) async {
    switch (resource.type) {
      case 'Link':
        await _openLink(resource.value);
        break;
      case 'File':
        await _openStoredFile(resource.value);
        break;
      default:
        await _showNote(resource);
    }
  }

  Future<void> _openLink(String rawUrl) async {
    final normalised = rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl';
    final uri = Uri.tryParse(normalised);

    if (uri == null) {
      _snack('That does not look like a valid link.');
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) _snack('No app can open $normalised');
    } catch (e) {
      _snack('Could not open the link: $e');
    }
  }

  Future<void> _openStoredFile(String path) async {
    if (!File(path).existsSync()) {
      _snack('The file is no longer at $path');
      return;
    }

    try {
      final result = await OpenFile.open(path);
      if (result.type != ResultType.done) {
        _snack(result.message);
      }
    } catch (e) {
      _snack('Could not open the file: $e');
    }
  }

  Future<void> _showNote(Resource resource) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(resource.title),
        content: SingleChildScrollView(child: SelectableText(resource.value)),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: resource.value));
              Navigator.pop(ctx);
              _snack('Note copied');
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Resource> _visibleResources() {
    bool matchesType(Resource r) => switch (_resourceTypeFilter) {
      ResourceTypeFilter.all => true,
      ResourceTypeFilter.note => r.type == 'Note',
      ResourceTypeFilter.link => r.type == 'Link',
      ResourceTypeFilter.file => r.type == 'File',
    };

    final filtered = _resources.where(matchesType).toList();
    int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

    filtered.sort((a, b) {
      final res = switch (_resourceSort) {
        ResourceSortField.title => cmp(a.title, b.title),
        ResourceSortField.type => cmp(a.type, b.type),
      };
      return _resourceAsc ? res : -res;
    });

    return filtered;
  }

  // ----------------------------------------------------------------- ui

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final scheme = Theme.of(context).colorScheme;
    final pending = _tasks.where((t) => !t.completed).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${course.code} • ${course.instructor}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accent,
        onPressed: () => _tabController.index == 0
            ? _openTaskForm()
            : _openResourceDialog(),
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Task' : 'Resource'),
      ),
      body: SafeArea(
        child: PhoneFrame(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TabBar(
                controller: _tabController,
                labelColor: _accent,
                unselectedLabelColor: scheme.onSurfaceVariant,
                indicatorColor: _accent,
                tabs: [
                  Tab(text: 'Tasks ($pending open)'),
                  Tab(text: 'Resources (${_resources.length})'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? EmptyState(
                        icon: Icons.error_outline,
                        title: 'Could not load this course',
                        message: _error,
                        action: FilledButton(
                          onPressed: _loadAll,
                          child: const Text('Try again'),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [_tasksTab(), _resourcesTab()],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tasksTab() {
    final visible = _visibleTasks();

    return Column(
      children: [
        SizedBox(
          height: 42,
          child: TextField(
            controller: _taskSearchCtrl,
            onChanged: (v) => setState(() => _taskQuery = v),
            decoration: compactDecoration(
              context,
              hint: 'Search tasks…',
              icon: Icons.search,
              suffix: _taskQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _taskSearchCtrl.clear();
                        setState(() => _taskQuery = '');
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _taskControls(),
        const SizedBox(height: 12),
        Expanded(
          child: _tasks.isEmpty
              ? EmptyState(
                  icon: Icons.task_alt,
                  title: 'No tasks yet',
                  message: 'Add assignments, exams and projects for this course.',
                  action: FilledButton.icon(
                    onPressed: () => _openTaskForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add task'),
                  ),
                )
              : visible.isEmpty
              ? const EmptyState(
                  icon: Icons.filter_alt_off,
                  title: 'No tasks match',
                  message: 'Adjust the filter or search to see more.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: visible.length,
                  itemBuilder: (ctx, i) {
                    final task = visible[i];
                    return TaskTile(
                      task: task,
                      course: widget.course,
                      onToggle: (v) => _toggleComplete(task, v),
                      onTap: () => _openTaskForm(task: task),
                      onDelete: () => _deleteTask(task),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _resourcesTab() {
    final visible = _visibleResources();

    return Column(
      children: [
        _resourceControls(),
        const SizedBox(height: 12),
        Expanded(
          child: _resources.isEmpty
              ? EmptyState(
                  icon: Icons.folder_open,
                  title: 'No resources yet',
                  message:
                      'Keep notes, lecture links and files for this course in '
                      'one place.',
                  action: FilledButton.icon(
                    onPressed: () => _openResourceDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add resource'),
                  ),
                )
              : visible.isEmpty
              ? const EmptyState(
                  icon: Icons.filter_alt_off,
                  title: 'No resources match',
                  message: 'Adjust the type filter to see more.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: visible.length,
                  itemBuilder: (ctx, i) => _resourceTile(visible[i]),
                ),
        ),
      ],
    );
  }

  Widget _resourceTile(Resource resource) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = switch (resource.type) {
      'Link' => resource.value,
      'File' => resource.value.split(Platform.pathSeparator).last,
      _ => resource.value.replaceAll('\n', ' '),
    };

    return AppTile(
      accent: _accent,
      onTap: () => _openResource(resource),
      child: Row(
        children: [
          Icon(_resourceIcon(resource.type), color: _accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Resource actions',
            onSelected: (v) {
              switch (v) {
                case 'open':
                  _openResource(resource);
                case 'edit':
                  _openResourceDialog(existing: resource);
                case 'copy':
                  Clipboard.setData(ClipboardData(text: resource.value));
                  _snack('Copied to clipboard');
                case 'delete':
                  _deleteResource(resource);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'open', child: Text('Open')),
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'copy', child: Text('Copy value')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  IconData _resourceIcon(String type) => switch (type) {
    'Link' => Icons.link,
    'File' => Icons.insert_drive_file_outlined,
    _ => Icons.sticky_note_2_outlined,
  };

  Widget _taskControls() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: DropdownButtonFormField<TaskFilter>(
              initialValue: _taskFilter,
              isExpanded: true,
              decoration: compactDecoration(
                context,
                hint: 'Filter',
                icon: Icons.filter_list,
              ),
              items: const [
                DropdownMenuItem(value: TaskFilter.all, child: Text('All')),
                DropdownMenuItem(
                  value: TaskFilter.pending,
                  child: Text('Pending'),
                ),
                DropdownMenuItem(
                  value: TaskFilter.completed,
                  child: Text('Completed'),
                ),
                DropdownMenuItem(
                  value: TaskFilter.overdue,
                  child: Text('Overdue'),
                ),
                DropdownMenuItem(value: TaskFilter.today, child: Text('Today')),
                DropdownMenuItem(
                  value: TaskFilter.thisWeek,
                  child: Text('This week'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _taskFilter = v ?? TaskFilter.all),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 42,
            child: DropdownButtonFormField<TaskSortField>(
              initialValue: _taskSort,
              isExpanded: true,
              decoration: compactDecoration(
                context,
                hint: 'Sort',
                icon: Icons.sort,
              ),
              items: const [
                DropdownMenuItem(
                  value: TaskSortField.dueDate,
                  child: Text('Due date'),
                ),
                DropdownMenuItem(
                  value: TaskSortField.priority,
                  child: Text('Priority'),
                ),
                DropdownMenuItem(
                  value: TaskSortField.title,
                  child: Text('Title'),
                ),
                DropdownMenuItem(
                  value: TaskSortField.type,
                  child: Text('Type'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _taskSort = v ?? TaskSortField.dueDate),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SquareIconButton(
          tooltip: _taskAsc ? 'Ascending' : 'Descending',
          icon: _taskAsc ? Icons.arrow_upward : Icons.arrow_downward,
          onTap: () => setState(() => _taskAsc = !_taskAsc),
        ),
        const SizedBox(width: 10),
        SquareIconButton(
          tooltip: 'Reset',
          icon: Icons.restart_alt,
          onTap: () {
            _taskSearchCtrl.clear();
            setState(() {
              _taskQuery = '';
              _taskFilter = TaskFilter.all;
              _taskSort = TaskSortField.dueDate;
              _taskAsc = true;
            });
          },
        ),
      ],
    );
  }

  Widget _resourceControls() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: DropdownButtonFormField<ResourceTypeFilter>(
              initialValue: _resourceTypeFilter,
              isExpanded: true,
              decoration: compactDecoration(
                context,
                hint: 'Type',
                icon: Icons.filter_list,
              ),
              items: const [
                DropdownMenuItem(
                  value: ResourceTypeFilter.all,
                  child: Text('All'),
                ),
                DropdownMenuItem(
                  value: ResourceTypeFilter.note,
                  child: Text('Note'),
                ),
                DropdownMenuItem(
                  value: ResourceTypeFilter.link,
                  child: Text('Link'),
                ),
                DropdownMenuItem(
                  value: ResourceTypeFilter.file,
                  child: Text('File'),
                ),
              ],
              onChanged: (v) => setState(
                () => _resourceTypeFilter = v ?? ResourceTypeFilter.all,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 42,
            child: DropdownButtonFormField<ResourceSortField>(
              initialValue: _resourceSort,
              isExpanded: true,
              decoration: compactDecoration(
                context,
                hint: 'Sort',
                icon: Icons.sort,
              ),
              items: const [
                DropdownMenuItem(
                  value: ResourceSortField.title,
                  child: Text('Title'),
                ),
                DropdownMenuItem(
                  value: ResourceSortField.type,
                  child: Text('Type'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _resourceSort = v ?? ResourceSortField.title),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SquareIconButton(
          tooltip: _resourceAsc ? 'Ascending' : 'Descending',
          icon: _resourceAsc ? Icons.arrow_upward : Icons.arrow_downward,
          onTap: () => setState(() => _resourceAsc = !_resourceAsc),
        ),
        const SizedBox(width: 10),
        SquareIconButton(
          tooltip: 'Reset',
          icon: Icons.restart_alt,
          onTap: () => setState(() {
            _resourceTypeFilter = ResourceTypeFilter.all;
            _resourceSort = ResourceSortField.title;
            _resourceAsc = true;
          }),
        ),
      ],
    );
  }
}

/// Add/edit resource. Owns its state, and can pick a real file from disk.
class _ResourceDialog extends StatefulWidget {
  const _ResourceDialog({required this.courseId, this.existing});

  final int courseId;
  final Resource? existing;

  @override
  State<_ResourceDialog> createState() => _ResourceDialogState();
}

class _ResourceDialogState extends State<_ResourceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  String _type = 'Note';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleCtrl.text = existing.title;
      _valueCtrl.text = existing.value;
      _type = existing.type;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      final path = result?.files.single.path;
      if (path == null || !mounted) return;

      setState(() {
        _valueCtrl.text = path;
        if (_titleCtrl.text.trim().isEmpty) {
          _titleCtrl.text = result!.files.single.name;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pick a file: $e')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    try {
      final title = _titleCtrl.text.trim();
      final value = _valueCtrl.text.trim();
      final existing = widget.existing;

      if (existing == null) {
        await insertResource(
          Resource(
            courseId: widget.courseId,
            title: title,
            type: _type,
            value: value,
          ),
        );
      } else {
        await updateResource(
          existing.copyWith(title: title, type: _type, value: value),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNote = _type == 'Note';
    final isFile = _type == 'File';

    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add resource' : 'Edit resource',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'Note', child: Text('Note')),
                  DropdownMenuItem(value: 'Link', child: Text('Link')),
                  DropdownMenuItem(value: 'File', child: Text('File')),
                ],
                // Rebuilds the dialog itself, so the value field below really
                // does change with the type.
                onChanged: (v) => setState(() => _type = v ?? 'Note'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _valueCtrl,
                minLines: isNote ? 3 : 1,
                maxLines: isNote ? 6 : 1,
                readOnly: isFile,
                onTap: isFile ? _pickFile : null,
                decoration: InputDecoration(
                  labelText: isNote
                      ? 'Note content'
                      : isFile
                      ? 'File'
                      : 'URL',
                  hintText: isFile
                      ? 'Tap to choose a file'
                      : _type == 'Link'
                      ? 'https://…'
                      : null,
                  suffixIcon: isFile
                      ? IconButton(
                          icon: const Icon(Icons.folder_open),
                          tooltip: 'Choose file',
                          onPressed: _pickFile,
                        )
                      : null,
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) {
                    return isFile ? 'Choose a file' : 'This field is required';
                  }
                  if (_type == 'Link') {
                    final uri = Uri.tryParse(
                      value.startsWith('http') ? value : 'https://$value',
                    );
                    if (uri == null || uri.host.isEmpty) {
                      return 'Enter a valid URL';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
