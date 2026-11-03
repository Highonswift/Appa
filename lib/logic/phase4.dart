import '../models/models.dart';
import 'phase2.dart' show isoWeek;

/// Pure Phase 4 rules. No I/O.

// ------------------------------------------------------------------ help others

/// What outside people can ask him about (roadmap: "vehicle trouble,
/// repairs, electrical work, how TNSTC or government offices actually work,
/// pension paperwork").
const helpTopics = <String>[
  'வண்டி / பைக்',
  'வீட்டுப் பழுது',
  'மின்சார வேலை',
  'அரசு / TNSTC அலுவலகம்',
  'ஓய்வூதியம்',
  'மற்றவை',
];

// ------------------------------------------------------------------ ledger

const _tamilNumbers = <String, int>{
  'பத்து': 10,
  'இருபது': 20,
  'முப்பது': 30,
  'நாற்பது': 40,
  'ஐம்பது': 50,
  'அறுபது': 60,
  'எழுபது': 70,
  'எண்பது': 80,
  'தொண்ணூறு': 90,
  'நூறு': 100,
  'இருநூறு': 200,
  'முந்நூறு': 300,
  'முன்னூறு': 300,
  'நானூறு': 400,
  'ஐநூறு': 500,
  'ஐந்நூறு': 500,
  'அறுநூறு': 600,
  'எழுநூறு': 700,
  'எண்ணூறு': 800,
  'தொள்ளாயிரம்': 900,
  'ஆயிரம்': 1000,
  'இரண்டாயிரம்': 2000,
  'ஐயாயிரம்': 5000,
};

const _fillers = {'ரூபாய்', 'ரூ', 'ரூ.', 'rs', 'rs.', '₹', 'க்கு', 'செலவு'};

/// Reads a spoken or typed ledger line such as "காய்கறி 200", "200 ரூபாய்
/// பால்", "பால் ஐம்பது ரூபாய்" or "₹1,500 கரண்ட் பில்". Returns null when
/// no amount or no item can be found, so the screen can ask again.
({String item, int amount})? parseLedgerUtterance(String raw) {
  var text = raw
      .replaceAll('₹', ' ₹ ')
      .replaceAll(RegExp(r'(?<=\d),(?=\d)'), '');
  int? amount;
  final words = <String>[];
  for (final w in text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
    final digits = RegExp(r'^\d+$').firstMatch(w);
    final lower = w.toLowerCase();
    if (amount == null && digits != null) {
      amount = int.parse(w);
    } else if (amount == null && _tamilNumbers.containsKey(w)) {
      amount = _tamilNumbers[w];
    } else if (!_fillers.contains(lower)) {
      words.add(w);
    }
  }
  final item = words.join(' ').trim();
  if (amount == null || amount <= 0 || item.isEmpty) return null;
  return (item: item, amount: amount);
}

class MonthLedger {
  const MonthLedger({
    required this.total,
    required this.byItem,
    required this.entries,
  });
  final int total;

  /// Item → total, largest first.
  final List<MapEntry<String, int>> byItem;
  final List<LedgerEntry> entries;
}

MonthLedger ledgerForMonth(List<LedgerEntry> all, int year, int month) {
  final entries =
      all.where((e) => e.at.year == year && e.at.month == month).toList()
        ..sort((a, b) => b.at.compareTo(a.at));
  final by = <String, int>{};
  for (final e in entries) {
    by[e.item] = (by[e.item] ?? 0) + e.amount;
  }
  final sorted = by.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return MonthLedger(
    total: entries.fold(0, (n, e) => n + e.amount),
    byItem: sorted,
    entries: entries,
  );
}

// ------------------------------------------------------------------ events

/// Events from today on, soonest first.
List<LocalEvent> upcomingEvents(List<LocalEvent> events, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return events.where((e) => !e.startsAt.isBefore(today)).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
}

/// Past events he hasn't said whether he went to (last 14 days). [answered]
/// holds ids he already answered ("I went" or "no"), so he is asked once.
List<LocalEvent> eventsToAskAbout(
  List<LocalEvent> events,
  DateTime now, {
  Set<String> answered = const {},
}) {
  final today = DateTime(now.year, now.month, now.day);
  return events
      .where(
        (e) =>
            e.startsAt.isBefore(today) &&
            e.startsAt.isAfter(today.subtract(const Duration(days: 14))),
      )
      .where((e) => !e.attended && !answered.contains(e.id))
      .toList()
    ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
}

/// The invite text he can send a friend.
String eventInvite(LocalEvent e, String from) {
  final d = e.startsAt;
  final time =
      '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return '${e.title} — ${e.place}, $time. நானும் போகிறேன், வருகிறீர்களா?\n— $from';
}

