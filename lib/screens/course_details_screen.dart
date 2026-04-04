import 'package:flutter/material.dart';
import 'package:unimate/screens/phone_frame.dart';
import '../models/course.dart';
import '../models/task.dart';
import '../models/resource.dart';
import '../db/task_storage.dart';
import '../db/resource_storage.dart';
import 'task_form_screen.dart';

// Course Details screen showing tasks and resources for a specific course
class CourseDetailsScreen extends StatefulWidget {
  const CourseDetailsScreen({super.key, required this.course});
  final Course course;

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

enum TaskFilter { all, pending, completed, overdue, today, thisWeek }

enum TaskSortField { dueDate, priority, title, type }

enum ResourceTypeFilter { all, note, link, file }

enum ResourceSortField { title, type }

class _CourseDetailsScreenState extends State<CourseDetailsScreen>
    with SingleTickerProviderStateMixin {
  static const blue = Color(0xFF2563EB);

  late TabController _tabController;

  List<Task> _tasks = [];
  List<Resource> _resources = [];

  // Resource dialog controllers
  final _resTitleCtrl = TextEditingController();
  final _resValueCtrl = TextEditingController();
  String _resType = 'Note';

  // ✅ Filter/Sort state
  TaskFilter _taskFilter = TaskFilter.all;
  TaskSortField _taskSort = TaskSortField.dueDate;
  bool _taskAsc = true;

  ResourceTypeFilter _resourceTypeFilter = ResourceTypeFilter.all;
  ResourceSortField _resourceSort = ResourceSortField.title;
  bool _resourceAsc = true;

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

  InputDecoration _compactDeco({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 18),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
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
        return const Color(0xFFF59E0B); // Medium
    }
  }

  int _priorityRank(String p) {
    // lower number = higher priority
    switch (p) {
      case 'High':
        return 0;
      case 'Medium':
        return 1;
      case 'Low':
        return 2;
      default:
        return 9;
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
    } else {
      _resTitleCtrl.text = existing.title;
      _resType = existing.type;
      _resValueCtrl.text = existing.value;
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

  // ✅ Visible Tasks (filter + sort only)
  List<Task> _visibleTasks() {
    final now = DateTime.now();

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    DateTime startOfWeek(DateTime d) => DateTime(
      d.year,
      d.month,
      d.day,
    ).subtract(Duration(days: d.weekday - 1));

    final weekStart = startOfWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 7));

    final filtered = _tasks.where((t) {
      final due = DateTime.fromMillisecondsSinceEpoch(t.dueDateMillis);
      final completed = t.isCompleted == 1;

      bool matchesFilter = true;
      switch (_taskFilter) {
        case TaskFilter.all:
          matchesFilter = true;
          break;
        case TaskFilter.pending:
          matchesFilter = !completed;
          break;
        case TaskFilter.completed:
          matchesFilter = completed;
          break;
        case TaskFilter.overdue:
          matchesFilter = !completed && due.isBefore(now);
          break;
        case TaskFilter.today:
          matchesFilter = isSameDay(due, now);
          break;
        case TaskFilter.thisWeek:
          matchesFilter =
              (due.isAtSameMomentAs(weekStart) || due.isAfter(weekStart)) &&
              due.isBefore(weekEnd);
          break;
      }

      return matchesFilter;
    }).toList();

    int cmpStr(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());

    filtered.sort((a, b) {
      int res = 0;
      switch (_taskSort) {
        case TaskSortField.dueDate:
          res = a.dueDateMillis.compareTo(b.dueDateMillis);
          break;
        case TaskSortField.priority:
          res = _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
          break;
        case TaskSortField.title:
          res = cmpStr(a.title, b.title);
          break;
        case TaskSortField.type:
          res = cmpStr(a.type, b.type);
          break;
      }
      return _taskAsc ? res : -res;
    });

    return filtered;
  }

  // ✅ Visible Resources (type filter + sort only)
  List<Resource> _visibleResources() {
    bool matchesType(Resource r) {
      switch (_resourceTypeFilter) {
        case ResourceTypeFilter.all:
          return true;
        case ResourceTypeFilter.note:
          return r.type == 'Note';
        case ResourceTypeFilter.link:
          return r.type == 'Link';
        case ResourceTypeFilter.file:
          return r.type == 'File';
      }
    }

    final filtered = _resources.where((r) => matchesType(r)).toList();

    int cmpStr(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());

    filtered.sort((a, b) {
      int res = 0;
      switch (_resourceSort) {
        case ResourceSortField.title:
          res = cmpStr(a.title, b.title);
          break;
        case ResourceSortField.type:
          res = cmpStr(a.type, b.type);
          break;
      }
      return _resourceAsc ? res : -res;
    });

    return filtered;
  }

  // ✅ Compact controls (NO SEARCH)
  Widget _taskControls() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: DropdownButtonFormField<TaskFilter>(
              initialValue: _taskFilter,
              isExpanded: true,
              decoration: _compactDeco(hint: 'Filter', icon: Icons.filter_list),
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
                  child: Text('This Week'),
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
              decoration: _compactDeco(hint: 'Sort', icon: Icons.sort),
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
        _squareIconButton(
          icon: _taskAsc ? Icons.arrow_upward : Icons.arrow_downward,
          onTap: () => setState(() => _taskAsc = !_taskAsc),
        ),
        const SizedBox(width: 10),
        _squareIconButton(
          icon: Icons.restart_alt,
          onTap: () {
            setState(() {
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
              decoration: _compactDeco(hint: 'Type', icon: Icons.filter_list),
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
              decoration: _compactDeco(hint: 'Sort', icon: Icons.sort),
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
        _squareIconButton(
          icon: _resourceAsc ? Icons.arrow_upward : Icons.arrow_downward,
          onTap: () => setState(() => _resourceAsc = !_resourceAsc),
        ),
        const SizedBox(width: 10),
        _squareIconButton(
          icon: Icons.restart_alt,
          onTap: () {
            setState(() {
              _resourceTypeFilter = ResourceTypeFilter.all;
              _resourceSort = ResourceSortField.title;
              _resourceAsc = true;
            });
          },
        ),
      ],
    );
  }

  Widget _squareIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 42,
      width: 42,
      child: Material(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Icon(icon, size: 18, color: Colors.black87),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final visibleTasks = _visibleTasks();
    final visibleResources = _visibleResources();

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
                  Column(
                    children: [
                      _taskControls(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: visibleTasks.isEmpty
                            ? Center(
                                child: Text(
                                  'No tasks match.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            : ListView.builder(
                                itemCount: visibleTasks.length,
                                itemBuilder: (ctx, i) {
                                  final t = visibleTasks[i];
                                  final due =
                                      DateTime.fromMillisecondsSinceEpoch(
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
                                                        ? TextDecoration
                                                              .lineThrough
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
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
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
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () =>
                                              _confirmDeleteTask(t),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),

                  // RESOURCES
                  Column(
                    children: [
                      _resourceControls(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: visibleResources.isEmpty
                            ? Center(
                                child: Text(
                                  'No resources match.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            : ListView.builder(
                                itemCount: visibleResources.length,
                                itemBuilder: (ctx, i) {
                                  final r = visibleResources[i];

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
