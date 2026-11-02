import '../data/scam_stories.dart';
import '../models/models.dart';

/// Pure Phase 2 rules: no I/O, so all of it is unit-tested.

// ------------------------------------------------------------------ scams

/// ISO-8601 week number of [d] (1–53).
int isoWeek(DateTime d) {
  final date = DateTime.utc(d.year, d.month, d.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstOfYear = DateTime.utc(thursday.year, 1, 1);
  return 1 + thursday.difference(firstOfYear).inDays ~/ 7;
}

/// One story a week, the same for the whole week, cycling through the list.
ScamStory scamForWeek(DateTime d, {List<ScamStory> stories = scamStories}) {
  final weekIndex =
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      (7 * 86400000);
  return stories[weekIndex % stories.length];
}

/// This week's and the earlier ones, newest first (for the archive).
List<ScamStory> scamArchive(
  DateTime d, {
  int weeks = 8,
  List<ScamStory> stories = scamStories,
}) {
  final seen = <String>{};
  final out = <ScamStory>[];
  for (var i = 0; i < weeks && out.length < stories.length; i++) {
    final s = scamForWeek(d.subtract(Duration(days: 7 * i)), stories: stories);
    if (seen.add(s.id)) out.add(s);
  }
  return out;
}

// ------------------------------------------------------------------ plan

/// Suggested items (roadmap: "walk, medicine, news, one call, one task").
const planSuggestions = [
  'காலை நடை',
  'மாத்திரை',
  'செய்தித்தாள் படிப்பது',
  'ஒருவருக்கு போன்',
  'வீட்டில் ஒரு வேலை',
  'கோயில்',
  'மாலை நடை',
];

List<PlanItem> planFor(String day, List<PlanItem> items) =>
    items.where((i) => i.day == day).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

/// A family member may add one item a day (roadmap: "Amma can add one item a
/// day, which is how household tasks reach him as requests, not orders").
bool familyCanAdd(String author, String day, List<PlanItem> items) =>
    !items.any((i) => i.day == day && i.addedBy == author);

// ------------------------------------------------------------------ health

/// Returns a gentle Tamil message if the numbers can't be right (a typo),
/// otherwise null. Deliberately no "high"/"low" judgement: that is the
/// doctor's job.
String? validateHealth(HealthKind kind, int? value, int? value2) {
  if (value == null) return 'எண்ணைப் போடுங்கள்.';
  switch (kind) {
    case HealthKind.bp:
      if (value2 == null) return 'கீழ் எண்ணையும் போடுங்கள்.';
      if (value < 60 || value > 260) {
        return 'மேல் எண் 60 முதல் 260-க்குள் இருக்கும். மீண்டும் பாருங்கள்.';
      }
      if (value2 < 30 || value2 > 160) {
        return 'கீழ் எண் 30 முதல் 160-க்குள் இருக்கும். மீண்டும் பாருங்கள்.';
      }
      if (value2 >= value) {
        return 'மேல் எண் கீழ் எண்ணை விடப் பெரியதாக இருக்கும். மாற்றிப் போட்டீர்களா?';
      }
      return null;
    case HealthKind.sugarFasting:
    case HealthKind.sugarAfterFood:
      if (value < 30 || value > 600) {
        return 'சர்க்கரை அளவு 30 முதல் 600-க்குள் இருக்கும். மீண்டும் பாருங்கள்.';
      }
      return null;
  }
}

/// Readings of [kind] in the last [days] days ending on [now], oldest first.
List<HealthEntry> healthSeries(
  List<HealthEntry> entries,
  HealthKind kind,
  DateTime now, {
  int days = 56,
}) {
  final from = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: days - 1));
  return entries
      .where(
        (e) => e.kind == kind && !e.at.isBefore(from) && !e.at.isAfter(now),
      )
      .toList()
    ..sort((a, b) => a.at.compareTo(b.at));
}

class HealthSummary {
  const HealthSummary({
    required this.count,
    this.avg,
    this.avg2,
    this.min,
    this.max,
    this.last,
  });
  final int count;
  final int? avg;
  final int? avg2;
  final int? min;
  final int? max;
  final HealthEntry? last;
}

/// For the doctor-visit page: count, average, range and latest reading.
HealthSummary summarise(List<HealthEntry> series) {
  if (series.isEmpty) return const HealthSummary(count: 0);
  final v = series.map((e) => e.value).toList();
  final v2 = series.map((e) => e.value2).whereType<int>().toList();
  int avgOf(List<int> xs) => (xs.reduce((a, b) => a + b) / xs.length).round();
  return HealthSummary(
    count: series.length,
    avg: avgOf(v),
    avg2: v2.isEmpty ? null : avgOf(v2),
    min: v.reduce((a, b) => a < b ? a : b),
    max: v.reduce((a, b) => a > b ? a : b),
    last: series.last,
  );
}

// ------------------------------------------------------------------ review

/// Numbers for the Sunday review with Appa (roadmap Phase 2 exit criteria).
class WeeklyReview {
  const WeeklyReview({
    required this.storiesThisWeek,
    required this.storiesTotal,
    required this.callsThisWeek,
    required this.walkthroughsDone,
    required this.realWorldDone,
    required this.questionsAnswered,
    required this.questionsWaiting,
    required this.sleepByWeek,
    required this.planDaysThisWeek,
  });

  final int storiesThisWeek;
  final int storiesTotal;
  final int callsThisWeek;
  final int walkthroughsDone;
  final int realWorldDone;
  final int questionsAnswered;
  final int questionsWaiting;

  /// Oldest first; each map counts good/okay/bad for one 7-day week.
  final List<Map<SleepRating, int>> sleepByWeek;

  /// Days in the last 7 with at least one plan item.
  final int planDaysThisWeek;
}

WeeklyReview weeklyReview({
  required DateTime now,
  required List<Story> stories,
  required List<CallEvent> calls,
  required Set<String> walkthroughsDone,
  required Set<String> realWorldDone,
  required List<FamilyQuestion> questions,
  required List<SleepEntry> sleep,
  required List<PlanItem> plan,
  int sleepWeeks = 4,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(const Duration(days: 6));
  bool inWeek(DateTime d) => !d.isBefore(weekStart);

  final sleepByWeek = <Map<SleepRating, int>>[];
  for (var w = sleepWeeks - 1; w >= 0; w--) {
    final end = today.subtract(Duration(days: 7 * w));
    final start = end.subtract(const Duration(days: 6));
    final counts = {for (final r in SleepRating.values) r: 0};
    for (final e in sleep) {
      final d = DateTime.parse(e.day);
      if (!d.isBefore(start) && !d.isAfter(end)) {
        counts[e.rating] = counts[e.rating]! + 1;
      }
    }
    sleepByWeek.add(counts);
  }

  final planDays = <String>{
    for (final p in plan)
      if (!DateTime.parse(p.day).isBefore(weekStart) &&
          !DateTime.parse(p.day).isAfter(today))
        p.day,
  };

  return WeeklyReview(
    storiesThisWeek: stories.where((s) => inWeek(s.createdAt)).length,
    storiesTotal: stories.length,
    callsThisWeek: calls
        .where((c) => c.outcome == CallOutcome.called && inWeek(c.at))
        .length,
    walkthroughsDone: walkthroughsDone.length,
    realWorldDone: realWorldDone.length,
    questionsAnswered: questions.where((q) => q.answered).length,
    questionsWaiting: questions.where((q) => !q.answered).length,
    sleepByWeek: sleepByWeek,
    planDaysThisWeek: planDays.length,
  );
}