// ------------------------------------------------------------------ circle

/// ISO week key such as "2026-W45" (the ISO year, not the calendar year).
String weekKey(DateTime d) {
  final date = DateTime.utc(d.year, d.month, d.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  return '${thursday.year}-W${isoWeek(d).toString().padLeft(2, '0')}';
}

/// The weekly voice prompt everyone in the retirees circle answers
/// (roadmap: "a weekly voice prompt everyone answers, a shared archive of
/// depot stories"). The same for every member in the same week.
const circlePrompts = <String>[
  'உங்கள் முதல் டிப்போ எது? அங்கே முதல் நாள் எப்படி இருந்தது?',
  'நீங்கள் ஓட்டிய அல்லது பராமரித்த பஸ்களில் மறக்க முடியாதது எது?',
  'நள்ளிரவில் வழியில் பஸ் நின்றுபோன ஒரு அனுபவம் சொல்லுங்கள்.',
  'டிப்போவில் எல்லோருக்கும் பிடித்த ஒரு அண்ணன் அல்லது அதிகாரி யார்? ஏன்?',
  'மழைக்காலத்தில் வேலை செய்த ஒரு நினைவு சொல்லுங்கள்.',
  'டிப்போ கேண்டீனில் கிடைத்த மிகச் சிறந்த சாப்பாடு எது?',
  'வேலையில் நீங்கள் கற்றுக்கொண்ட முக்கியமான ஒரு கைத்தொழில் ரகசியம் என்ன?',
  'பண்டிகை நாளில் டியூட்டி பார்த்த ஒரு அனுபவம் சொல்லுங்கள்.',
  'பயணிகளில் யாராவது மறக்க முடியாதவர் உண்டா?',
  'பழைய என்ஜினுக்கும் இப்போதைய என்ஜினுக்கும் என்ன வித்தியாசம்?',
  'சக ஊழியர்கள் சேர்ந்து செய்த ஒரு குறும்பு அல்லது விளையாட்டு சொல்லுங்கள்.',
  'வேலையில் உங்களுக்குக் கிடைத்த ஒரு பாராட்டு அல்லது பரிசு பற்றிச் சொல்லுங்கள்.',
  'புதிதாகச் சேர்ந்த இளைஞருக்கு நீங்கள் சொல்லிக்கொடுத்த ஒன்று என்ன?',
  'ஓய்வுக்குப் பிறகு நீங்கள் தொடங்கிய ஒரு பழக்கம் என்ன?',
  'டிப்போவில் இப்போதும் நினைவில் இருக்கும் ஒரு வாசனை அல்லது சத்தம் என்ன?',
  'உங்கள் ஊர் ரூட்டில் இப்போது என்ன மாறியிருக்கிறது?',
];

String circlePromptFor(DateTime d) {
  final weekIndex =
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      (7 * 86400000);
  return circlePrompts[weekIndex % circlePrompts.length];
}

/// Circle members with a birthday in the next 7 days (including today).
List<({CircleMember member, int inDays})> circleBirthdays(
  List<CircleMember> members,
  DateTime now,
) {
  final out = <({CircleMember member, int inDays})>[];
  final today = DateTime(now.year, now.month, now.day);
  for (var i = 0; i < 7; i++) {
    final d = today.add(Duration(days: i));
    for (final m in members) {
      if (m.birthdayMonth == d.month && m.birthdayDay == d.day) {
        out.add((member: m, inDays: i));
      }
    }
  }
  return out;
}

// ------------------------------------------------------------------ review

class PurposeReview {
  const PurposeReview({
    required this.outsideAnswered,
    required this.outsideWaiting,
    required this.eventsAttended,
    required this.repairsThisMonth,
    required this.repairsTotal,
    required this.ledgerEntriesThisMonth,
  });

  final int outsideAnswered;
  final int outsideWaiting;
  final int eventsAttended;
  final int repairsThisMonth;
  final int repairsTotal;
  final int ledgerEntriesThisMonth;
}

PurposeReview purposeReview({
  required DateTime now,
  required List<FamilyQuestion> questions,
  required List<LocalEvent> events,
  required List<RepairEntry> repairs,
  required List<LedgerEntry> ledger,
}) => PurposeReview(
  outsideAnswered: questions.where((q) => q.outside && q.answered).length,
  outsideWaiting: questions.where((q) => q.outside && !q.answered).length,
  eventsAttended: events.where((e) => e.attended).length,
  repairsThisMonth: repairs
      .where((r) => r.at.year == now.year && r.at.month == now.month)
      .length,
  repairsTotal: repairs.length,
  ledgerEntriesThisMonth: ledger
      .where((e) => e.at.year == now.year && e.at.month == now.month)
      .length,
);
