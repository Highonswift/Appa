import 'dart:convert';

import 'package:appa_app/app_state.dart';
import 'package:appa_app/data/local_store.dart';
import 'package:appa_app/data/story_prompts.dart';
import 'package:appa_app/logic/archive_export.dart';
import 'package:appa_app/logic/companion.dart';
import 'package:appa_app/logic/phase3.dart';
import 'package:appa_app/main.dart';
import 'package:appa_app/models/models.dart';
import 'package:appa_app/services/audio.dart';
import 'package:appa_app/services/companion_model.dart';
import 'package:appa_app/services/dictation.dart';
import 'package:appa_app/services/phone.dart';
import 'package:appa_app/services/reminders.dart';
import 'package:appa_app/services/speech.dart';
import 'package:appa_app/services/sync.dart';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertSync extends NoFamilySync {
  final sent = <String>[];
  @override
  bool get connected => true;
  @override
  Future<void> sendAlert({
    required String id,
    required String kind,
    required String note,
  }) async => sent.add(note);
}

DateTime clock = DateTime(2026, 11, 2, 9, 0);

final murugan = Contact(
  id: 'm',
  name: 'முருகன்',
  phone: '1',
  group: ContactGroup.colleague,
);
final ragul = Contact(
  id: 'r',
  name: 'ராகுல்',
  phone: '2',
  group: ContactGroup.family,
);

