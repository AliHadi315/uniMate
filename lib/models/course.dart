class Course {
  final int? id;
  final String name;
  final String code;
  final String instructor;
  final String semester;

  const Course({
    this.id,
    required this.name,
    required this.code,
    required this.instructor,
    required this.semester,
  });

  Course copyWith({
    int? id,
    String? name,
    String? code,
    String? instructor,
    String? semester,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      instructor: instructor ?? this.instructor,
      semester: semester ?? this.semester,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'code': code,
    'instructor': instructor,
    'semester': semester,
  };

  factory Course.fromMap(Map<String, Object?> map) {
    return Course(
      id: map['id'] as int?,
      name: map['name'] as String,
      code: map['code'] as String,
      instructor: map['instructor'] as String,
      semester: map['semester'] as String,
    );
  }
}
