class Course {
  final int? id;
  final int userId;
  final String name;
  final String code;
  final String instructor;
  final String semester;

  /// ARGB colour used for the course accent. 0 means "pick from the palette
  /// deterministically", which keeps old rows looking sensible.
  final int colorValue;

  const Course({
    this.id,
    this.userId = 0,
    required this.name,
    required this.code,
    required this.instructor,
    required this.semester,
    this.colorValue = 0,
  });

  Course copyWith({
    int? id,
    int? userId,
    String? name,
    String? code,
    String? instructor,
    String? semester,
    int? colorValue,
  }) {
    return Course(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      code: code ?? this.code,
      instructor: instructor ?? this.instructor,
      semester: semester ?? this.semester,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'code': code,
    'instructor': instructor,
    'semester': semester,
    'colorValue': colorValue,
  };

  factory Course.fromMap(Map<String, Object?> map) {
    return Course(
      id: map['id'] as int?,
      userId: (map['userId'] as int?) ?? 0,
      name: map['name'] as String,
      code: map['code'] as String,
      instructor: map['instructor'] as String,
      semester: map['semester'] as String,
      colorValue: (map['colorValue'] as int?) ?? 0,
    );
  }
}
