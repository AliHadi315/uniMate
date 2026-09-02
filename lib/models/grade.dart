/// One assessment result for a course.
///
/// [weight] is the assessment's share of the final grade in percent. When
/// every recorded grade has weight 0, averages fall back to a simple mean.
class Grade {
  final int? id;
  final int courseId;
  final String title;
  final double score;
  final double maxScore;
  final double weight;
  final int createdAtMillis;

  const Grade({
    this.id,
    required this.courseId,
    required this.title,
    required this.score,
    required this.maxScore,
    this.weight = 0,
    required this.createdAtMillis,
  });

  /// 0..100, guarded against a zero max.
  double get percent => maxScore <= 0 ? 0 : (score / maxScore) * 100;

  Grade copyWith({
    int? id,
    String? title,
    double? score,
    double? maxScore,
    double? weight,
  }) {
    return Grade(
      id: id ?? this.id,
      courseId: courseId,
      title: title ?? this.title,
      score: score ?? this.score,
      maxScore: maxScore ?? this.maxScore,
      weight: weight ?? this.weight,
      createdAtMillis: createdAtMillis,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'courseId': courseId,
    'title': title,
    'score': score,
    'maxScore': maxScore,
    'weight': weight,
    'createdAtMillis': createdAtMillis,
  };

  factory Grade.fromMap(Map<String, Object?> map) => Grade(
    id: map['id'] as int?,
    courseId: map['courseId'] as int,
    title: map['title'] as String,
    score: (map['score'] as num).toDouble(),
    maxScore: (map['maxScore'] as num).toDouble(),
    weight: ((map['weight'] as num?) ?? 0).toDouble(),
    createdAtMillis: map['createdAtMillis'] as int,
  );
}

/// Grade aggregation used by the course screen and statistics.
class GradeSummary {
  final int count;

  /// Weighted (or plain, when no weights are set) average in percent,
  /// or null when there are no grades.
  final double? average;

  /// Sum of the recorded weights — tells the student how much of the final
  /// grade is accounted for so far.
  final double weightCovered;

  const GradeSummary({
    required this.count,
    required this.average,
    required this.weightCovered,
  });

  static GradeSummary of(Iterable<Grade> grades) {
    final list = grades.toList();
    if (list.isEmpty) {
      return const GradeSummary(count: 0, average: null, weightCovered: 0);
    }

    final totalWeight = list.fold<double>(0, (sum, g) => sum + g.weight);
    double average;
    if (totalWeight > 0) {
      average =
          list.fold<double>(0, (sum, g) => sum + g.percent * g.weight) /
          totalWeight;
    } else {
      average =
          list.fold<double>(0, (sum, g) => sum + g.percent) / list.length;
    }

    return GradeSummary(
      count: list.length,
      average: average,
      weightCovered: totalWeight,
    );
  }

  /// A common percent → 4.0-scale mapping. Institutions differ; this is the
  /// widely used band table and is labelled as an estimate in the UI.
  static double gpaFromPercent(double percent) {
    if (percent >= 90) return 4.0;
    if (percent >= 85) return 3.7;
    if (percent >= 80) return 3.3;
    if (percent >= 75) return 3.0;
    if (percent >= 70) return 2.7;
    if (percent >= 65) return 2.3;
    if (percent >= 60) return 2.0;
    if (percent >= 55) return 1.7;
    if (percent >= 50) return 1.0;
    return 0.0;
  }

  static String letterFromPercent(double percent) {
    if (percent >= 90) return 'A';
    if (percent >= 80) return 'B';
    if (percent >= 70) return 'C';
    if (percent >= 60) return 'D';
    if (percent >= 50) return 'E';
    return 'F';
  }
}
