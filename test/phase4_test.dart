import 'package:appa_app/app_state.dart';
import 'package:appa_app/data/local_store.dart';
import 'package:appa_app/logic/phase4.dart';
import 'package:appa_app/main.dart';
import 'package:appa_app/models/models.dart';
import 'package:appa_app/services/audio.dart';
import 'package:appa_app/services/companion_model.dart';
import 'package:appa_app/services/dictation.dart';
import 'package:appa_app/services/phone.dart';
import 'package:appa_app/services/reminders.dart';
import 'package:appa_app/services/speech.dart';
import 'package:appa_app/services/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A connected backend that records Phase 4 calls.
class WorldSync extends NoFamilySync {
  WorldSync({this.household = true});
  final bool household;
  bool joined = false;
  final asked = <({String? text, String? topic, bool outside})>[];
  final questions = <FamilyQuestion>[];
  List<LocalEvent> remoteEvents = [];
  final attended = <String, bool>{};
  final answers = <CircleAnswer>[];
  String? circle;

  @override
  bool get connected => household || joined;
  @override
  bool get online => true;
  @override
  Future<void> connect({required String url, required String key}) async {}
  @override
  Future<void> resume({required String householdCode}) async {}
  @override
  Future<String> helpCode() async => 'HABC234';
  @override
  Future<({String kind, String id})> joinByCode({
    required String code,
    required String displayName,
  }) async {
    if (code.startsWith('C')) {
      circle = 'circle-1';
      return (kind: 'circle', id: 'circle-1');
    }
    if (code.startsWith('H')) {
      joined = true;
      return (kind: 'help', id: 'hh-1');
    }
    throw StateError('unknown code');
  }

  @override
  Future<void> askQuestion({
    required String id,
    String? text,
    String? localAudioPath,
    required String authorName,
    bool outside = false,
    String? topic,
  }) async {
    asked.add((text: text, topic: topic, outside: outside));
    questions.add(
      FamilyQuestion(
        id: id,
        authorName: authorName,
        createdAt: DateTime(2026, 11, 2),
        text: text,
        outside: outside,
        topic: topic,
      ),
    );
  }

  @override
  Future<List<FamilyQuestion>> fetchQuestions() async => List.of(questions);
  @override
  Future<List<LocalEvent>> fetchEvents() async => remoteEvents;
  @override
  Future<void> setEventAttended(String id, bool a) async => attended[id] = a;
  @override
  Future<({String id, String code})> createCircle({
    required String name,
    required String displayName,
  }) async {
    circle = 'circle-1';
    return (id: 'circle-1', code: 'CXYZ234');
  }

  @override
  void useCircle(String circleId) => circle = circleId;
  @override
  Future<List<CircleMember>> fetchCircleMembers() async => const [
    CircleMember(name: 'அப்பா'),
    CircleMember(name: 'சுப்பிரமணி', birthdayMonth: 11, birthdayDay: 4),
  ];
  @override
  Future<List<CircleAnswer>> fetchCircleAnswers() async => List.of(answers);
  @override
  Future<void> uploadCircleAnswer({
    required String week,
    required String localPath,
    required String authorName,
  }) async => answers.add(
    CircleAnswer(
      id: '${answers.length}',
      week: week,
      authorName: authorName,
      audioPath: 'c/$week/x.m4a',
      createdAt: DateTime(2026, 11, 2),
      mine: true,
    ),
  );
}

DateTime clock = DateTime(2026, 11, 2, 9, 0); // Monday, ISO week 45

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
    dictation: FakeDictation('பால் ஐம்பது ரூபாய்'),
    sharer: sharer ?? FakeSharer(),
    companionModel: NoCompanionModel(),
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

LocalEvent ev(String id, DateTime at, {bool attended = false}) => LocalEvent(
  id: id,
  title: 'சங்கக் கூட்டம் $id',
  place: 'சங்க அலுவலகம்',
  startsAt: at,
  attended: attended,
);

