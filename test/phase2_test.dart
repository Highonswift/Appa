import 'package:appa_app/app_state.dart';
import 'package:appa_app/data/local_store.dart';
import 'package:appa_app/data/scam_stories.dart';
import 'package:appa_app/logic/phase2.dart';
import 'package:appa_app/main.dart';
import 'package:appa_app/models/models.dart';
import 'package:appa_app/services/audio.dart';
import 'package:appa_app/services/dictation.dart';
import 'package:appa_app/services/phone.dart';
import 'package:appa_app/services/reminders.dart';
import 'package:appa_app/services/speech.dart';
import 'package:appa_app/services/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A connected sync that records what would have left the phone.
class RecordingSync extends NoFamilySync {
  final calls = <String>[];
  SharingSettings? sharing;
  List<PlanItem> pendingRequests = [];
  List<FamilyQuestion> remoteQuestions = [];

  @override
  bool get connected => true;
  @override
  String? get householdCode => 'ABC123';
  @override
  Future<void> setSharing(SharingSettings s) async {
    sharing = s;
    calls.add('setSharing h=${s.health} s=${s.sleep} p=${s.plan}');
    if (!s.health) calls.add('clear health');
    if (!s.sleep) calls.add('clear sleep');
    if (!s.plan) calls.add('clear plan');
  }

  @override
  Future<void> upsertHealth(List<HealthEntry> entries) async =>
      calls.add('upsertHealth ${entries.length}');
  @override
  Future<void> upsertSleep(List<SleepEntry> entries) async =>
      calls.add('upsertSleep ${entries.length}');
  @override
  Future<void> upsertPlan(List<PlanItem> items) async =>
      calls.add('upsertPlan ${items.length}');
  @override
  Future<List<PlanItem>> takePlanRequests() async {
    final r = pendingRequests;
    pendingRequests = [];
    return r;
  }

  @override
  Future<List<FamilyQuestion>> fetchQuestions() async => remoteQuestions;
  @override
  Future<String> answerQuestion({
    required String questionId,
    required String localPath,
  }) async {
    calls.add('answer $questionId');
    return 'hh/answers/$questionId.m4a';
  }
}

DateTime clock = DateTime(2026, 11, 2, 9, 0); // a Monday

