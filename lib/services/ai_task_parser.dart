import 'dart:convert';

/// A task proposed by the assistant, before the student reviews it.
class SuggestedTask {
  final String courseCode;
  final String title;
  final String type;
  final int dueInDays;
  final String priority;
  final String notes;

  const SuggestedTask({
    required this.courseCode,
    required this.title,
    required this.type,
    required this.dueInDays,
    required this.priority,
    required this.notes,
  });
}

/// The assistant's reply split into prose and structured task suggestions.
class ParsedAiReply {
  final String text;
  final List<SuggestedTask> tasks;

  const ParsedAiReply({required this.text, required this.tasks});
}

/// Extracts the ```unimate-tasks``` block the system prompt asks the model to
/// emit when it proposes concrete work.
///
/// Everything is validated defensively: the block is model output, so a
/// malformed or hostile payload must degrade to "no suggestions", never throw.
class AiTaskParser {
  const AiTaskParser._();

  static const allowedTypes = {
    'Assignment',
    'Exam',
    'Project',
    'Quiz',
    'Reading',
  };
  static const allowedPriorities = {'Low', 'Medium', 'High'};

  static final _blockPattern = RegExp(
    r'```unimate-tasks\s*\n(.*?)```',
    dotAll: true,
  );

  /// The instruction appended to the system prompt.
  static const promptInstruction =
      'When the student asks you to plan, schedule or break down work, you '
      'may ALSO propose concrete tasks the app can create. To do that, end '
      'your reply with a fenced code block tagged unimate-tasks containing a '
      'JSON array, e.g.\n'
      '```unimate-tasks\n'
      '[{"course":"CS340","title":"Read chapter 4","type":"Reading",'
      '"dueInDays":2,"priority":"Medium","notes":""}]\n'
      '```\n'
      'Rules for the block: "course" must be one of the listed course codes; '
      '"type" one of Assignment/Exam/Project/Quiz/Reading; "priority" one of '
      'Low/Medium/High; "dueInDays" an integer 0-60 counting from today. '
      'At most 10 tasks. Only include the block when the student wants tasks '
      'created; never mention the block itself in your prose.';

  static ParsedAiReply parse(String reply) {
    final match = _blockPattern.firstMatch(reply);
    if (match == null) return ParsedAiReply(text: reply.trim(), tasks: const []);

    final text = reply.replaceAll(_blockPattern, '').trim();
    final tasks = _parseTasks(match.group(1) ?? '');
    return ParsedAiReply(text: text, tasks: tasks);
  }

  static List<SuggestedTask> _parseTasks(String jsonText) {
    Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      return const [];
    }
    if (decoded is! List) return const [];

    final tasks = <SuggestedTask>[];
    for (final entry in decoded.take(10)) {
      if (entry is! Map) continue;

      final title = (entry['title'] as Object?)?.toString().trim() ?? '';
      if (title.isEmpty || title.length > 120) continue;

      final rawDue = entry['dueInDays'];
      final dueInDays = rawDue is int
          ? rawDue
          : int.tryParse('$rawDue') ?? -1;
      if (dueInDays < 0 || dueInDays > 60) continue;

      final type = (entry['type'] as Object?)?.toString() ?? '';
      final priority = (entry['priority'] as Object?)?.toString() ?? '';

      tasks.add(
        SuggestedTask(
          courseCode: (entry['course'] as Object?)?.toString().trim() ?? '',
          title: title,
          type: allowedTypes.contains(type) ? type : 'Assignment',
          dueInDays: dueInDays,
          priority:
              allowedPriorities.contains(priority) ? priority : 'Medium',
          notes: ((entry['notes'] as Object?)?.toString() ?? '').length > 500
              ? ''
              : (entry['notes'] as Object?)?.toString() ?? '',
        ),
      );
    }
    return tasks;
  }
}
