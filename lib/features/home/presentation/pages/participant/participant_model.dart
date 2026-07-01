import 'package:intl/intl.dart';

/// One activity that can be scored (e.g. "Homework", weight 20%).
class ActivityWeight {
  final String id;
  final String name;
  final double weight;

  const ActivityWeight({
    required this.id,
    required this.name,
    required this.weight,
  });

  factory ActivityWeight.fromJson(Map<String, dynamic> json) {
    return ActivityWeight(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? 'Untitled').toString(),
      weight: _toDouble(json['score'] ?? json['weight'] ?? 0),
    );
  }
}

/// One score record (a student got [score] for [activityId] on [date]).
class ScoreEntry {
  final String activityId;
  final double score;
  final DateTime date;

  const ScoreEntry({
    required this.activityId,
    required this.score,
    required this.date,
  });

  factory ScoreEntry.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] ?? json['scoredAt'] ?? json['createdAt'] ?? '';
    DateTime parsed;
    try {
      parsed = DateTime.parse(rawDate.toString()).toLocal();
    } catch (_) {
      parsed = DateTime.now();
    }

    return ScoreEntry(
      activityId: (json['participationId'] ?? json['activityId'] ?? '')
          .toString(),
      score: _toDouble(json['score'] ?? 0),
      date: DateTime(parsed.year, parsed.month, parsed.day),
    );
  }
}

/// One row inside a day group — denormalised for the UI.
class DayRow {
  final String activityName;
  final double score;
  final double max;

  const DayRow({
    required this.activityName,
    required this.score,
    required this.max,
  });

  double get fraction => max <= 0 ? 0 : (score / max).clamp(0, 1).toDouble();
}

/// All rows for one date, plus the day's total.
class DayGroup {
  final DateTime date;
  final List<DayRow> rows;

  const DayGroup({required this.date, required this.rows});

  double get totalScore => rows.fold(0.0, (s, r) => s + r.score);
  double get totalMax => rows.fold(0.0, (s, r) => s + r.max);

  int get percent =>
      totalMax <= 0 ? 0 : ((totalScore / totalMax) * 100).round();

  String get label => DateFormat('EEE, d MMM y').format(date);
}

/// What the page needs to render.
class ParticipantSummary {
  final List<ActivityWeight> weights;
  final List<DayGroup> days;

  const ParticipantSummary({required this.weights, required this.days});

  double get totalWeight => weights.fold(0.0, (s, w) => s + w.weight);

  /// Most-recent-day percent — what the hero ring shows.
  int get latestPercent => days.isEmpty ? 0 : days.first.percent;

  int get scoredDayCount => days.length;
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}