Future<AppState> makeState({
  Map<String, Object> prefs = const {'role': 'appa', 'displayName': 'அப்பா'},
  FamilySync? sync,
  Sharer? sharer,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  return AppState(
    store: await LocalStore.open(),
    speaker: SilentSpeaker(),
    audio: FakeVoiceAudio(),
    reminders: FakeReminders(),
    phone: FakePhone(),
    sync: sync ?? NoFamilySync(),
    dictation: FakeDictation('கோயில்'),
    sharer: sharer ?? FakeSharer(),
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

void main() {
  setUp(() => clock = DateTime(2026, 11, 2, 9, 0));

  group('rules', () {
    test('ISO week', () {
      expect(isoWeek(DateTime(2026, 1, 1)), 1);
      expect(isoWeek(DateTime(2026, 12, 31)), 53);
      expect(isoWeek(DateTime(2026, 11, 2)), 45);
    });

    test('scam story is stable for a week and changes the next', () {
      final mon = scamForWeek(DateTime(2026, 11, 5)); // Thu
      final sameWeek = scamForWeek(DateTime(2026, 11, 7));
      final next = scamForWeek(DateTime(2026, 11, 13));
      expect(mon.id, sameWeek.id);
      expect(next.id, isNot(mon.id));
      final archive = scamArchive(DateTime(2026, 11, 5));
      expect(archive.map((s) => s.id).toSet().length, archive.length);
      expect(archive.first.id, mon.id);
      expect(scamStories.map((s) => s.id).toSet().length, scamStories.length);
    });

    test('family may add one plan item a day each', () {
      final items = [
        PlanItem(
          id: '1',
          day: '2026-11-02',
          text: 'காய்கறி',
          createdAt: clock,
          addedBy: 'அம்மா',
        ),
      ];
      expect(familyCanAdd('அம்மா', '2026-11-02', items), isFalse);
      expect(familyCanAdd('ராகுல்', '2026-11-02', items), isTrue);
      expect(familyCanAdd('அம்மா', '2026-11-03', items), isTrue);
    });

    test('health validation catches typos, never judges', () {
      expect(validateHealth(HealthKind.bp, 130, 85), isNull);
      expect(
        validateHealth(HealthKind.bp, 85, 130),
        contains('மாற்றி'),
      ); // swapped
      expect(validateHealth(HealthKind.bp, 1300, 85), isNotNull);
      expect(validateHealth(HealthKind.bp, 130, null), isNotNull);
      expect(validateHealth(HealthKind.sugarFasting, 110, null), isNull);
      expect(validateHealth(HealthKind.sugarAfterFood, 5, null), isNotNull);
      expect(validateHealth(HealthKind.sugarFasting, null, null), isNotNull);
      // A high-but-possible reading is accepted without comment.
      expect(validateHealth(HealthKind.bp, 190, 110), isNull);
    });

    test('health series window and summary', () {
      final e = [
        HealthEntry(
          id: 'a',
          at: DateTime(2026, 9, 1),
          kind: HealthKind.bp,
          value: 150,
          value2: 95,
        ),
        HealthEntry(
          id: 'b',
          at: DateTime(2026, 10, 20),
          kind: HealthKind.bp,
          value: 140,
          value2: 90,
        ),
        HealthEntry(
          id: 'c',
          at: DateTime(2026, 11, 1),
          kind: HealthKind.bp,
          value: 130,
          value2: 80,
        ),
        HealthEntry(
          id: 'd',
          at: DateTime(2026, 11, 1),
          kind: HealthKind.sugarFasting,
          value: 110,
        ),
      ];
      final bp30 = healthSeries(e, HealthKind.bp, clock, days: 30);
      expect(bp30.map((x) => x.id), ['b', 'c']);
      final sum = summarise(bp30);
      expect(sum.count, 2);
      expect(sum.avg, 135);
      expect(sum.avg2, 85);
      expect(sum.last!.id, 'c');
      expect(summarise(const []).count, 0);
    });

    test('weekly review counts the last seven days', () {
      final r = weeklyReview(
        now: clock,
        stories: [
          Story(
            id: '1',
            promptId: 'p',
            promptText: 'q',
            createdAt: DateTime(2026, 11, 1),
          ),
          Story(
            id: '2',
            promptId: 'p',
            promptText: 'q',
            createdAt: DateTime(2026, 10, 1),
          ),
        ],
        calls: [
          CallEvent(
            day: '2026-10-30',
            contactId: 'm',
            outcome: CallOutcome.called,
            at: DateTime(2026, 10, 30),
          ),
          CallEvent(
            day: '2026-10-31',
            contactId: 'm',
            outcome: CallOutcome.notToday,
            at: DateTime(2026, 10, 31),
          ),
        ],
        walkthroughsDone: {'a', 'b'},
        realWorldDone: {'a'},
        questions: [
          FamilyQuestion(
            id: 'q',
            authorName: 'அம்மா',
            createdAt: clock,
            text: '?',
            answeredAt: clock,
          ),
          FamilyQuestion(
            id: 'r',
            authorName: 'அம்மா',
            createdAt: clock,
            text: '?',
          ),
        ],
        sleep: [
          SleepEntry(
            day: '2026-11-02',
            rating: SleepRating.good,
            recordedAt: clock,
          ),
          SleepEntry(
            day: '2026-10-01',
            rating: SleepRating.bad,
            recordedAt: clock,
          ),
        ],
        plan: [
          PlanItem(id: 'x', day: '2026-11-01', text: 'நடை', createdAt: clock),
        ],
      );
      expect(r.storiesThisWeek, 1);
      expect(r.storiesTotal, 2);
      expect(r.callsThisWeek, 1);
      expect(r.realWorldDone, 1);
      expect(r.questionsAnswered, 1);
      expect(r.questionsWaiting, 1);
      expect(r.planDaysThisWeek, 1);
      expect(r.sleepByWeek.length, 4);
      expect(r.sleepByWeek.last[SleepRating.good], 1);
    });
  });

  group('consent', () {
    test(
      'nothing about health, sleep or plan leaves the phone until he shares it',
      () async {
        final sync = RecordingSync();
        final s = await makeState(sync: sync);
        await s.addHealth(HealthKind.bp, 130, 85);
        await s.rateSleep(SleepRating.good);
        await s.addPlanItem('நடை');
        expect(sync.calls.where((c) => c.startsWith('upsert')), isEmpty);

        await s.updateSharing(const SharingSettings(health: true));
        expect(sync.calls, contains('upsertHealth 1'));
        expect(
          sync.calls.where(
            (c) => c.startsWith('upsertSleep') || c.startsWith('upsertPlan'),
          ),
          isEmpty,
        );

        sync.calls.clear();
        await s.addHealth(HealthKind.sugarFasting, 110);
        expect(sync.calls, ['upsertHealth 1']);
      },
    );

    test('turning sharing off clears the family copy', () async {
      final sync = RecordingSync();
      final s = await makeState(sync: sync);
      await s.updateSharing(const SharingSettings(health: true, sleep: true));
      sync.calls.clear();
      await s.updateSharing(const SharingSettings(health: false, sleep: true));
      expect(sync.calls, contains('clear health'));
      expect(sync.calls, isNot(contains('clear sleep')));
      expect(s.store.sharing.health, isFalse);
    });

    test('plan requests arrive as requests, one per person per day', () async {
      final sync = RecordingSync();
      final s = await makeState(sync: sync);
      sync.pendingRequests = [
        PlanItem(
          id: 'r1',
          day: '2026-11-02',
          text: 'காய்கறி வாங்குவது',
          createdAt: clock,
          addedBy: 'அம்மா',
        ),
        PlanItem(
          id: 'r2',
          day: '2026-11-02',
          text: 'இன்னொன்று',
          createdAt: clock,
          addedBy: 'அம்மா',
        ),
      ];
      await s.pullPhase2();
      final today = s.planForDay('2026-11-02');
      expect(today.length, 1);
      expect(today.single.addedBy, 'அம்மா');
    });

    test('remote questions come in; answers go back', () async {
      final sync = RecordingSync()
        ..remoteQuestions = [
          FamilyQuestion(
            id: 'q1',
            authorName: 'ராகுல்',
            createdAt: clock,
            text: 'பைக் சத்தம்?',
          ),
        ];
      final s = await makeState(sync: sync);
      await s.pullPhase2();
      expect(s.unansweredQuestions, 1);
      await s.answerQuestion('q1', '/fake/a.m4a');
      expect(s.unansweredQuestions, 0);
      expect(sync.calls, contains('answer q1'));
      expect(s.questions.single.answerRemotePath, 'hh/answers/q1.m4a');
    });
  });

  group('state', () {
    test(
      'plan: add, tick, repeat yesterday skips family requests and duplicates',
      () async {
        final s = await makeState();
        clock = DateTime(2026, 11, 1, 8);
        await s.addPlanItem('காலை நடை');
        await s.addFamilyPlanItem(author: 'அம்மா', text: 'காய்கறி');
        clock = DateTime(2026, 11, 2, 8);
        await s.addPlanItem('காலை நடை');
        expect(await s.repeatYesterday(s.todayKey), 0);
        await s.removePlanItem(s.planForDay(s.todayKey).single.id);
        expect(await s.repeatYesterday(s.todayKey), 1);
        final id = s.planForDay(s.todayKey).single.id;
        await s.togglePlanItem(id);
        expect(s.planForDay(s.todayKey).single.done, isTrue);
        expect(await s.addFamilyPlanItem(author: 'அம்மா', text: 'a'), isTrue);
        expect(await s.addFamilyPlanItem(author: 'அம்மா', text: 'b'), isFalse);
      },
    );

    test('scam share is signed by him and remembered', () async {
      final sharer = FakeSharer();
      final s = await makeState(sharer: sharer);
      await s.shareScam(s.thisWeeksScam);
      expect(sharer.shared.single, contains('அப்பா அனுப்பியது'));
      expect(s.scamShared, contains(s.thisWeeksScam.id));
    });
  });

  group('screens', () {
    testWidgets('daily plan: suggestion chip, dictation, tick', (tester) async {
      final s = await makeState();
      await pumpApp(tester, s);
      await tapText(tester, 'இன்றைய திட்டம்');
      await tapText(tester, 'காலை நடை');
      expect(s.planForDay(s.todayKey).map((p) => p.text), ['காலை நடை']);

      await tester.ensureVisible(find.byTooltip('பேசிச் சேர்'));
      await tester.tap(find.byTooltip('பேசிச் சேர்'));
      await tester.pumpAndSettle();
      await tapText(tester, 'சேர்');
      expect(s.planForDay(s.todayKey).map((p) => p.text), [
        'காலை நடை',
        'கோயில்',
      ]);

      await tapText(tester, 'காலை நடை');
      expect(s.planForDay(s.todayKey).first.done, isTrue);
      expect(find.text('2-இல் 1 முடிந்தது'), findsOneWidget);
    });

    testWidgets('health: swapped BP numbers get a gentle note, then save', (
      tester,
    ) async {
      final s = await makeState();
      await pumpApp(tester, s);
      await tapText(tester, 'உடல்நலம்');
      await tapText(tester, 'BP, சர்க்கரை');
      await tapText(tester, 'BP போடு');
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '80');
      await tester.enterText(fields.at(1), '130');
      await tapText(tester, 'சேமி');
      expect(find.textContaining('மாற்றிப் போட்டீர்களா'), findsOneWidget);
      expect(s.healthEntries, isEmpty);
      await tester.enterText(fields.at(0), '130');
      await tester.enterText(fields.at(1), '80');
      await tapText(tester, 'சேமி');
      expect(s.healthEntries.single.display, '130/80');
      expect(find.text('130/80  mmHg'), findsOneWidget);
    });

    testWidgets('questions: family asks on his phone, he answers by voice', (
      tester,
    ) async {
      final s = await makeState();
      await s.addLocalQuestion(
        author: 'அம்மா',
        text: 'மின்விசிறி சத்தம் போடுகிறது, என்ன செய்யலாம்?',
      );
      await pumpApp(tester, s);
      expect(find.text('1'), findsWidgets); // badge
      await tapText(tester, 'குடும்பத்தின் கேள்விகள்');
      await tapText(tester, 'அம்மா கேட்டது');
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();
      await tapText(tester, 'பதிலை அனுப்பு');
      expect(s.unansweredQuestions, 0);
      expect(find.text('நீங்கள் பதில் சொல்லிவிட்டீர்கள்.'), findsOneWidget);
    });

    testWidgets('scam alert: read and forward', (tester) async {
      final sharer = FakeSharer();
      final s = await makeState(sharer: sharer);
      await pumpApp(tester, s);
      await tapText(tester, 'இந்த வாரம் கவனிக்க');
      expect(find.text(s.thisWeeksScam.title), findsWidgets);
      await tapText(tester, 'நண்பர்களுக்கு அனுப்பு');
      expect(sharer.shared, hasLength(1));
      expect(find.text('நண்பர்களுக்கு அனுப்பினீர்கள்.'), findsOneWidget);
    });

    testWidgets('sharing screen: he turns health on and sees it', (
      tester,
    ) async {
      final s = await makeState();
      await pumpApp(tester, s);
      await tapText(tester, 'குடும்பம் என்ன பார்க்கிறது');
      expect(find.text('இப்போது: உங்களுக்கு மட்டும்'), findsWidgets);
      await tester.ensureVisible(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(s.sharing.health, isTrue);
      expect(find.text('இப்போது: குடும்பத்தினர் பார்க்கலாம்'), findsOneWidget);
    });

    testWidgets(
      'learning: WhatsApp voice note by press-and-hold, then "did it for real"',
      (tester) async {
        final s = await makeState();
        await pumpApp(tester, s);
        await tapText(tester, 'கற்றுக்கொள்வோம்');
        await tapText(tester, 'குரல் செய்தி அனுப்புவது');
        await tapText(tester, 'தொடங்கு');
        await tapText(tester, 'குடும்பம் (பயிற்சி)');
        final mic = find.byIcon(Icons.mic);
        await tester.ensureVisible(mic);
        await tester.tap(mic);
        await tester.pumpAndSettle();
        expect(find.textContaining('பிடித்துக்கொண்டே'), findsWidgets);
        await tester.ensureVisible(mic);
        await tester.pumpAndSettle();
        await tester.longPress(mic);
        await tester.pumpAndSettle();
        await tapText(tester, 'முடிந்தது');
        expect(s.completedWalkthroughs, contains('wa-voice'));
        await tapText(tester, 'போதும்');
        await tapText(tester, 'உண்மையான ஆப்பில் நானே செய்தேன்');
        expect(s.realWorldDone, contains('wa-voice'));
      },
    );

    testWidgets('family phone has four tabs and settings inside', (
      tester,
    ) async {
      final s = await makeState(
        prefs: {'role': 'family', 'displayName': 'ராகுல்'},
      );
      await pumpApp(tester, s);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text('அமைப்பு'));
      await tester.pumpAndSettle();
      expect(find.text('Supabase URL'), findsOneWidget);
    });

    testWidgets('weekly review opens from settings', (tester) async {
      final s = await makeState();
      await pumpApp(tester, s);
      await tapText(tester, 'குடும்பத்தினருக்கு: அமைப்புகள்');
      await tapText(tester, 'வாராந்திர ஆய்வு (ஞாயிறு)');
      expect(find.text('தூக்கம், கடந்த 4 வாரம்'), findsOneWidget);
    });
  });
}
