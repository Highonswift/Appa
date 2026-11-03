import '../models/models.dart';

/// Pure Phase 5 rules: turning band samples into nights and walks, and the
/// summaries his screens and the doctor page show. No I/O.

/// A run of samples from the band.
class Span {
  const Span(this.from, this.to, [this.value = 0]);
  final DateTime from;
  final DateTime to;

  /// Steps in this span (0 for sleep spans).
  final int value;

  Duration get length => to.difference(from);
}

// ------------------------------------------------------------------ sleep

/// The night that ends on the morning of [day]: sleep spans that end
/// between noon the day before and noon on [day]. Overlaps are merged so a
/// band that reports both a session and its stages isn't double counted.
({int minutes, DateTime bed, DateTime wake})? nightFromSpans(
  String day,
  List<Span> sleep,
) {
  final d = DateTime.parse(day);
  final from = DateTime(d.year, d.month, d.day - 1, 12);
  final to = DateTime(d.year, d.month, d.day, 12);
  final spans =
      sleep.where((s) => s.to.isAfter(from) && !s.to.isAfter(to)).toList()
        ..sort((a, b) => a.from.compareTo(b.from));
  if (spans.isEmpty) return null;
  var minutes = 0;
  var curFrom = spans.first.from, curTo = spans.first.to;
  for (final s in spans.skip(1)) {
    if (!s.from.isAfter(curTo)) {
      if (s.to.isAfter(curTo)) curTo = s.to;
    } else {
      minutes += curTo.difference(curFrom).inMinutes;
      curFrom = s.from;
      curTo = s.to;
    }
  }
  minutes += curTo.difference(curFrom).inMinutes;
  final wake = spans.map((s) => s.to).reduce((a, b) => a.isAfter(b) ? a : b);
  return (minutes: minutes, bed: spans.first.from, wake: wake);
}

/// A night counts as bad when he rated it bad, or (without a rating) the
/// band measured under 4½ hours. Band hours add evidence; they never
/// overrule what he said.
bool badNight(SleepRating? rating, NightSleep? night) {
  if (rating != null) return rating == SleepRating.bad;
  final m = night?.minutes;
  return m != null && m < 270;
}

// ------------------------------------------------------------------ walking

class Walk {
  const Walk(this.start, this.end, this.steps);
  final DateTime start;
  final DateTime end;
  final int steps;
  int get minutes => end.difference(start).inMinutes;
}

/// Groups step samples into walks: samples less than 5 minutes apart join
/// up; a walk lasts 10+ minutes at 40+ steps a minute on average (an easy
/// pace for someone just starting; pottering about the house doesn't count).
List<Walk> walksFromSteps(List<Span> steps) {
  final s = steps.where((x) => x.value > 0).toList()
    ..sort((a, b) => a.from.compareTo(b.from));
  final out = <Walk>[];
  if (s.isEmpty) return out;
  var start = s.first.from, end = s.first.to, count = s.first.value;
  void close() {
    final mins = end.difference(start).inMinutes;
    if (mins >= 10 && count / mins >= 40) out.add(Walk(start, end, count));
  }

  for (final x in s.skip(1)) {
    if (x.from.difference(end) <= const Duration(minutes: 5)) {
      if (x.to.isAfter(end)) end = x.to;
      count += x.value;
    } else {
      close();
      start = x.from;
      end = x.to;
      count = x.value;
    }
  }
  close();
  return out;
}

/// One DayActivity per day in [days] (dayKeys), from step samples, walks
/// and resting heart-rate readings.
List<DayActivity> dayActivities(
  List<String> days,
  List<Span> steps,
  List<({DateTime at, int bpm})> resting,
) {
  final walks = walksFromSteps(steps);
  return [
    for (final d in days)
      DayActivity(
        day: d,
        steps: steps
            .where((x) => dayKey(x.from) == d)
            .fold(0, (n, x) => n + x.value),
        walkMinutes: walks
            .where((w) => dayKey(w.start) == d)
            .fold(0, (n, w) => n + w.minutes),
        restingHr: () {
          final r = resting
              .where((x) => dayKey(x.at) == d)
              .map((x) => x.bpm)
              .toList();
          return r.isEmpty
              ? null
              : (r.reduce((a, b) => a + b) / r.length).round();
        }(),
      ),
  ];
}

