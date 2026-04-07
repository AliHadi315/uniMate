import 'package:flutter/material.dart';
import 'package:unimate/screens/phone_frame.dart';
import '../models/course.dart';
import '../db/course_storage.dart';
import '../db/task_storage.dart';
import 'course_details_screen.dart';

// Screen to display and manage the list of courses
// Allows adding, editing, and deleting courses
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

enum CourseSortField { name, code, instructor, semester }

class _CoursesScreenState extends State<CoursesScreen> {
  static const blue = Color(0xFF2563EB);

  List<Course> _coursesList = [];
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _instCtrl = TextEditingController();
  String _semesterValue = 'Fall 2025';

  // Filter/Sort state
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _semesterFilter = 'All';
  CourseSortField _sortField = CourseSortField.name;
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _instCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final loaded = await loadCourses();
    setState(() => _coursesList = loaded);
  }

  List<String> _semesterOptions() {
    return const ['All', 'Fall 2025', 'Spring 2026', 'Summer 2026'];
  }

  List<Course> _visibleCourses() {
    final q = _query.trim().toLowerCase();

    final filtered = _coursesList.where((c) {
      final matchesQuery =
          q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q) ||
          c.instructor.toLowerCase().contains(q);

      final matchesSemester =
          _semesterFilter == 'All' || c.semester == _semesterFilter;

      return matchesQuery && matchesSemester;
    }).toList();

    int cmpString(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());

    filtered.sort((a, b) {
      int res = 0;
      switch (_sortField) {
        case CourseSortField.name:
          res = cmpString(a.name, b.name);
          break;
        case CourseSortField.code:
          res = cmpString(a.code, b.code);
          break;
        case CourseSortField.instructor:
          res = cmpString(a.instructor, b.instructor);
          break;
        case CourseSortField.semester:
          res = cmpString(a.semester, b.semester);
          break;
      }
      return _ascending ? res : -res;
    });

    return filtered;
  }

  void _openCourseDialog({Course? existing}) {
    if (existing == null) {
      _nameCtrl.clear();
      _codeCtrl.clear();
      _instCtrl.clear();
      _semesterValue = 'Fall 2025';
    } else {
      _nameCtrl.text = existing.name;
      _codeCtrl.text = existing.code;
      _instCtrl.text = existing.instructor;
      _semesterValue = existing.semester;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Course' : 'Edit Course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Course Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(labelText: 'Course Code'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _instCtrl,
              decoration: const InputDecoration(labelText: 'Instructor'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _semesterValue,
              items: const [
                DropdownMenuItem(value: 'Fall 2025', child: Text('Fall 2025')),
                DropdownMenuItem(
                  value: 'Spring 2026',
                  child: Text('Spring 2026'),
                ),
                DropdownMenuItem(
                  value: 'Summer 2026',
                  child: Text('Summer 2026'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _semesterValue = v ?? _semesterValue),
              decoration: const InputDecoration(labelText: 'Semester'),
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
              final name = _nameCtrl.text.trim();
              final code = _codeCtrl.text.trim();
              final inst = _instCtrl.text.trim();
              if (name.isEmpty || code.isEmpty || inst.isEmpty) return;

              if (existing == null) {
                await insertCourse(
                  Course(
                    name: name,
                    code: code,
                    instructor: inst,
                    semester: _semesterValue,
                  ),
                );
              } else {
                await updateCourse(
                  existing.copyWith(
                    name: name,
                    code: code,
                    instructor: inst,
                    semester: _semesterValue,
                  ),
                );
              }

              if (mounted) Navigator.pop(ctx);
              await _refresh();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Course c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text('Delete "${c.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (c.id == null) return;
              await deleteCourseById(c.id!);
              await _refresh();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  InputDecoration _compactDeco({
    required String hint,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 18),
      suffixIcon: suffix,
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

  Widget _searchBar() {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        decoration: _compactDeco(
          hint: 'Search courses…',
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
    );
  }

  Widget _controls() {
    return Row(
      children: [
        // Semester
        Expanded(
          child: SizedBox(
            height: 42,
            child: DropdownButtonFormField<String>(
              initialValue: _semesterFilter,
              isExpanded: true,
              decoration: _compactDeco(hint: 'Semester', icon: Icons.school),
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

        // Sort
        Expanded(
          child: SizedBox(
            height: 42,
            child: DropdownButtonFormField<CourseSortField>(
              initialValue: _sortField,
              isExpanded: true,
              decoration: _compactDeco(hint: 'Sort', icon: Icons.sort),
              items: const [
                DropdownMenuItem(
                  value: CourseSortField.name,
                  child: Text('Name'),
                ),
                DropdownMenuItem(
                  value: CourseSortField.code,
                  child: Text('Code'),
                ),
                DropdownMenuItem(
                  value: CourseSortField.instructor,
                  child: Text('Instructor'),
                ),
                DropdownMenuItem(
                  value: CourseSortField.semester,
                  child: Text('Semester'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _sortField = v ?? CourseSortField.name),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Asc/Desc toggle
        SizedBox(
          height: 42,
          width: 42,
          child: Material(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _ascending = !_ascending),
              child: Icon(
                _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 18,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Reset
        SizedBox(
          height: 42,
          width: 42,
          child: Material(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                _searchCtrl.clear();
                setState(() {
                  _query = '';
                  _semesterFilter = 'All';
                  _sortField = CourseSortField.name;
                  _ascending = true;
                });
              },
              child: const Icon(
                Icons.restart_alt,
                size: 20,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleCourses();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCourseDialog(),
        child: const Icon(Icons.add),
      ),
      body: PhoneFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'My Courses',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Text(
              'Tap a course to manage tasks and resources.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 14),

            // Search + controls
            _searchBar(),
            const SizedBox(height: 10),
            _controls(),
            const SizedBox(height: 14),

            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        'No courses match.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (ctx, i) {
                        final course = visible[i];

                        return FutureBuilder<int>(
                          future: course.id == null
                              ? Future.value(0)
                              : countPendingTasksByCourse(course.id!),
                          builder: (context, snap) {
                            final taskCount = snap.data ?? 0;

                            return GestureDetector(
                              onTap: () {
                                if (course.id == null) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CourseDetailsScreen(course: course),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            course.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            course.code,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            course.instructor,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: blue.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        '$taskCount Tasks',
                                        style: const TextStyle(
                                          color: blue,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    PopupMenuButton<String>(
                                      onSelected: (v) {
                                        if (v == 'edit') {
                                          _openCourseDialog(existing: course);
                                        }
                                        if (v == 'delete') {
                                          _confirmDelete(course);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
