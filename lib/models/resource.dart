class Resource {
  final int? id;
  final int courseId;
  final String title;
  final String type; // Note / Link / File
  final String value;

  const Resource({
    this.id,
    required this.courseId,
    required this.title,
    required this.type,
    required this.value,
  });

  Resource copyWith({
    int? id,
    int? courseId,
    String? title,
    String? type,
    String? value,
  }) {
    return Resource(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      type: type ?? this.type,
      value: value ?? this.value,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'courseId': courseId,
    'title': title,
    'type': type,
    'value': value,
  };

  factory Resource.fromMap(Map<String, Object?> map) {
    return Resource(
      id: map['id'] as int?,
      courseId: map['courseId'] as int,
      title: map['title'] as String,
      type: map['type'] as String,
      value: map['value'] as String,
    );
  }
}
