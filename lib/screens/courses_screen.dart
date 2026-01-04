import 'package:flutter/material.dart';
import 'package:unimate/screens/phone_frame.dart';
import '../models/course.dart';
import '../db/course_storage.dart';
import '../db/task_storage.dart';
import 'course_details_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key, required this.courses});
  final List<Course> courses;

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  static const blue = Color(0xFF2563EB);

  late List<Course> _coursesList;

  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _instCtrl = TextEditingController();
  String _semesterValue = 'Fall 2025';

  @override
  void initState() {
    super.initState();
    _coursesList = widget.courses;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _instCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final loaded = await loadCourses();
    setState(() => _coursesList = loaded);
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

  @override
  Widget build(BuildContext context) {
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

            Expanded(
              child: _coursesList.isEmpty
                  ? Center(
                      child: Text(
                        'No courses yet.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _coursesList.length,
                      itemBuilder: (ctx, i) {
                        final course = _coursesList[i];

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
