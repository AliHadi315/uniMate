import 'package:flutter/material.dart';
import 'package:unimate/screens/phone_frame.dart';
import '../models/task.dart';
import '../db/task_storage.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.courseId,
    required this.existingTask,
  });

  final int courseId;
  final Task? existingTask;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  static const blue = Color(0xFF2563EB);

  final _titleCtrl = TextEditingController();

  String _type = 'Assignment';
  String _priority = 'Medium';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTask;
    if (t != null) {
      _titleCtrl.text = t.title;
      _type = t.type;
      _priority = t.priority;
      _dueDate = DateTime.fromMillisecondsSinceEpoch(t.dueDateMillis);
      _completed = t.isCompleted == 1;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final completedInt = _completed ? 1 : 0;

    if (widget.existingTask == null) {
      await insertTask(
        Task(
          courseId: widget.courseId,
          title: title,
          type: _type,
          dueDateMillis: _dueDate.millisecondsSinceEpoch,
          priority: _priority,
          isCompleted: completedInt,
        ),
      );
    } else {
      final old = widget.existingTask!;
      if (old.id == null) return;
      await updateTask(
        old.copyWith(
          title: title,
          type: _type,
          dueDateMillis: _dueDate.millisecondsSinceEpoch,
          priority: _priority,
          isCompleted: completedInt,
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingTask != null;

    return Scaffold(
      body: PhoneFrame(
        child: ListView(
          children: [
            Text(
              isEdit ? 'Edit Task' : 'Add Task',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Task Title'),
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Task Type'),
              items: const [
                DropdownMenuItem(
                  value: 'Assignment',
                  child: Text('Assignment'),
                ),
                DropdownMenuItem(value: 'Exam', child: Text('Exam')),
                DropdownMenuItem(value: 'Project', child: Text('Project')),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem(value: 'Low', child: Text('Low')),
                DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                DropdownMenuItem(value: 'High', child: Text('High')),
              ],
              onChanged: (v) => setState(() => _priority = v ?? _priority),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Due: ${_dueDate.month}/${_dueDate.day}/${_dueDate.year}',
                    ),
                  ),
                  TextButton(onPressed: _pickDate, child: const Text('Pick')),
                ],
              ),
            ),
            const SizedBox(height: 10),

            SwitchListTile(
              value: _completed,
              onChanged: (v) => setState(() => _completed = v),
              title: const Text('Completed'),
            ),

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _save,
                child: Text(isEdit ? 'Save Changes' : 'Save Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
