import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../db/course_storage.dart';
import '../db/task_storage.dart';
import '../models/course.dart';
import '../providers/auth_provider.dart';
import '../providers/data_refresh.dart';
import '../widgets/common.dart';
import 'course_details_screen.dart';
import 'phone_frame.dart';

enum CourseSortField { name, code, instructor, semester }

/// A course plus the counters shown on its card.
class _CourseRow {
  final Course course;
  final int pendingTasks;
  final int totalTasks;

  const _CourseRow({
    required this.course,
    required this.pendingTasks,
    required this.totalTasks,
  });
}

/// Lists the signed-in student's courses with search, filter and sort.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<_CourseRow> _rows = [];
  bool _loading = true;
  String? _error;
  int _revision = -1;

  final _searchCtrl = TextEditingController();
  String _query = '';
  String _semesterFilter = 'All';
  CourseSortField _sortField = CourseSortField.name;
  bool _ascending = true;
  bool _showArchived = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = Provider.of<DataRefresh>(context).revision;
    if (revision != _revision) {
      _revision = revision;
      _load();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = context.read<AuthProvider>().userId;
      final courses = await loadCourses(userId, includeArchived: true);

      // One pass over the courses instead of a FutureBuilder per row.
      final rows = <_CourseRow>[];
      for (final course in courses) {
        final id = course.id;
        final tasks = id == null ? const [] : await loadTasksByCourse(id);
        rows.add(
          _CourseRow(
            course: course,
            pendingTasks: tasks.where((t) => t.isCompleted == 0).length,
            totalTasks: tasks.length,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  List<String> _semesterOptions() {
    final used = _rows.map((r) => r.course.semester).toSet();
    final all = {..._defaultSemesters, ...used}.toList()..sort();
    return ['All', ...all];
  }

  static const _defaultSemesters = [
    'Fall 2025',
    'Spring 2026',
    'Summer 2026',
    'Fall 2026',
  ];

  List<_CourseRow> _visibleCourses() {
    final q = _query.trim().toLowerCase();

    final filtered = _rows.where((row) {
      final c = row.course;
      if (c.archived != _showArchived) return false;
      final matchesQuery =
          q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q) ||
          c.instructor.toLowerCase().contains(q);
      final matchesSemester =
          _semesterFilter == 'All' || c.semester == _semesterFilter;
      return matchesQuery && matchesSemester;
    }).toList();

    int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

    filtered.sort((a, b) {
      final res = switch (_sortField) {
        CourseSortField.name => cmp(a.course.name, b.course.name),
        CourseSortField.code => cmp(a.course.code, b.course.code),
        CourseSortField.instructor => cmp(
          a.course.instructor,
          b.course.instructor,
        ),
        CourseSortField.semester => cmp(a.course.semester, b.course.semester),
      };
      return _ascending ? res : -res;
    });

    return filtered;
  }

  Future<void> _openCourseDialog({Course? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CourseDialog(
        existing: existing,
        userId: context.read<AuthProvider>().userId,
        semesters: _defaultSemesters,
      ),
    );

    if (saved == true && mounted) context.read<DataRefresh>().bump();
  }

  Future<void> _toggleArchived(Course course) async {
    final id = course.id;
    if (id == null) return;

    await setCourseArchived(id, !course.archived);
    if (!mounted) return;
    context.read<DataRefresh>().bump();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            course.archived
                ? '"${course.name}" restored'
                : '"${course.name}" archived — hidden from the dashboard, '
                      'agenda and statistics',
          ),
        ),
      );
  }

  Future<void> _confirmDelete(Course course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete course'),
        content: Text(
          'Delete "${course.name}"?\n\n'
          'Its tasks and resources are removed too. This cannot be undone.',
        ),
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

    if (confirmed != true || course.id == null) return;

    await deleteCourseById(course.id!);
    if (mounted) context.read<DataRefresh>().bump();
  }

  Future<void> _openCourse(Course course) async {
    if (course.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourseDetailsScreen(course: course)),
    );
    if (mounted) context.read<DataRefresh>().bump();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleCourses();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCourseDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Course'),
      ),
      body: SafeArea(
        child: PhoneFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'My Courses',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _showArchived
                        ? 'Show active courses'
                        : 'Show archived courses',
                    onPressed: () =>
                        setState(() => _showArchived = !_showArchived),
                    icon: Icon(
                      _showArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              Text(
                'Tap a course to manage its tasks and resources.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 14),

              SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: compactDecoration(
                    context,
                    hint: 'Search name, code or instructor…',
                    icon: Icons.search,
                    suffix: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _controls(),
              const SizedBox(height: 14),

              Expanded(child: _list(visible)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(List<_CourseRow> visible) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load courses',
        message: _error,
        action: FilledButton(
          onPressed: _load,
          child: const Text('Try again'),
        ),
      );
    }
    if (_rows.isEmpty) {
      return EmptyState(
        icon: Icons.school_outlined,
        title: 'No courses yet',
        message: 'Add the courses you are taking this semester to get started.',
        action: FilledButton.icon(
          onPressed: () => _openCourseDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add course'),
        ),
      );
    }
    if (visible.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No courses match',
        message: 'Try a different search term or clear the filters.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 90),
        itemCount: visible.length,
        itemBuilder: (ctx, i) => _courseCard(visible[i]),
      ),
    );
  }

  Widget _courseCard(_CourseRow row) {
    final course = row.course;
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTheme.courseColor(
      course.colorValue,
      seedIndex: course.id ?? 0,
    );
    final done = row.totalTasks - row.pendingTasks;
    final progress = row.totalTasks == 0 ? 0.0 : done / row.totalTasks;

    return AppTile(
      accent: accent,
      onTap: () => _openCourse(course),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${course.code} • ${course.instructor}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (course.archived)
                Pill(
                  text: 'Archived',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  dense: true,
                )
              else
                Pill(
                  text: row.pendingTasks == 0
                      ? 'Clear'
                      : '${row.pendingTasks} open',
                  color: row.pendingTasks == 0 ? AppTheme.low : accent,
                  dense: true,
                ),
              PopupMenuButton<String>(
                tooltip: 'Course actions',
                onSelected: (v) {
                  if (v == 'edit') _openCourseDialog(existing: course);
                  if (v == 'archive') _toggleArchived(course);
                  if (v == 'delete') _confirmDelete(course);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(course.archived ? 'Unarchive' : 'Archive'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (row.totalTasks > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: accent,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '$done / ${row.totalTasks} tasks done',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  course.semester,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _controls() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: DropdownButtonFormField<String>(
              initialValue: _semesterOptions().contains(_semesterFilter)
                  ? _semesterFilter
                  : 'All',
              isExpanded: true,
              decoration: compactDecoration(
                context,
                hint: 'Semester',
                icon: Icons.school,
              ),
              items: _semesterOptions()
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _semesterFilter = v ?? 'All'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 42,
            child: DropdownButtonFormField<CourseSortField>(
              initialValue: _sortField,
              isExpanded: true,
              decoration: compactDecoration(
                context,
                hint: 'Sort',
                icon: Icons.sort,
              ),
              items: const [
                DropdownMenuItem(
                  value: CourseSortField.name,
                  child: Text('Name', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: CourseSortField.code,
                  child: Text('Code', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: CourseSortField.instructor,
                  child: Text('Instructor', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: CourseSortField.semester,
                  child: Text('Semester', style: TextStyle(fontSize: 13)),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _sortField = v ?? CourseSortField.name),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SquareIconButton(
          tooltip: _ascending ? 'Ascending' : 'Descending',
          icon: _ascending ? Icons.arrow_upward : Icons.arrow_downward,
          onTap: () => setState(() => _ascending = !_ascending),
        ),
        const SizedBox(width: 10),
        SquareIconButton(
          tooltip: 'Reset filters',
          icon: Icons.restart_alt,
          onTap: () {
            _searchCtrl.clear();
            setState(() {
              _query = '';
              _semesterFilter = 'All';
              _sortField = CourseSortField.name;
              _ascending = true;
            });
          },
        ),
      ],
    );
  }
}

/// Add/edit dialog. Owns its own controllers so its state cannot leak into
/// the list screen (the previous version reused the parent's controllers and
/// its dropdown did not repaint).
class _CourseDialog extends StatefulWidget {
  const _CourseDialog({
    required this.existing,
    required this.userId,
    required this.semesters,
  });

  final Course? existing;
  final int userId;
  final List<String> semesters;

  @override
  State<_CourseDialog> createState() => _CourseDialogState();
}

class _CourseDialogState extends State<_CourseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _instCtrl;
  late String _semester;
  late int _colorValue;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _codeCtrl = TextEditingController(text: existing?.code ?? '');
    _instCtrl = TextEditingController(text: existing?.instructor ?? '');
    _semester = existing?.semester ?? widget.semesters.first;
    _colorValue = existing?.colorValue ?? AppTheme.coursePalette.first.toARGB32();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _instCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    try {
      final existing = widget.existing;
      if (existing == null) {
        await insertCourse(
          Course(
            userId: widget.userId,
            name: _nameCtrl.text.trim(),
            code: _codeCtrl.text.trim(),
            instructor: _instCtrl.text.trim(),
            semester: _semester,
            colorValue: _colorValue,
          ),
        );
      } else {
        await updateCourse(
          existing.copyWith(
            name: _nameCtrl.text.trim(),
            code: _codeCtrl.text.trim(),
            instructor: _instCtrl.text.trim(),
            semester: _semester,
            colorValue: _colorValue,
          ),
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
    final semesters = {...widget.semesters, _semester}.toList()..sort();

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add course' : 'Edit course'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Course name'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a course name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Course code'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a course code' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _instCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Instructor'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter the instructor' : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _semester,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Semester'),
                items: semesters
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _semester = v ?? _semester),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Colour',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppTheme.coursePalette.map((color) {
                  final value = color.toARGB32();
                  final selected = value == _colorValue;
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(() => _colorValue = value),
                    child: Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
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
