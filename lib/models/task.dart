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
  });

  bool get completed => isCompleted == 1;

  DateTime get dueDate => DateTime.fromMillisecondsSinceEpoch(dueDateMillis);

  bool get isOverdue => !completed && dueDate.isBefore(DateTime.now());

  /// The moment the reminder should fire, or null when there is none.
  DateTime? get reminderTime {
    final minutes = reminderMinutesBefore;
    if (minutes == null) return null;
    return dueDate.subtract(Duration(minutes: minutes));
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
    );
  }
}