/// Walk days for the last [days] days ending today, oldest first.
List<bool> walkDays(
  DateTime today,
  List<DayActivity> activity, {
  int days = 7,
}) => List.generate(days, (i) {
  final key = dayKey(
    DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: days - 1 - i)),
  );
  return activity.any((a) => a.day == key && a.walked);
});

/// Hours slept per night over the last [days] days, oldest first; nights
/// without data are skipped.
List<(DateTime, double)> sleepHoursSeries(
  DateTime today,
  List<NightSleep> nights, {
  int days = 56,
}) {
  final from = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: days - 1));
  final out = <(DateTime, double)>[];
  for (final n in nights) {
    final d = DateTime.parse(n.day);
    if (!d.isBefore(from) && n.hours != null) out.add((d, n.hours!));
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}

class BodySummary {
  const BodySummary({
    required this.nightsWithHours,
    this.avgSleepHours,
    required this.walkDays,
    this.avgSteps,
    this.avgRestingHr,
    required this.bandNights,
  });

  final int nightsWithHours;
  final double? avgSleepHours;
  final int walkDays;
  final int? avgSteps;
  final int? avgRestingHr;

  /// Nights the band recorded (is he wearing it?).
  final int bandNights;
}

/// For the doctor page and the weekly review: the last [days] days.
BodySummary bodySummary(
  DateTime today,
  List<NightSleep> nights,
  List<DayActivity> activity, {
  int days = 30,
}) {
  final from = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: days - 1));
  bool inRange(String day) => !DateTime.parse(day).isBefore(from);
  final n = nights.where((x) => inRange(x.day)).toList();
  final hrs = n.map((x) => x.hours).whereType<double>().toList();
  final a = activity.where((x) => inRange(x.day)).toList();
  final withSteps = a.where((x) => x.steps > 0).toList();
  final hr = a.map((x) => x.restingHr).whereType<int>().toList();
  return BodySummary(
    nightsWithHours: hrs.length,
    avgSleepHours: hrs.isEmpty
        ? null
        : hrs.reduce((x, y) => x + y) / hrs.length,
    walkDays: a.where((x) => x.walked).length,
    avgSteps: withSteps.isEmpty
        ? null
        : (withSteps.fold(0, (s, x) => s + x.steps) / withSteps.length).round(),
    avgRestingHr: hr.isEmpty
        ? null
        : (hr.reduce((x, y) => x + y) / hr.length).round(),
    bandNights: n.where((x) => x.bandMinutes != null).length,
  );
}

/// "6 மணி 40 நிமி".
String hoursLabel(int minutes) => '${minutes ~/ 60} மணி ${minutes % 60} நிமி';

// ------------------------------------------------------------------ getting him walking

/// Errands on foot the daily plan can suggest once his doctor has cleared
/// him (roadmap: "A walk to somewhere").
const walkErrands = <String>[
  'நடந்து கோயிலுக்கு',
  'நடந்து கடைக்கு',
  'நடந்து போய் பால் வாங்குவது',
  'நடந்து போய் செய்தித்தாள் வாங்குவது',
];

/// Plan items a recorded walk ticks: anything mentioning a walk.
bool isWalkItem(String text) =>
    text.contains('நடை') || text.startsWith('நடந்து');

/// The line suggested during a call with a nearby friend.
String walkTogetherLine(String name) =>
    'பேசும்போது கேளுங்கள்: "நாளை காலை சேர்ந்து நடக்கலாமா?"';
