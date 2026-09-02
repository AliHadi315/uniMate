class Task {
  final int? id;
  final int courseId;
  final String title;
  final String type;
  final int dueDateMillis;
  final String priority;
  final int isCompleted;
  final String notes;

  /// Minutes before [dueDateMillis] a local reminder should fire.
  /// `null` means no reminder.
  final int? reminderMinutesBefore;

  /// When the task was ticked off, used by the weekly activity chart.
  final int? completedAtMillis;

  /// Interval in days between occurrences (1 daily, 7 weekly, …).
  /// `null` means the task does not repeat. Completing a repeating task
  /// spawns the next occurrence.
  final int? recurrenceDays;

  /// Optional local file attached to this task.
  final String? attachmentPath;

  const Task({
    this.id,
    required this.courseId,
    required this.title,
    required this.type,
    required this.dueDateMillis,
    required this.priority,
    required this.isCompleted,
    this.notes = '',
    this.reminderMinutesBefore,
    this.completedAtMillis,
    this.recurrenceDays,
    this.attachmentPath,
  });

  bool get completed => isCompleted == 1;

  bool get repeats => recurrenceDays != null && recurrenceDays! > 0;

  DateTime get dueDate => DateTime.fromMillisecondsSinceEpoch(dueDateMillis);

  bool get isOverdue => !completed && dueDate.isBefore(DateTime.now());

  /// The moment the reminder should fire, or null when there is none.
  DateTime? get reminderTime {
    final minutes = reminderMinutesBefore;
    if (minutes == null) return null;
    return dueDate.subtract(Duration(minutes: minutes));
  }

  /// Due date of the occurrence after this one — the next slot strictly in
  /// the future, so completing an overdue weekly task does not spawn another
  /// task that is already overdue.
  DateTime nextOccurrence({DateTime? now}) {
    final days = recurrenceDays ?? 0;
    assert(days > 0, 'nextOccurrence needs a repeating task');
    final reference = now ?? DateTime.now();
    var next = dueDate.add(Duration(days: days));
    while (!next.isAfter(reference)) {
      next = next.add(Duration(days: days));
    }
    return next;
  }

  Task copyWith({
    int? id,
    int? courseId,
    String? title,
    String? type,
    int? dueDateMillis,
    String? priority,
    int? isCompleted,
    String? notes,
    int? reminderMinutesBefore,
    bool clearReminder = false,
    int? completedAtMillis,
    bool clearCompletedAt = false,
    int? recurrenceDays,
    bool clearRecurrence = false,
    String? attachmentPath,
    bool clearAttachment = false,
  }) {
    return Task(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      type: type ?? this.type,
      dueDateMillis: dueDateMillis ?? this.dueDateMillis,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      reminderMinutesBefore: clearReminder
          ? null
          : (reminderMinutesBefore ?? this.reminderMinutesBefore),
      completedAtMillis: clearCompletedAt
          ? null
          : (completedAtMillis ?? this.completedAtMillis),
      recurrenceDays: clearRecurrence
          ? null
          : (recurrenceDays ?? this.recurrenceDays),
      attachmentPath: clearAttachment
          ? null
          : (attachmentPath ?? this.attachmentPath),
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'courseId': courseId,
    'title': title,
    'type': type,
    'dueDateMillis': dueDateMillis,
    'priority': priority,
    'isCompleted': isCompleted,
    'notes': notes,
    'reminderMinutesBefore': reminderMinutesBefore,
    'completedAtMillis': completedAtMillis,
    'recurrenceDays': recurrenceDays,
    'attachmentPath': attachmentPath,
  };

  factory Task.fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as int?,
      courseId: map['courseId'] as int,
      title: map['title'] as String,
      type: map['type'] as String,
      dueDateMillis: map['dueDateMillis'] as int,
      priority: map['priority'] as String,
      isCompleted: map['isCompleted'] as int,
      notes: (map['notes'] as String?) ?? '',
      reminderMinutesBefore: map['reminderMinutesBefore'] as int?,
      completedAtMillis: map['completedAtMillis'] as int?,
      recurrenceDays: map['recurrenceDays'] as int?,
      attachmentPath: map['attachmentPath'] as String?,
    );
  }
}
