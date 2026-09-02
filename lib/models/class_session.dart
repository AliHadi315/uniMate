import 'package:flutter/material.dart';

/// One weekly lecture/lab slot for a course.
///
/// [weekday] follows `DateTime`: 1 = Monday … 7 = Sunday. Times are stored as
/// minutes since midnight so they need no timezone handling.
class ClassSession {
  final int? id;
  final int courseId;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final String location;

  const ClassSession({
    this.id,
    required this.courseId,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    this.location = '',
  });

  TimeOfDay get start =>
      TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60);

  TimeOfDay get end =>
      TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);

  static String formatMinutes(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get timeLabel =>
      '${formatMinutes(startMinutes)} – ${formatMinutes(endMinutes)}';

  static const weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String get weekdayName => weekdayNames[weekday - 1];

  ClassSession copyWith({
    int? id,
    int? courseId,
    int? weekday,
    int? startMinutes,
    int? endMinutes,
    String? location,
  }) {
    return ClassSession(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      weekday: weekday ?? this.weekday,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      location: location ?? this.location,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'courseId': courseId,
    'weekday': weekday,
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
    'location': location,
  };

  factory ClassSession.fromMap(Map<String, Object?> map) => ClassSession(
    id: map['id'] as int?,
    courseId: map['courseId'] as int,
    weekday: map['weekday'] as int,
    startMinutes: map['startMinutes'] as int,
    endMinutes: map['endMinutes'] as int,
    location: (map['location'] as String?) ?? '',
  );
}
