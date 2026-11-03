import 'package:appa_app/app_state.dart';
import 'package:appa_app/data/local_store.dart';
import 'package:appa_app/logic/phase3.dart';
import 'package:appa_app/logic/phase5.dart';
import 'package:appa_app/main.dart';
import 'package:appa_app/models/models.dart';
import 'package:appa_app/services/audio.dart';
import 'package:appa_app/services/band.dart';
import 'package:appa_app/services/companion_model.dart';
import 'package:appa_app/services/dictation.dart';
import 'package:appa_app/services/phone.dart';
import 'package:appa_app/services/reminders.dart';
import 'package:appa_app/services/speech.dart';
import 'package:appa_app/services/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BodySync extends NoFamilySync {
  final pushed = <({String day, int? sleepMinutes, bool? walked})>[];
  SharingSettings? sharing;
  @override
  bool get connected => true;
  @override
  Future<void> setSharing(SharingSettings s) async => sharing = s;
  @override
  Future<void> upsertBody(
    List<({String day, int? sleepMinutes, bool? walked})> rows,
  ) async => pushed.addAll(rows);
}

DateTime clock = DateTime(2026, 11, 10, 8, 0); // Tuesday morning

DateTime at(int day, int h, [int m = 0]) => DateTime(2026, 11, day, h, m);

/// Steps at 80 a minute for [mins] minutes, as 1-minute samples.
List<Span> walkSamples(DateTime start, int mins, [int perMin = 80]) => [
  for (var i = 0; i < mins; i++)
    Span(
      start.add(Duration(minutes: i)),
      start.add(Duration(minutes: i + 1)),
      perMin,
    ),
];

