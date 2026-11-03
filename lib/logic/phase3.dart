import '../data/festivals.dart';
import '../models/models.dart';

/// Pure Phase 3 rules: who to suggest, which occasions are coming, which
/// follow-up becomes today's question, which patterns to raise with him, and
/// the guard-rails the companion's replies pass through. No I/O.

// ------------------------------------------------------------------ calls

/// Who to suggest calling today, tuned by his "Good call?" answers.
///
/// Score = days since last call (never called counts as 365), +2 for each
/// "good" call with that person in the last 90 days (max +6), −4 for each
/// "not good". Highest score first; ties keep list order. Still one
/// suggestion a day: null once he has called or said "not today".
Contact? tunedContactForDay(
  DateTime day,
  List<Contact> contacts,
  List<CallEvent> history,
) {
  if (contacts.isEmpty) return null;
  final today = dayKey(day);
  if (history.any((e) => e.day == today)) return null;
  final since = day.subtract(const Duration(days: 90));

  int score(Contact c) {
    final stale = c.lastCalled == null
        ? 365
        : day.difference(c.lastCalled!).inDays;
    final recent = history.where(
      (e) => e.contactId == c.id && e.at.isAfter(since),
    );
    final good = recent.where((e) => e.rating == CallRating.good).length;
    final bad = recent.where((e) => e.rating == CallRating.notGood).length;
    return stale + (2 * good).clamp(0, 6) - 4 * bad;
  }

  final ordered = [...contacts];
  final scores = {for (final c in contacts) c.id: score(c)};
  ordered.sort((a, b) {
    final d = scores[b.id]!.compareTo(scores[a.id]!);
    return d != 0 ? d : contacts.indexOf(a).compareTo(contacts.indexOf(b));
  });
  return ordered.first;
}

/// The latest call today he hasn't rated yet, if any (asked once, skippable).
CallEvent? unratedCallToday(DateTime day, List<CallEvent> history) {
  final today = dayKey(day);
  for (final e in history.reversed) {
    if (e.day == today && e.outcome == CallOutcome.called) {
      return e.rating == null ? e : null;
    }
  }
  return null;
}

// ------------------------------------------------------------------ occasions

enum OccasionKind { birthday, festival }

class Occasion {
  const Occasion({
    required this.kind,
    required this.title,
    required this.daysAway,
    this.contact,
    this.festival,
    this.suggested = const [],
  });

  final OccasionKind kind;
  final String title;

  /// 0 = today, 1 = tomorrow.
  final int daysAway;
  final Contact? contact;
  final Festival? festival;

  /// For festivals: a few people to greet.
  final List<Contact> suggested;

  /// What he sees on the home screen.
  String get line => switch ((kind, daysAway)) {
    (OccasionKind.birthday, 0) => 'இன்று ${contact!.name}-இன் பிறந்தநாள்',
    (OccasionKind.birthday, _) => 'நாளை ${contact!.name}-இன் பிறந்தநாள்',
    (OccasionKind.festival, 0) => 'இன்று $title',
    (OccasionKind.festival, _) => 'நாளை $title',
  };
}

/// Birthdays and festivals today and tomorrow, birthdays first.
List<Occasion> upcomingOccasions(DateTime now, List<Contact> contacts) {
  final out = <Occasion>[];
  for (final away in [0, 1]) {
    final d = DateTime(now.year, now.month, now.day).add(Duration(days: away));
    for (final c in contacts.where((c) => c.hasBirthday)) {
      if (c.birthdayMonth == d.month && c.birthdayDay == d.day) {
        out.add(
          Occasion(
            kind: OccasionKind.birthday,
            title: c.name,
            daysAway: away,
            contact: c,
          ),
        );
      }
    }
  }
  for (final away in [0, 1]) {
    final d = DateTime(now.year, now.month, now.day).add(Duration(days: away));
    for (final f in festivals.where((f) => f.on(d))) {
      final greet = [...contacts.where((c) => c.group != ContactGroup.family)]
        ..sort(
          (a, b) => (a.lastCalled ?? DateTime(2000)).compareTo(
            b.lastCalled ?? DateTime(2000),
          ),
        );
      out.add(
        Occasion(
          kind: OccasionKind.festival,
          title: f.name,
          daysAway: away,
          festival: f,
          suggested: greet.take(3).toList(),
        ),
      );
    }
  }
  return out;
}

// ------------------------------------------------------------------ follow-ups

