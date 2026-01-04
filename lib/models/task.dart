class Task {
  final int? id;
  final int courseId;
  final String title;
  final String type;
  final int dueDateMillis;
  final String priority;
  final int isCompleted;

  const Task({
    this.id,
    required this.courseId,
    required this.title,
    required this.type,
    required this.dueDateMillis,
    required this.priority,
    required this.isCompleted,
  });

  Task copyWith({
    int? id,
    int? courseId,
    String? title,
    String? type,
    int? dueDateMillis,
    String? priority,
    int? isCompleted,
  }) {
    return Task(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      type: type ?? this.type,
      dueDateMillis: dueDateMillis ?? this.dueDateMillis,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
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
    );
  }
}