Future<AppState> makeState({
  Map<String, Object> prefs = const {'role': 'appa', 'displayName': 'அப்பா'},
  FamilySync? sync,
  BandReader? band,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  return AppState(
    store: await LocalStore.open(),
    speaker: SilentSpeaker(),
    audio: FakeVoiceAudio(),
    reminders: FakeReminders(),
    phone: FakePhone(),
    sync: sync ?? NoFamilySync(),
    dictation: FakeDictation(),
    sharer: FakeSharer(),
    companionModel: NoCompanionModel(),
    band: band,
    clock: () => clock,
  );
}

Future<void> pumpApp(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AppaApp(state: state));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// A band week: slept 22:30-05:30 most nights (with overlapping stage
/// spans), a 25-minute walk on the 8th and 9th, pottering on the 7th.
BandData bandWeek() => BandData(
  sleep: [
    for (var d = 4; d <= 10; d++) ...[
      Span(at(d - 1, 22, 30), at(d, 5, 30)),
      Span(at(d - 1, 23, 0), at(d, 2, 0)), // a stage inside the session
    ],
  ],
  steps: [
    ...walkSamples(at(8, 6, 30), 25),
    ...walkSamples(at(9, 17, 0), 25),
    ...walkSamples(at(7, 10, 0), 6), // too short to be a walk
    for (var i = 0; i < 30; i++)
      Span(at(6, 11, i), at(6, 11, i + 1), 15), // slow pottering
  ],
  resting: [(at: at(9, 6), bpm: 72), (at: at(9, 18), bpm: 70)],
);

void main() {
  setUp(() => clock = DateTime(2026, 11, 10, 8, 0));

  group('sleep from the band', () {
    test(
      'a night is the spans ending between noon and noon, overlaps merged',
      () {
        final n = nightFromSpans('2026-11-10', bandWeek().sleep)!;
        expect(n.minutes, 7 * 60);
        expect(n.bed, at(9, 22, 30));
        expect(n.wake, at(10, 5, 30));
        expect(nightFromSpans('2026-11-12', bandWeek().sleep), isNull);
      },
    );

    test('broken sleep adds up the pieces', () {
      final n = nightFromSpans('2026-11-10', [
        Span(at(9, 23), at(10, 1)),
        Span(at(10, 3), at(10, 6)),
      ])!;
      expect(n.minutes, 5 * 60);
    });

    test('band hours are evidence only when he gave no rating', () {
      const short = NightSleep(day: 'x', bandMinutes: 240);
      const long = NightSleep(day: 'x', bandMinutes: 420);
      expect(badNight(null, short), isTrue);
      expect(badNight(null, long), isFalse);
      expect(badNight(SleepRating.good, short), isFalse); // his word wins
      expect(badNight(SleepRating.bad, long), isTrue);
      expect(badNight(null, null), isFalse);
    });

    test('hours: his correction, else the band, else his taps', () {
      final n = NightSleep(day: 'x', selfBed: at(9, 22), selfWake: at(10, 6));
      expect(n.minutes, 480);
      expect(n.copyWith(bandMinutes: 400).minutes, 400);
      expect(n.copyWith(bandMinutes: 400).fromBand, isTrue);
      expect(n.copyWith(bandMinutes: 400, correctedMinutes: 360).minutes, 360);
      expect(hoursLabel(400), '6 மணி 40 நிமி');
    });

    test(
      'four short band nights with no ratings raise the bad-sleep pattern',
      () {
        final nights = [
          for (var d = 7; d <= 10; d++)
            NightSleep(
              day: '2026-11-${d.toString().padLeft(2, '0')}',
              bandMinutes: 230,
            ),
        ];
        final found = detectPatterns(
          now: clock,
          sleep: const [],
          calls: const [],
          contacts: const [],
          sessions: const [],
          alerts: const [],
          firstUse: null,
          nights: nights,
        );
        expect(found, {PatternKind.badSleep});
      },
    );
  });

  group('walking from the band', () {
    test('10+ minutes at an easy pace is a walk; short bursts and pottering are not', () {
      final walks = walksFromSteps(bandWeek().steps);
      expect(walks.length, 2);
      expect(walks.first.minutes, 25);
      expect(walks.first.steps, 2000);
    });

    test('short gaps (a pause to talk) join one walk', () {
      final w = walksFromSteps([
        ...walkSamples(at(8, 6), 6),
        ...walkSamples(at(8, 6, 9), 6),
      ]);
      expect(w.single.minutes, 15);
    });

    test('day activity, walk days and summaries', () {
      final days = [
        for (var d = 4; d <= 10; d++) '2026-11-${d.toString().padLeft(2, '0')}',
      ];
      final b = bandWeek();
      final act = dayActivities(days, b.steps, b.resting);
      expect(act.where((a) => a.walked).map((a) => a.day), [
        '2026-11-08',
        '2026-11-09',
      ]);
      expect(act.firstWhere((a) => a.day == '2026-11-09').restingHr, 71);
      expect(walkDays(clock, act), [
        false,
        false,
        false,
        false,
        true,
        true,
        false,
      ]);
      final nights = [
        for (final d in days)
          NightSleep(day: d, bandMinutes: nightFromSpans(d, b.sleep)!.minutes),
      ];
      final sum = bodySummary(clock, nights, act, days: 7);
      expect(sum.avgSleepHours, 7);
      expect(sum.walkDays, 2);
      expect(sum.bandNights, 7);
      expect(sum.avgRestingHr, 71);
      expect(sleepHoursSeries(clock, nights).length, 7);
    });

    test('walk items in the plan', () {
      expect(isWalkItem('காலை நடை'), isTrue);
      expect(isWalkItem('நடந்து கோயிலுக்கு'), isTrue);
      expect(isWalkItem('காலை நடை — முருகன்-உடன்'), isTrue);
      expect(isWalkItem('மாத்திரை'), isFalse);
    });
  });

  group('state', () {
    test('bed/wake taps: an evening bedtime is the night before', () async {
      final s = await makeState();
      await s.rateSleep(SleepRating.okay);
      expect(s.askSleepHours, isTrue);
      await s.setSelfSleepTimes(bedHour: 22, wakeHour: 6);
      expect(s.lastNight!.minutes, 480);
      await s.setSelfSleepTimes(bedHour: 0, wakeHour: 5);
      expect(s.lastNight!.minutes, 300);
      expect(s.askSleepHours, isFalse);
    });

    test('"not today" stops the hours question for the day only', () async {
      final s = await makeState();
      await s.rateSleep(SleepRating.good);
      await s.skipSleepHours();
      expect(s.askSleepHours, isFalse);
      clock = DateTime(2026, 11, 11, 8);
      await s.rateSleep(SleepRating.good);
      expect(s.askSleepHours, isTrue);
    });

    test('connect and read the band: nights, walks, plan auto-tick', () async {
      final band = FakeBand(data: bandWeek());
      final s = await makeState(band: band);
      clock = DateTime(2026, 11, 9, 7);
      await s.addPlanItem('காலை நடை');
      await s.addPlanItem('மாத்திரை');
      clock = DateTime(2026, 11, 10, 8);
      expect(await s.connectBand(), isTrue);
      expect(s.bandSettings.connectedSince, clock);
      expect(s.nightFor('2026-11-10')!.bandMinutes, 420);
      expect(s.activity.where((a) => a.walked).length, 2);
      final plan = s.planForDay('2026-11-09');
      expect(plan.firstWhere((p) => p.text == 'காலை நடை').done, isTrue);
      expect(plan.firstWhere((p) => p.text == 'மாத்திரை').done, isFalse);
      // His correction survives the next read.
      await s.correctNight('2026-11-10', 6 * 60);
      await s.syncBand();
      expect(s.nightFor('2026-11-10')!.minutes, 360);
    });

    test('family copy: only the columns he shares, nulls otherwise', () async {
      final sync = BodySync();
      final s = await makeState(
        sync: sync,
        band: FakeBand(data: bandWeek()),
      );
      await s.connectBand();
      expect(
        sync.pushed.every((r) => r.sleepMinutes == null && r.walked == null),
        isTrue,
      );
      sync.pushed.clear();
      await s.updateSharing(const SharingSettings(walk: true));
      final r9 = sync.pushed.lastWhere((r) => r.day == '2026-11-09');
      expect(r9.walked, isTrue);
      expect(r9.sleepMinutes, isNull);
      sync.pushed.clear();
      await s.updateSharing(
        const SharingSettings(walk: true, sleepHours: true),
      );
      expect(
        sync.pushed.lastWhere((r) => r.day == '2026-11-10').sleepMinutes,
        420,
      );
    });

    test('no walking suggestions until the doctor has cleared him', () async {
      final s = await makeState();
      expect(s.walkSuggestions, isEmpty);
      await s.updateBandSettings(
        s.bandSettings.copyWith(
          doctorCleared: true,
          doctorWords: 'தினமும் 15 நிமிடம் மெதுவாக',
        ),
      );
      expect(s.walkSuggestions, walkErrands);
      await s.planWalkWith(
        Contact(id: 'k', name: 'குமார்', phone: '1', nearby: true),
      );
      expect(s.planForDay(s.tomorrowKey).single.text, 'காலை நடை — குமார்-உடன்');
    });
  });

  group('screens', () {
    testWidgets('health screen: hours line and walk days, never a step count', (
      tester,
    ) async {
      final s = await makeState(band: FakeBand(data: bandWeek()));
      await s.connectBand();
      await s.updateBandSettings(
        s.bandSettings.copyWith(doctorWords: 'தினமும் 15 நிமிடம்'),
      );
      await pumpApp(tester, s);
      await tapText(tester, 'உடல்நலம்');
      await tester.ensureVisible(find.text('இந்த வாரம் நடந்த நாட்கள்'));
      expect(find.text('தூக்க நேரம் · கடந்த 8 வாரம் (மணி)'), findsOneWidget);
      expect(find.byIcon(Icons.directions_walk), findsNWidgets(2));
      expect(
        find.textContaining('மருத்துவர் சொன்னது: தினமும் 15 நிமிடம்'),
        findsOneWidget,
      );
      expect(find.textContaining('2000'), findsNothing);
      expect(find.textContaining('அடிகள்'), findsNothing);
    });

    testWidgets(
      'doctor page carries sleep, walk days, steps and resting heart rate',
      (tester) async {
        final s = await makeState(band: FakeBand(data: bandWeek()));
        await s.connectBand();
        await pumpApp(tester, s);
        await tapText(tester, 'உடல்நலம்');
        await tapText(tester, 'BP, சர்க்கரை');
        await tapText(tester, 'மருத்துவரிடம் காட்ட');
        expect(find.text('தூக்கமும் நடையும்'), findsOneWidget);
        expect(find.text('7.0 மணி'), findsOneWidget);
        expect(find.text('71 / நிமி'), findsOneWidget);
      },
    );

    testWidgets(
      'call screen: "walk together?" only for a nearby friend after the doctor says yes',
      (tester) async {
        final s = await makeState();
        await s.saveContact(
          Contact(id: 'k', name: 'குமார்', phone: '1', nearby: true),
        );
        await pumpApp(tester, s);
        await tapText(tester, 'இன்று யாரிடம் பேசலாம்');
        expect(find.textContaining('சேர்ந்து நடக்கலாமா'), findsNothing);
        await s.updateBandSettings(
          s.bandSettings.copyWith(doctorCleared: true),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('சேர்ந்து நடக்கலாமா'), findsOneWidget);
        await tapText(tester, 'நாளை காலை குமார்-உடன் நடை');
        expect(s.planForDay(s.tomorrowKey).single.text, contains('குமார்'));
      },
    );

    testWidgets('settings: connect the band through Health Connect', (
      tester,
    ) async {
      final band = FakeBand();
      final s = await makeState(band: band);
      await pumpApp(tester, s);
      await tapText(tester, 'குடும்பத்தினருக்கு: அமைப்புகள்');
      await tapText(tester, 'கைப்பட்டையை இணை');
      expect(band.connects, 1);
      expect(find.text('இணைக்கப்பட்டது.'), findsOneWidget);
    });

    testWidgets('sharing screen has the two new switches, off by default', (
      tester,
    ) async {
      final s = await makeState();
      await pumpApp(tester, s);
      await tapText(tester, 'குடும்பம் என்ன பார்க்கிறது');
      expect(find.text('நடை'), findsOneWidget);
      expect(find.text('தூக்க நேரம்'), findsOneWidget);
      expect(s.sharing.walk || s.sharing.sleepHours, isFalse);
    });
  });
}
