import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:unimate/screens/phone_frame.dart';
import '../models/course.dart';
import '../models/task.dart';
import '../models/resource.dart';
import '../db/task_storage.dart';
import '../db/resource_storage.dart';
import 'task_form_screen.dart';

class CourseDetailsScreen extends StatefulWidget {
  const CourseDetailsScreen({super.key, required this.course});
  final Course course;

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen>
    with SingleTickerProviderStateMixin {
  static const blue = Color(0xFF2563EB);

  late TabController _tabController;

  List<Task> _tasks = [];
  List<Resource> _resources = [];

  final _resTitleCtrl = TextEditingController();
  final _resValueCtrl = TextEditingController();
  String _resType = 'Note';
  String? _pickedFilePath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _resTitleCtrl.dispose();
    _resValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (widget.course.id == null) return;
    _tasks = await loadTasksByCourse(widget.course.id!);
    _resources = await loadResourcesByCourse(widget.course.id!);
    if (mounted) setState(() {});
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'High':
        return const Color(0xFFDC2626);
      case 'Low':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Future<void> _openAddTask() async {
    if (widget.course.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TaskFormScreen(courseId: widget.course.id!, existingTask: null),
      ),
    );
    await _loadAll();
  }

  Future<void> _openEditTask(Task task) async {
    if (widget.course.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TaskFormScreen(courseId: widget.course.id!, existingTask: task),
      ),
    );
    await _loadAll();
  }

  Future<void> _toggleComplete(Task t, bool v) async {
    if (t.id == null) return;
    await setTaskCompleted(t.id!, v);
    await _loadAll();
  }

  void _confirmDeleteTask(Task t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${t.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (t.id == null) return;
              await deleteTaskById(t.id!);
              await _loadAll();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openResourceDialog({Resource? existing}) {
    if (existing == null) {
      _resTitleCtrl.clear();
      _resValueCtrl.clear();
      _resType = 'Note';
      _pickedFilePath = null;
    } else {
      _resTitleCtrl.text = existing.title;
      _resType = existing.type;
      if (existing.type == 'File') {
        _pickedFilePath = existing.value;
        _resValueCtrl.text = p.basename(existing.value);
      } else {
        _resValueCtrl.text = existing.value;
        _pickedFilePath = null;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Resource' : 'Edit Resource'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _resTitleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _resType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'Note', child: Text('Note')),
                DropdownMenuItem(value: 'Link', child: Text('Link')),
                DropdownMenuItem(value: 'File', child: Text('File')),
              ],
              onChanged: (v) => setState(() => _resType = v ?? 'Note'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _resValueCtrl,
              maxLines: _resType == 'Note' ? 3 : 1,
              decoration: InputDecoration(
                labelText: _resType == 'Link'
                    ? 'URL'
                    : _resType == 'File'
                    ? 'File Path'
                    : 'Note Content',
              ),
            ),
            if (_resType == 'File')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Tip: paste a local file path (simple version)',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (widget.course.id == null) return;

              final title = _resTitleCtrl.text.trim();
              final value = _resValueCtrl.text.trim();
              if (title.isEmpty || value.isEmpty) return;

              if (existing == null) {
                await insertResource(
                  Resource(
                    courseId: widget.course.id!,
                    title: title,
                    type: _resType,
                    value: value,
                  ),
                );
              } else {
                if (existing.id == null) return;
                await updateResource(
                  existing.copyWith(title: title, type: _resType, value: value),
                );
              }

              if (mounted) Navigator.pop(ctx);
              await _loadAll();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteResource(Resource r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Resource'),
        content: Text('Delete "${r.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (r.id == null) return;
              await deleteResourceById(r.id!);
              await _loadAll();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _resIcon(String type) {
    switch (type) {
      case 'Link':
        return Icons.link;
      case 'File':
        return Icons.picture_as_pdf;
      default:
        return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _openAddTask();
          } else {
            _openResourceDialog();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: PhoneFrame(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              c.code,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),

            TabBar(
              controller: _tabController,
              labelColor: blue,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: blue,
              tabs: const [
                Tab(text: 'Tasks'),
                Tab(text: 'Resources'),
              ],
            ),
            const SizedBox(height: 10),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // TASKS
                  _tasks.isEmpty
                      ? Center(
                          child: Text(
                            'No tasks yet.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _tasks.length,
                          itemBuilder: (ctx, i) {
                            final t = _tasks[i];
                            final due = DateTime.fromMillisecondsSinceEpoch(
                              t.dueDateMillis,
                            );
                            final completed = t.isCompleted == 1;
                            final pColor = _priorityColor(t.priority);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: completed,
                                    onChanged: (v) =>
                                        _toggleComplete(t, v ?? false),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _openEditTask(t),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              decoration: completed
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${t.type} • Due ${due.month}/${due.day}',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: pColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      t.priority,
                                      style: TextStyle(
                                        color: pColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _confirmDeleteTask(t),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                  // RESOURCES
                  Column(
                    children: [
                      Expanded(
                        child: _resources.isEmpty
                            ? Center(
                                child: Text(
                                  'No resources yet.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _resources.length,
                                itemBuilder: (ctx, i) {
                                  final r = _resources[i];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(_resIcon(r.type), color: blue),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                r.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                r.type,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () =>
                                              _openResourceDialog(existing: r),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () =>
                                              _confirmDeleteResource(r),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