Future<AppState> makeState({
  Map<String, Object> prefs = const {'role': 'appa', 'displayName': 'அப்பா'},
  CompanionModel? model,
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
    dictation: FakeDictation('டிப்போவில் இன்று பழைய நண்பரைப் பார்த்தேன்'),
    sharer: sharer ?? FakeSharer(),
    companionModel: model ?? NoCompanionModel(),
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

CompanionContext ctx({
  CompanionSettings settings = const CompanionSettings(),
  List<MemoryFact> memory = const [],
}) => CompanionContext(
  appaName: 'அப்பா',
  contacts: [murugan, ragul],
  memory: memory,
  todaysPlan: const ['காலை நடை'],
  settings: settings,
  familyPerson: 'ராகுல்',
);

void main() {
  setUp(() => clock = DateTime(2026, 11, 2, 9, 0));

  group('calls', () {
    final day = DateTime(2026, 11, 2, 10);
    final a = Contact(
      id: 'a',
      name: 'A',
      phone: '1',
      lastCalled: DateTime(2026, 10, 20),
    );
    final b = Contact(
      id: 'b',
      name: 'B',
      phone: '1',
      lastCalled: DateTime(2026, 10, 20),
    );

    test('good calls lift a person, not-good calls lower them', () {
      expect(tunedContactForDay(day, [a, b], [])!.id, 'a');
      final good = [
        for (var i = 0; i < 2; i++)
          CallEvent(
            day: '2026-10-${10 + i}',
            contactId: 'b',
            outcome: CallOutcome.called,
            at: DateTime(2026, 10, 10 + i),
            rating: CallRating.good,
          ),
      ];
      expect(tunedContactForDay(day, [a, b], good)!.id, 'b');
      final bad = [
        CallEvent(
          day: '2026-10-11',
          contactId: 'a',
          outcome: CallOutcome.called,
          at: DateTime(2026, 10, 11),
          rating: CallRating.notGood,
        ),
      ];
      expect(tunedContactForDay(day, [a, b], bad)!.id, 'b');
    });

    test('still one suggestion a day, and asks "Good call?" once', () {
      final e = CallEvent(
        day: dayKey(day),
        contactId: 'a',
        outcome: CallOutcome.called,
        at: day,
      );
      expect(tunedContactForDay(day, [a, b], [e]), isNull);
      expect(unratedCallToday(day, [e]), same(e));
      expect(unratedCallToday(day, [e.withRating(CallRating.good)]), isNull);
    });

    test('birthdays and festivals: the day before and on the day', () {
      final b1 = murugan.copyWith(birthdayMonth: 11, birthdayDay: 3);
      final o = upcomingOccasions(DateTime(2026, 11, 2), [b1, ragul]);
      expect(o.single.line, 'நாளை முருகன்-இன் பிறந்தநாள்');
      final eve = upcomingOccasions(DateTime(2026, 11, 7), [murugan, ragul]);
      expect(eve.single.line, 'நாளை தீபாவளி');
      expect(eve.single.suggested.map((c) => c.id), ['m']); // family excluded
      expect(
        upcomingOccasions(DateTime(2026, 11, 8), [murugan]).single.daysAway,
        0,
      );
      expect(
        upcomingOccasions(DateTime(2027, 4, 14), []).single.title,
        'தமிழ்ப் புத்தாண்டு',
      );
    });
  });

  group('follow-ups', () {
    StoryFollowUp f(String id, DateTime at, [String? used]) => StoryFollowUp(
      id: id,
      storyId: 's',
      text: 'q',
      authorName: 'அம்மா',
      createdAt: at,
      usedOnDay: used,
    );

    test(
      'become a later day\'s question, oldest first, never the same day',
      () {
        expect(
          followUpForDay('2026-11-02', [
            f('x', DateTime(2026, 11, 2, 8)),
          ]).followUp,
          isNull,
        );
        final r = followUpForDay('2026-11-02', [
          f('y', DateTime(2026, 11, 1)),
          f('x', DateTime(2026, 10, 30)),
        ]);
        expect(r.followUp!.id, 'x');
        expect(r.assign, isTrue);
        final again = followUpForDay('2026-11-02', [
          f('x', DateTime(2026, 10, 30), '2026-11-02'),
        ]);
        expect(again.followUp!.id, 'x');
        expect(again.assign, isFalse);
      },
    );

    test('app state: today\'s question becomes the follow-up, its theme is the parent\'s', () async {
      final s = await makeState();
      clock = DateTime(2026, 11, 1, 9);
      final parent = Story(
        id: 'p1',
        promptId: 'hardest-breakdown',
        promptText: 'q',
        createdAt: clock,
      );
      s.stories = [parent];
      await s.addFollowUp(
        storyId: 'p1',
        text: 'அந்த பஸ் எந்த ரூட்?',
        author: 'ராகுல்',
      );
      await s.ensureTodaysFollowUp();
      expect(
        s.todaysPrompt.id.startsWith('followup:'),
        isFalse,
      ); // not the same day
      clock = DateTime(2026, 11, 2, 9);
      await s.ensureTodaysFollowUp();
      expect(s.todaysPrompt.tamil, 'ராகுல் கேட்கிறார்கள்: அந்த பஸ் எந்த ரூட்?');
      final st = await s.saveStory(audioPath: '/fake/a.m4a');
      expect(s.themeOf(st), StoryTheme.repairs);
      expect(s.storiesByTheme[StoryTheme.repairs]!.length, 2);
    });
  });

  group('patterns', () {
    final now = DateTime(2026, 11, 10, 9);
    List<SleepEntry> nights(List<SleepRating> r) => [
      for (var i = 0; i < r.length; i++)
        SleepEntry(
          day: dayKey(now.subtract(Duration(days: r.length - 1 - i))),
          rating: r[i],
          recordedAt: now,
        ),
    ];
    Set<PatternKind> detect({
      List<SleepEntry> sleep = const [],
      List<CallEvent> calls = const [],
      List<CompanionSessionLog> sessions = const [],
      List<PatternAlert> alerts = const [],
      DateTime? firstUse,
    }) => detectPatterns(
      now: now,
      sleep: sleep,
      calls: calls,
      contacts: [murugan],
      sessions: sessions,
      alerts: alerts,
      firstUse: firstUse,
    );

    test('four bad nights in a row, not three', () {
      expect(detect(sleep: nights(List.filled(4, SleepRating.bad))), {
        PatternKind.badSleep,
      });
      expect(
        detect(
          sleep: nights([SleepRating.good, ...List.filled(3, SleepRating.bad)]),
        ),
        isEmpty,
      );
    });

    test('low mood needs three sessions in a week', () {
      CompanionSessionLog log(int d) => CompanionSessionLog(
        start: now.subtract(Duration(days: d)),
        end: now.subtract(Duration(days: d)),
        exchanges: 3,
        outward: OutwardAction.none,
        feelings: {Feeling.unwanted},
      );
      expect(detect(sessions: [log(1), log(2)]), isEmpty);
      expect(detect(sessions: [log(1), log(2), log(3)]), {PatternKind.lowMood});
    });

    test('no calls in a week, but never on a fresh install', () {
      expect(detect(firstUse: now.subtract(const Duration(days: 3))), isEmpty);
      expect(detect(firstUse: now.subtract(const Duration(days: 20))), {
        PatternKind.noCalls,
      });
      final called = CallEvent(
        day: '2026-11-08',
        contactId: 'm',
        outcome: CallOutcome.called,
        at: DateTime(2026, 11, 8),
      );
      expect(detect(firstUse: DateTime(2026, 1, 1), calls: [called]), isEmpty);
    });

    test('not raised again within a week', () {
      final a = PatternAlert(
        id: 'a',
        kind: PatternKind.badSleep,
        noticedOn: '2026-11-08',
        decision: AlertDecision.notTold,
      );
      expect(
        detect(sleep: nights(List.filled(5, SleepRating.bad)), alerts: [a]),
        isEmpty,
      );
    });

    test('the family note is a sentence, never a transcript', () {
      for (final k in PatternKind.values) {
        expect(alertNote(k, 'அப்பா').length, lessThan(200));
        expect(alertQuestion(k, 'ராகுல்'), contains('ராகுல்'));
      }
    });
  });

  group('companion guard-rails', () {
    test('affection and "miss you" lines are removed', () {
      expect(
        sanitizeReply(
          'நல்ல கதை. நான் உங்களை மிஸ் பண்ணுவேன். முருகனிடம் சொல்லலாமா?',
        ),
        'நல்ல கதை. முருகனிடம் சொல்லலாமா?',
      );
      expect(sanitizeReply('I miss you.'), isNull);
      expect(sanitizeReply('நான் உங்கள் நண்பன்.'), isNull);
    });

    test('soft limit: wrap up in the last two minutes, end at the limit', () {
      expect(sessionPhase(const Duration(minutes: 5), 15), SessionPhase.normal);
      expect(
        sessionPhase(const Duration(minutes: 13), 15),
        SessionPhase.wrapUp,
      );
      expect(sessionPhase(const Duration(minutes: 15), 15), SessionPhase.over);
      expect(sessionPhase(const Duration(minutes: 4), 5), SessionPhase.wrapUp);
    });

    test('system prompt carries the rules; memory only when he allows it', () {
      final mem = [
        MemoryFact(id: '1', text: 'காலையில் நடப்பார்', createdAt: clock),
      ];
      final on = buildSystemPrompt(
        ctx(memory: mem),
        phase: SessionPhase.normal,
        mustSteer: false,
      );
      expect(on, contains('Never say you are his friend'));
      expect(on, contains('காலையில் நடப்பார்'));
      expect(on, contains('முருகன்'));
      final off = buildSystemPrompt(
        ctx(memory: mem, settings: const CompanionSettings(remember: false)),
        phase: SessionPhase.wrapUp,
        mustSteer: true,
      );
      expect(off, isNot(contains('காலையில் நடப்பார்')));
      expect(off, contains('wrap up'));
      expect(off, contains('must include one outward suggestion'));
    });

    test(
      'health, money, family conflict: hands off to a person, never advice',
      () async {
        final model = FakeCompanionModel([
          const ModelReply(
            reply: 'இந்த மாத்திரையை இரண்டு மடங்கு எடுங்கள்.',
            topic: SensitiveTopic.health,
          ),
        ]);
        final c = CompanionConversation(
          model: model,
          context: ctx(),
          start: clock,
        );
        final t = await c.send('BP அதிகமா இருக்கு, மாத்திரை கூட்டலாமா?', clock);
        expect(t.reply, isNot(contains('மாத்திரையை')));
        expect(t.reply, contains('மருத்துவரிடமோ ராகுல்'));
        expect(t.suggestion!.type, SuggestionType.call);
        expect(t.suggestion!.contact!.id, 'r');
      },
    );

    test(
      'steers outward by the third reply even if the model does not',
      () async {
        final model = FakeCompanionModel([
          const ModelReply(reply: 'அப்படியா, சொல்லுங்கள்.'),
        ]);
        final c = CompanionConversation(
          model: model,
          context: ctx(),
          start: clock,
        );
        expect((await c.send('a', clock)).suggestion, isNull);
        expect((await c.send('b', clock)).suggestion, isNull);
        final third = await c.send('c', clock);
        expect(third.suggestion, isNotNull);
        expect(third.suggestion!.contact!.id, 'm'); // a non-family person first
        expect(
          model.systems.last,
          contains('must include one outward suggestion'),
        );
      },
    );

    test('model suggestion for a named contact is honoured; unknown names fall back', () async {
      final model = FakeCompanionModel([
        const ModelReply(
          reply: 'முருகனிடம் சொல்லலாமா?',
          suggestion: SuggestionType.call,
          suggestionContact: 'முருகன்',
        ),
        const ModelReply(
          reply: 'x',
          suggestion: SuggestionType.call,
          suggestionContact: 'யாரோ',
        ),
      ]);
      final c = CompanionConversation(
        model: model,
        context: ctx(),
        start: clock,
      );
      expect((await c.send('a', clock)).suggestion!.contact!.name, 'முருகன்');
      expect((await c.send('b', clock)).suggestion!.contact, isNotNull);
    });

    test('ends at the limit; remembers only non-sensitive facts', () async {
      final model = FakeCompanionModel([
        const ModelReply(
          reply: 'சரி.',
          remember: ['காலையில் கோயிலுக்குப் போவார்'],
        ),
        const ModelReply(
          reply: 'சரி.',
          topic: SensitiveTopic.money,
          remember: ['வங்கியில் 2 லட்சம்'],
        ),
      ]);
      final c = CompanionConversation(
        model: model,
        context: ctx(),
        start: clock,
      );
      await c.send('a', clock);
      final t = await c.send('b', clock.add(const Duration(minutes: 16)));
      expect(t.ended, isTrue);
      expect(c.remembered, ['காலையில் கோயிலுக்குப் போவார்']);
      c.took(SuggestionType.call);
      final log = c.finish(clock.add(const Duration(minutes: 16)));
      expect(log.outward, OutwardAction.call);
      expect(log.exchanges, 2);
    });

    test('Gemini response parsing is tolerant', () {
      String wrap(String text) => jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': text},
              ],
            },
          },
        ],
      });
      final r = parseGeminiReply(
        wrap(
          jsonEncode({
            'reply': 'வணக்கம்',
            'suggestion_type': 'story',
            'topic': 'none',
            'feelings': ['lonely', 'bogus'],
            'remember': ['ஒன்று', ''],
          }),
        ),
      );
      expect(r.reply, 'வணக்கம்');
      expect(r.suggestion, SuggestionType.story);
      expect(r.feelings, {Feeling.lonely});
      expect(r.remember, ['ஒன்று']);
      expect(parseGeminiReply(wrap('not json')).reply, 'not json');
      expect(parseGeminiReply(jsonEncode({'candidates': []})).reply, '');
    });

    test('weekly stats flag sessions getting longer', () {
      CompanionSessionLog log(
        int daysAgo,
        int minutes, [
        OutwardAction o = OutwardAction.none,
      ]) {
        final st = clock.subtract(Duration(days: daysAgo));
        return CompanionSessionLog(
          start: st,
          end: st.add(Duration(minutes: minutes)),
          exchanges: 4,
          outward: o,
        );
      }

      final st = companionStats(clock, [
        log(10, 5),
        log(9, 5),
        log(2, 9, OutwardAction.call),
        log(1, 9),
      ]);
      expect(st.sessionsThisWeek, 2);
      expect(st.outwardShare, 0.5);
      expect(st.lengthening, isTrue);
    });
  });

  group('archive', () {
    test('zip holds a transcript file and each recording by theme', () {
      final items = [
        (
          theme: StoryTheme.tnstc,
          story: Story(
            id: '1',
            promptId: 'tnstc-first-day',
            promptText: 'முதல் நாள்?',
            createdAt: DateTime(2026, 10, 1),
            localAudioPath: '/a',
            transcript: 'அன்று மழை.',
          ),
        ),
        (
          theme: StoryTheme.repairs,
          story: Story(
            id: '2',
            promptId: 'x',
            promptText: 'பழுது?',
            createdAt: DateTime(2026, 10, 2),
            localAudioPath: '/missing',
          ),
        ),
      ];
      final bytes = buildArchiveZip(
        appaName: 'அப்பா',
        items: items,
        readAudio: (p) => p == '/a' ? [1, 2, 3] : throw Exception('missing'),
      );
      final zip = ZipDecoder().decodeBytes(bytes);
      final names = zip.files.map((f) => f.name).toList();
      expect(names, contains('கதைகள்.txt'));
      expect(names.where((n) => n.endsWith('.m4a')), hasLength(1));
      final txt = utf8.decode(zip.findFile('கதைகள்.txt')!.content as List<int>);
      expect(txt, contains('TNSTC ஆண்டுகள்'));
      expect(txt, contains('அன்று மழை.'));
      expect(txt, contains('எழுத்து வடிவம் இன்னும் இல்லை'));
    });

    test('transcribe a story with the model', () async {
      final s = await makeState(
        model: FakeCompanionModel([const ModelReply(reply: '')]),
      );
      final st = await s.saveStory(audioPath: '/fake/a.m4a');
      expect(await s.transcribeStory(st.id), isTrue);
      expect(s.stories.single.transcript, contains('/fake/a.m4a'));
    });
  });

  group('state', () {
    test('ending a session saves numbers and facts, not words', () async {
      final s = await makeState(
        model: FakeCompanionModel([
          const ModelReply(reply: 'சரி', remember: ['மாலையில் டீ குடிப்பார்']),
        ]),
      );
      final c = s.startCompanion();
      await c.send('மாலையில் டீ குடிப்பேன்', clock);
      await s.endCompanion(c);
      expect(s.sessions.single.exchanges, 1);
      expect(s.memory.single.text, 'மாலையில் டீ குடிப்பார்');
      expect(
        s.store.sessions.single.toJson().toString(),
        isNot(contains('டீ')),
      );
    });

    test(
      'his own settings change is recorded; memory off wipes memory',
      () async {
        final s = await makeState();
        s.memory = [MemoryFact(id: '1', text: 'x', createdAt: clock)];
        await s.updateCompanionSettings(
          s.companionSettings.copyWith(minutes: 10),
        );
        expect(s.companionSettings.changedByAppa, isTrue);
        await s.updateCompanionSettings(
          s.companionSettings.copyWith(remember: false),
        );
        expect(s.memory, isEmpty);
      },
    );

    test(
      'asks him first; telling without sync opens the share sheet',
      () async {
        final sharer = FakeSharer();
        final s = await makeState(sharer: sharer);
        s.firstUse = DateTime(2026, 1, 1);
        await s.saveContact(murugan);
        await s.checkPatterns();
        expect(s.pendingAlert!.kind, PatternKind.noCalls);
        await s.decideAlert(s.pendingAlert!.id, tell: true);
        expect(sharer.shared.single, contains('ஒரு வாரமாக'));
        expect(s.pendingAlert, isNull);
        await s.checkPatterns();
        expect(s.pendingAlert, isNull); // not again this week
      },
    );

    test(
      'a standing permission he set sends the note without asking',
      () async {
        final sync = AlertSync();
        final s = await makeState(sync: sync);
        s.firstUse = DateTime(2026, 1, 1);
        await s.saveContact(murugan);
        await s.updateAlertPermissions(
          const AlertPermissions(always: {PatternKind.noCalls}),
        );
        await s.checkPatterns();
        expect(sync.sent, hasLength(1));
        expect(s.pendingAlert, isNull);
        expect(s.alerts.single.decision, AlertDecision.told);
      },
    );

    test('rating the call', () async {
      final s = await makeState();
      await s.saveContact(murugan);
      await s.callContact(murugan);
      expect(s.unratedCall, isNotNull);
      await s.rateCall(CallRating.good);
      expect(s.unratedCall, isNull);
      expect(s.callEvents.single.rating, CallRating.good);
    });
  });

  group('screens', () {
    testWidgets(
      'companion tile appears only with a model; a talk ends in a call',
      (tester) async {
        final none = await makeState();
        await pumpApp(tester, none);
        expect(find.text('பேசலாம்'), findsNothing);

        final model = FakeCompanionModel([
          const ModelReply(
            reply: 'நல்ல நினைவு. இதை முருகனிடம் சொல்லலாமா?',
            suggestion: SuggestionType.call,
            suggestionContact: 'முருகன்',
          ),
        ]);
        final s = await makeState(model: model);
        await s.saveContact(murugan);
        await pumpApp(tester, s);
        await tapText(tester, 'பேசலாம்');
        expect(find.textContaining('சுமார் 15 நிமிடம்'), findsOneWidget);
        await tester.enterText(
          find.byType(TextField),
          'இன்று பழைய டிப்போ ஞாபகம் வந்தது',
        );
        await tester.tap(find.byTooltip('அனுப்பு'));
        await tester.pumpAndSettle();
        expect(
          find.text('நல்ல நினைவு. இதை முருகனிடம் சொல்லலாமா?'),
          findsOneWidget,
        );
        await tapText(tester, 'முருகன்-ஐ அழை');
        expect((s.phone as FakePhone).dialled, ['1']);
        await tapText(tester, 'போதும்');
        expect(s.sessions.single.outward, OutwardAction.call);
      },
    );

    testWidgets('memory screen: he sees and deletes what it remembers', (
      tester,
    ) async {
      final s = await makeState(
        model: FakeCompanionModel([const ModelReply(reply: '')]),
      );
      s.memory = [
        MemoryFact(id: '1', text: 'காலையில் நடப்பார்', createdAt: clock),
      ];
      await pumpApp(tester, s);
      await tapText(tester, 'குடும்பம் என்ன பார்க்கிறது');
      await tapText(tester, 'பேசும் வசதி நினைவில் வைத்திருப்பவை (1)');
      expect(find.text('காலையில் நடப்பார்'), findsOneWidget);
      await tester.tap(find.byTooltip('நீக்கு'));
      await tester.pumpAndSettle();
      expect(s.memory, isEmpty);
      await tapText(tester, '10 நிமி');
      expect(s.companionSettings.minutes, 10);
      expect(s.companionSettings.changedByAppa, isTrue);
    });

    testWidgets('after a call he is asked once "was it good?"', (tester) async {
      final s = await makeState();
      await s.saveContact(murugan);
      await pumpApp(tester, s);
      await tapText(tester, 'இன்று யாரிடம் பேசலாம்');
      await tapText(tester, 'முருகன்-ஐ அழை');
      expect(
        find.text('முருகன்-உடன் பேசியது நன்றாக இருந்ததா?'),
        findsOneWidget,
      );
      await tapText(tester, 'நன்றாக');
      expect(s.callEvents.single.rating, CallRating.good);
      expect(find.text('முருகன்-உடன் பேசியது நன்றாக இருந்ததா?'), findsNothing);
    });

    testWidgets('home asks before telling his son, and accepts "no"', (
      tester,
    ) async {
      final s = await makeState();
      s.firstUse = DateTime(2026, 1, 1);
      await s.saveContact(murugan);
      await s.checkPatterns();
      await pumpApp(tester, s);
      expect(find.textContaining('ராகுல்-இடம் சொல்லலாமா?'), findsOneWidget);
      await tapText(tester, 'வேண்டாம்');
      expect(s.alerts.single.decision, AlertDecision.notTold);
      expect(find.textContaining('ராகுல்-இடம் சொல்லலாமா?'), findsNothing);
    });

    testWidgets('birthday card on home with a call button', (tester) async {
      final s = await makeState();
      await s.saveContact(murugan.copyWith(birthdayMonth: 11, birthdayDay: 2));
      await pumpApp(tester, s);
      expect(find.text('இன்று முருகன்-இன் பிறந்தநாள்'), findsOneWidget);
    });

    testWidgets('archive screen groups by theme and shows progress', (
      tester,
    ) async {
      final s = await makeState();
      s.stories = [
        Story(
          id: '1',
          promptId: 'tnstc-first-day',
          promptText: 'முதல் நாள்?',
          createdAt: clock,
        ),
        Story(
          id: '2',
          promptId: 'wedding-day',
          promptText: 'திருமணம்?',
          createdAt: clock,
        ),
      ];
      await pumpApp(tester, s);
      await tapText(tester, 'இன்றைய கதை');
      await tapText(tester, 'கதைத் தொகுப்பு (2)');
      expect(find.text('2 கதைகள்'), findsOneWidget);
      expect(find.text('TNSTC ஆண்டுகள் (1)'), findsOneWidget);
      expect(find.text('குடும்பம் (1)'), findsOneWidget);
    });
  });
}
