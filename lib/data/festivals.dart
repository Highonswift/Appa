/// Festivals he might call people for. A greeting nudge shows the day before
/// and on the day (roadmap: "Birthdays and festival greetings are prompted a
/// day early"). No notification is added for this: it appears on his home
/// screen, which keeps the app at three notifications a day.
///
/// Fixed-date festivals repeat every year. Lunar ones move, so they are
/// listed per year; the dates below are approximate and the team should
/// check them against a Tamil panchangam each year and add the next year.
class Festival {
  const Festival(this.name, this.month, this.day, {this.year, this.greeting});
  final String name;
  final int month;
  final int day;

  /// Null for the same date every year.
  final int? year;

  /// What to say, e.g. "இனிய பொங்கல் நல்வாழ்த்துகள்".
  final String? greeting;

  bool on(DateTime d) =>
      d.month == month && d.day == day && (year == null || year == d.year);
}

const festivals = <Festival>[
  Festival(
    'தமிழ்ப் புத்தாண்டு',
    4,
    14,
    greeting: 'இனிய தமிழ்ப் புத்தாண்டு நல்வாழ்த்துகள்',
  ),
  Festival('கிறிஸ்துமஸ்', 12, 25, greeting: 'கிறிஸ்துமஸ் நல்வாழ்த்துகள்'),
  Festival(
    'ஆங்கிலப் புத்தாண்டு',
    1,
    1,
    greeting: 'இனிய புத்தாண்டு நல்வாழ்த்துகள்',
  ),
  // 2026 (approximate; verify)
  Festival(
    'பொங்கல்',
    1,
    14,
    year: 2026,
    greeting: 'இனிய பொங்கல் நல்வாழ்த்துகள்',
  ),
  Festival('ரம்ஜான்', 3, 21, year: 2026, greeting: 'ரம்ஜான் நல்வாழ்த்துகள்'),
  Festival(
    'விநாயகர் சதுர்த்தி',
    9,
    14,
    year: 2026,
    greeting: 'விநாயகர் சதுர்த்தி நல்வாழ்த்துகள்',
  ),
  Festival(
    'ஆயுத பூஜை',
    10,
    19,
    year: 2026,
    greeting: 'ஆயுத பூஜை நல்வாழ்த்துகள்',
  ),
  Festival(
    'தீபாவளி',
    11,
    8,
    year: 2026,
    greeting: 'இனிய தீபாவளி நல்வாழ்த்துகள்',
  ),
  Festival(
    'கார்த்திகை தீபம்',
    11,
    24,
    year: 2026,
    greeting: 'கார்த்திகை தீப நல்வாழ்த்துகள்',
  ),
  // 2027 (approximate; verify)
  Festival(
    'பொங்கல்',
    1,
    15,
    year: 2027,
    greeting: 'இனிய பொங்கல் நல்வாழ்த்துகள்',
  ),
  Festival('ரம்ஜான்', 3, 10, year: 2027, greeting: 'ரம்ஜான் நல்வாழ்த்துகள்'),
  Festival(
    'தீபாவளி',
    10,
    29,
    year: 2027,
    greeting: 'இனிய தீபாவளி நல்வாழ்த்துகள்',
  ),
];