void main() {
  setUp(() => clock = DateTime(2026, 11, 2, 9, 0));

  group('ledger', () {
    test('reads spoken and typed lines', () {
      expect(parseLedgerUtterance('காய்கறி 200'), (
        item: 'காய்கறி',
        amount: 200,
      ));
      expect(parseLedgerUtterance('200 ரூபாய் பால்'), (
        item: 'பால்',
        amount: 200,
      ));
      expect(parseLedgerUtterance('பால் ஐம்பது ரூபாய்'), (
        item: 'பால்',
        amount: 50,
      ));
      expect(parseLedgerUtterance('₹1,500 கரண்ட் பில்'), (
        item: 'கரண்ட் பில்',
        amount: 1500,
      ));
      expect(parseLedgerUtterance('காய்கறி'), isNull);
      expect(parseLedgerUtterance('300'), isNull);
      expect(parseLedgerUtterance(''), isNull);
    });

    test('month totals by item, largest first', () {
      final e = [
        LedgerEntry(
          id: '1',
          at: DateTime(2026, 11, 1),
          item: 'பால்',
          amount: 50,
        ),
        LedgerEntry(
          id: '2',
          at: DateTime(2026, 11, 2),
          item: 'காய்கறி',
          amount: 200,
        ),
        LedgerEntry(
          id: '3',
          at: DateTime(2026, 11, 3),
          item: 'பால்',
          amount: 50,
        ),
        LedgerEntry(
          id: '4',
          at: DateTime(2026, 10, 3),
          item: 'பால்',
          amount: 999,
        ),
      ];
      final m = ledgerForMonth(e, 2026, 11);
      expect(m.total, 300);
      expect(m.byItem.first.key, 'காய்கறி');
      expect(m.byItem.last.value, 100);
      expect(m.entries.length, 3);
    });
  });

  group('events and circle rules', () {
    test('upcoming soonest first; asked about once, only for 14 days', () {
      final events = [
        ev('a', DateTime(2026, 11, 5, 17)),
        ev('b', DateTime(2026, 11, 3, 10)),
        ev('c', DateTime(2026, 10, 30, 10)),
        ev('d', DateTime(2026, 10, 1, 10)),
        ev('e', DateTime(2026, 10, 31, 10), attended: true),
      ];
      expect(upcomingEvents(events, clock).map((e) => e.id), ['b', 'a']);
      expect(eventsToAskAbout(events, clock).map((e) => e.id), ['c']);
      expect(eventsToAskAbout(events, clock, answered: {'c'}), isEmpty);
      expect(eventInvite(events[0], 'அப்பா'), contains('வருகிறீர்களா'));
    });

    test('ISO week keys cross the year boundary correctly', () {
      expect(weekKey(DateTime(2026, 11, 2)), '2026-W45');
      expect(weekKey(DateTime(2026, 12, 31)), '2026-W53');
      expect(weekKey(DateTime(2027, 1, 1)), '2026-W53');
      expect(weekKey(DateTime(2027, 1, 4)), '2027-W01');
    });

    test('circle prompt is the same all week; birthdays within 7 days', () {
      expect(
        circlePromptFor(DateTime(2026, 11, 5)),
        circlePromptFor(DateTime(2026, 11, 7)),
      );
      expect(
        circlePromptFor(DateTime(2026, 11, 5)),
        isNot(circlePromptFor(DateTime(2026, 11, 13))),
      );
      final b = circleBirthdays(const [
        CircleMember(name: 'a', birthdayMonth: 11, birthdayDay: 2),
        CircleMember(name: 'b', birthdayMonth: 11, birthdayDay: 8),
        CircleMember(name: 'c', birthdayMonth: 11, birthdayDay: 9),
        CircleMember(name: 'd'),
      ], clock);
      expect(b.map((x) => (x.member.name, x.inDays)), [('a', 0), ('b', 6)]);
    });
  });

  group('state', () {
    test('repair diary and review counts', () async {
      final s = await makeState();
      await s.addRepair(
        item: 'தண்ணீர் மோட்டார்',
        note: 'கெப்பாசிட்டர் மாற்றினேன்',
      );
      await s.addRepair(item: 'ஸ்கூட்டர்', forWhom: 'குமார்');
      await s.addRepair(item: '  ');
      expect(s.repairs.length, 2);
      expect(s.repairs.first.forWhom, 'குமார்');
      expect(s.purpose.repairsThisMonth, 2);
      await s.removeRepair(s.repairs.first.id);
      expect(s.store.repairs.length, 1);
    });

    test('ledger is off until he turns it on; spoken entries', () async {
      final s = await makeState();
      expect(s.ledgerEnabled, isFalse);
      await s.setLedgerEnabled(true);
      expect(await s.addLedgerSpoken('காய்கறி 200'), isNull);
      expect(await s.addLedgerSpoken('ஏதோ'), contains('எதற்கு'));
      expect(s.ledgerMonth(2026, 11).total, 200);
    });

    test('events: plan, invite, did you go (asked once), remote merge keeps his answer', () async {
      final sharer = FakeSharer();
      final sync = WorldSync();
      final s = await makeState(sync: sync, sharer: sharer);
      sync.remoteEvents = [
        ev('r1', DateTime(2026, 10, 30, 10)),
        ev('r2', DateTime(2026, 11, 6, 17)),
      ];
      await s.pullPhase4();
      expect(s.upcoming.single.id, 'r2');
      expect(s.askAttended.single.id, 'r1');
      await s.eventToPlan(s.upcoming.single);
      expect(
        s.planForDay('2026-11-06').single.text,
        contains('சங்கக் கூட்டம்'),
      );
      await s.inviteToEvent(s.upcoming.single);
      expect(sharer.shared.single, contains('அப்பா'));
      await s.markAttended('r1', true);
      expect(sync.attended['r1'], isTrue);
      expect(s.askAttended, isEmpty);
      await s.pullPhase4();
      expect(s.events.firstWhere((e) => e.id == 'r1').attended, isTrue);
      expect(s.purpose.eventsAttended, 1);
    });

    test('help code is made once and shared in his words', () async {
      final sharer = FakeSharer();
      final s = await makeState(sync: WorldSync(), sharer: sharer);
      await s.shareHelpCode();
      expect(s.helpCode, 'HABC234');
      expect(sharer.shared.single, contains('HABC234'));
    });

    test('friend phone: help code lets them ask as an outsider; circle code joins the circle', () async {
      final sync = WorldSync(household: false);
      final s = await makeState(
        prefs: {'role': 'friend', 'displayName': 'சுப்பிரமணி'},
        sync: sync,
      );
      expect(await s.joinWithCode(url: 'u', key: 'k', code: 'HABC234'), 'help');
      expect(s.helpJoined, isTrue);
      expect(
        await s.askHelp(text: 'லாரி கரும்புகை?', topic: helpTopics.first),
        isTrue,
      );
      expect(sync.asked.single.outside, isTrue);
      expect(s.friendQuestions.single.topic, helpTopics.first);

      expect(
        await s.joinWithCode(url: 'u', key: 'k', code: 'CXYZ234'),
        'circle',
      );
      expect(s.inCircle, isTrue);
      expect(s.circleMembers.length, 2);
      expect(await s.answerCircle('/fake/c.m4a'), isTrue);
      expect(s.answeredCircleThisWeek, isTrue);
      expect(await s.joinWithCode(url: 'u', key: 'k', code: 'XXX'), isNull);
    });

    test('Appa starts the circle and shares its code', () async {
      final sharer = FakeSharer();
      final s = await makeState(sync: WorldSync(), sharer: sharer);
      expect(await s.createCircle('டிப்போ நண்பர்கள்'), 'CXYZ234');
      await s.shareCircleCode();
      expect(sharer.shared.single, contains('CXYZ234'));
      expect(s.inCircle, isTrue);
    });
  });

  group('screens', () {
    testWidgets('home: repair diary tile; ledger offered quietly', (
      tester,
    ) async {
      final s = await makeState();
      await pumpApp(tester, s);
      expect(find.text('நான் சரிசெய்தவை'), findsOneWidget);
      expect(find.text('வீட்டுக் கணக்கு (விருப்பம்)'), findsOneWidget);
      await tapText(tester, 'நான் சரிசெய்தவை');
      await tapText(tester, 'இன்று சரிசெய்ததைச் சேர்');
      await tester.enterText(find.byType(TextField).first, 'மின்விசிறி');
      await tapText(tester, 'சேமி');
      expect(s.repairs.single.item, 'மின்விசிறி');
      expect(find.text('மின்விசிறி'), findsOneWidget);
    });

    testWidgets('ledger: he turns it on and speaks an entry', (tester) async {
      final s = await makeState();
      await pumpApp(tester, s);
      await tapText(tester, 'வீட்டுக் கணக்கு (விருப்பம்)');
      await tapText(tester, 'கணக்கு வைக்கத் தொடங்கு');
      await tester.tap(find.byTooltip('பேசிச் சேர்'));
      await tester.pumpAndSettle();
      await tapText(tester, 'சேர்');
      expect(s.ledger.single.amount, 50);
      expect(find.text('₹ 50'), findsWidgets);
    });

    testWidgets('events: "did you go?" then gone from the list', (
      tester,
    ) async {
      final s = await makeState();
      s.events = [
        ev('p', DateTime(2026, 10, 31, 10)),
        ev('u', DateTime(2026, 11, 4, 17)),
      ];
      await pumpApp(tester, s);
      await tapText(tester, 'அருகில் நிகழ்ச்சிகள்');
      expect(find.text('சங்கக் கூட்டம் p-க்குப் போனீர்களா?'), findsOneWidget);
      await tapText(tester, 'போனேன்');
      expect(s.events.firstWhere((e) => e.id == 'p').attended, isTrue);
      expect(find.text('சங்கக் கூட்டம் p-க்குப் போனீர்களா?'), findsNothing);
      expect(find.text('சங்கக் கூட்டம் u'), findsOneWidget);
    });

    testWidgets('questions: outside helpers in their own section with topic', (
      tester,
    ) async {
      final s = await makeState();
      s.questions = [
        FamilyQuestion(
          id: '1',
          authorName: 'அம்மா',
          createdAt: clock,
          text: 'மின்விசிறி?',
        ),
        FamilyQuestion(
          id: '2',
          authorName: 'கார்த்திக்',
          createdAt: clock,
          text: 'லாரி?',
          outside: true,
          topic: 'வண்டி / பைக்',
        ),
      ];
      await pumpApp(tester, s);
      expect(find.textContaining('1 வெளியிலிருந்து'), findsOneWidget);
      await tapText(tester, 'குடும்பத்தின் கேள்விகள்');
      expect(find.text('உங்கள் உதவி கேட்பவர்கள்'), findsOneWidget);
      expect(find.text('கார்த்திக் கேட்டது · வண்டி / பைக்'), findsOneWidget);
    });

    testWidgets('friend setup: third option lands on the join screen', (
      tester,
    ) async {
      final s = await makeState(prefs: const {});
      await pumpApp(tester, s);
      await tapText(tester, 'நண்பர் / உதவி கேட்பவர்');
      await tester.enterText(find.byType(TextField), 'சுப்பிரமணி');
      await tapText(tester, 'தொடங்கலாம்');
      expect(find.text('குறியீடு போட்டுச் சேருங்கள்'), findsOneWidget);
      expect(find.text('அப்பாவின் கதைகள்'), findsNothing);
    });

    testWidgets('circle: weekly prompt, answer, archive', (tester) async {
      final sync = WorldSync();
      final s = await makeState(sync: sync);
      await s.createCircle('டிப்போ நண்பர்கள்');
      await pumpApp(tester, s);
      await tapText(tester, 'டிப்போ நண்பர்கள் வட்டம்');
      expect(find.text(circlePromptFor(clock)), findsOneWidget);
      expect(find.text('2 நாளில் சுப்பிரமணி-இன் பிறந்தநாள்'), findsOneWidget);
      await tester.ensureVisible(find.byIcon(Icons.mic));
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();
      await tapText(tester, 'எல்லோருக்கும் அனுப்பு');
      expect(sync.answers, hasLength(1));
      expect(find.text('அப்பா (நீங்கள்)'), findsOneWidget);
    });
  });
}