/// The follow-up question to ask today: one already given today, else the
/// oldest unused one. [assign] is true when the caller must mark it used.
({StoryFollowUp? followUp, bool assign}) followUpForDay(
  String today,
  List<StoryFollowUp> all,
) {
  for (final f in all) {
    if (f.usedOnDay == today) return (followUp: f, assign: false);
  }
  // Only follow-ups from before today: they become the *next* day's question.
  final unused =
      all
          .where(
            (f) =>
                f.usedOnDay == null && dayKey(f.createdAt).compareTo(today) < 0,
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return unused.isEmpty
      ? (followUp: null, assign: false)
      : (followUp: unused.first, assign: true);
}

// ------------------------------------------------------------------ patterns

/// Patterns to raise with him today, skipping any raised in the last 7 days.
///
/// - badSleep: he rated the last 4 nights (ending today or yesterday) all bad.
/// - lowMood: the companion noticed "unwanted" or "angry" in 3+ sessions in
///   the last 7 days.
/// - noCalls: no call in 7 days, he has people in his list, and the app has
///   been in use for over a week (so a fresh install never fires).
Set<PatternKind> detectPatterns({
  required DateTime now,
  required List<SleepEntry> sleep,
  required List<CallEvent> calls,
  required List<Contact> contacts,
  required List<CompanionSessionLog> sessions,
  required List<PatternAlert> alerts,
  required DateTime? firstUse,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final found = <PatternKind>{};

  bool badRun(DateTime end) {
    for (var i = 0; i < 4; i++) {
      final key = dayKey(end.subtract(Duration(days: i)));
      final e = sleep.where((s) => s.day == key);
      if (e.isEmpty || e.last.rating != SleepRating.bad) return false;
    }
    return true;
  }

  if (badRun(today) || badRun(today.subtract(const Duration(days: 1)))) {
    found.add(PatternKind.badSleep);
  }

  final weekAgo = now.subtract(const Duration(days: 7));
  final moody = sessions
      .where((s) => s.start.isAfter(weekAgo))
      .where(
        (s) =>
            s.feelings.contains(Feeling.unwanted) ||
            s.feelings.contains(Feeling.angry),
      )
      .length;
  if (moody >= 3) found.add(PatternKind.lowMood);

  final called = calls.any(
    (c) => c.outcome == CallOutcome.called && c.at.isAfter(weekAgo),
  );
  if (!called &&
      contacts.isNotEmpty &&
      firstUse != null &&
      firstUse.isBefore(weekAgo)) {
    found.add(PatternKind.noCalls);
  }

  final recent = alerts
      .where(
        (a) =>
            !DateTime.parse(a.noticedOn)
                .isBefore(today.subtract(const Duration(days: 7))),
      )
      .map((a) => a.kind)
      .toSet();
  return found.difference(recent);
}

/// What the app asks him first, in his words.
String alertQuestion(PatternKind k, String recipient) => switch (k) {
  PatternKind.badSleep =>
    'நான்கு இரவுகளாகத் தூக்கம் சரியில்லை என்று சொன்னீர்கள். $recipient-இடம் சொல்லலாமா? அவர் உங்களை அழைப்பார்.',
  PatternKind.lowMood =>
    'சில நாட்களாக மனம் சரியில்லை போலத் தெரிகிறது. $recipient-இடம் சொல்லலாமா? அவர் உங்களை அழைப்பார்.',
  PatternKind.noCalls =>
    'ஒரு வாரமாக யாரிடமும் போனில் பேசவில்லை. $recipient-இடம் சொல்லலாமா?',
};

/// The short note the family receives. A sentence, never a transcript.
String alertNote(PatternKind k, String appaName) => switch (k) {
  PatternKind.badSleep =>
    '$appaName நான்கு இரவுகளாக நன்றாகத் தூங்கவில்லை என்று சொன்னார். இன்று அவரை அழைத்துப் பேசலாம்.',
  PatternKind.lowMood =>
    '$appaName சில நாட்களாக மனம் சரியில்லாமல் இருக்கிறார் போலத் தெரிகிறது. இன்று அவரை அழைத்துப் பேசலாம்.',
  PatternKind.noCalls =>
    '$appaName ஒரு வாரமாக யாரிடமும் போனில் பேசவில்லை. இன்று அவரை அழைக்கலாம்.',
};

const patternNames = {
  PatternKind.badSleep: 'தொடர்ந்து தூக்கம் சரியில்லாதபோது',
  PatternKind.lowMood: 'மனம் சரியில்லாதது போலத் தெரிந்தால்',
  PatternKind.noCalls: 'ஒரு வாரம் யாரிடமும் பேசாதபோது',
};

// ------------------------------------------------------------------ companion guard-rails

/// Phrases the companion must never use: affection, friendship, missing him,
/// guilt (roadmap: "never claims to be a friend, never says it misses him,
/// never uses guilt or affection to bring him back").
const _forbidden = <String>[
  'மிஸ் பண்ண',
  'மிஸ் செய்',
  'உங்களை நேசிக்கிறேன்',
  'உங்களை விரும்புகிறேன்',
  'உங்கள் நண்பன்',
  'உங்கள் நண்பர் நான்',
  'நான் உங்கள் நண்பர்',
  'உங்கள் தோழன்',
  'நான் உங்கள் தோழன்',
  'என்னை விட்டுப் போகாதீர்கள்',
  'என்னோடு இருங்கள்',
  'திரும்ப வாருங்கள்',
  'நான் காத்திருப்பேன்',
  'உங்களுக்காகக் காத்திருக்கிறேன்',
  'i miss you',
  'love you',
  'your friend',
  'come back',
  'i\'ll be waiting',
];

/// Removes any sentence containing a forbidden phrase. Returns null if
/// nothing acceptable is left (the caller then uses a neutral line).
String? sanitizeReply(String reply) {
  final sentences = reply.split(RegExp(r'(?<=[.!?।])\s+'));
  final kept = sentences.where((s) {
    final low = s.toLowerCase();
    return !_forbidden.any((f) => low.contains(f.toLowerCase()));
  }).toList();
  final out = kept.join(' ').trim();
  return out.isEmpty ? null : out;
}

bool containsForbidden(String text) {
  final low = text.toLowerCase();
  return _forbidden.any((f) => low.contains(f.toLowerCase()));
}

enum SessionPhase { normal, wrapUp, over }

/// Soft limit: wrap up in the last 2 minutes, end at the limit.
SessionPhase sessionPhase(Duration elapsed, int limitMinutes) {
  final limit = Duration(minutes: limitMinutes);
  if (elapsed >= limit) return SessionPhase.over;
  if (elapsed >= limit - const Duration(minutes: 2)) return SessionPhase.wrapUp;
  return SessionPhase.normal;
}

/// "Every few exchanges it steers outward": due on the 3rd reply without a
/// suggestion.
bool steeringDue(int repliesSinceSuggestion) => repliesSinceSuggestion >= 2;

// ------------------------------------------------------------------ review

class CompanionStats {
  const CompanionStats({
    required this.sessionsThisWeek,
    required this.avgMinutesThisWeek,
    required this.avgMinutesLastWeek,
    required this.outwardShare,
  });

  final int sessionsThisWeek;
  final double avgMinutesThisWeek;
  final double avgMinutesLastWeek;

  /// Fraction of this week's sessions that ended in a call, story or plan.
  final double outwardShare;

  /// Stop-and-rethink signal: sessions getting longer week over week.
  bool get lengthening =>
      sessionsThisWeek > 0 &&
      avgMinutesLastWeek > 0 &&
      avgMinutesThisWeek > avgMinutesLastWeek * 1.2;
}

CompanionStats companionStats(
  DateTime now,
  List<CompanionSessionLog> sessions,
) {
  final weekAgo = now.subtract(const Duration(days: 7));
  final twoWeeksAgo = now.subtract(const Duration(days: 14));
  final thisWeek = sessions.where((s) => s.start.isAfter(weekAgo)).toList();
  final lastWeek = sessions
      .where((s) => s.start.isAfter(twoWeeksAgo) && !s.start.isAfter(weekAgo))
      .toList();
  double avg(List<CompanionSessionLog> xs) => xs.isEmpty
      ? 0
      : xs.map((s) => s.length.inSeconds / 60).reduce((a, b) => a + b) /
            xs.length;
  return CompanionStats(
    sessionsThisWeek: thisWeek.length,
    avgMinutesThisWeek: avg(thisWeek),
    avgMinutesLastWeek: avg(lastWeek),
    outwardShare: thisWeek.isEmpty
        ? 0
        : thisWeek.where((s) => s.outward != OutwardAction.none).length /
              thisWeek.length,
  );
}
