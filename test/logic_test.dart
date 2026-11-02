import 'package:appa_app/data/story_prompts.dart';
import 'package:appa_app/logic/daily_picker.dart';
import 'package:appa_app/data/walkthroughs.dart';
import 'package:appa_app/logic/walkthrough.dart';
import 'package:appa_app/models/models.dart';
import 'package:appa_app/services/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('promptForDay', () {
    test('is stable within a day and changes across days', () {
      final a = promptForDay(DateTime(2026, 11, 2, 7));
      final b = promptForDay(DateTime(2026, 11, 2, 22));
      final c = promptForDay(DateTime(2026, 11, 3, 7));
      expect(a.id, b.id);
      expect(a.id, isNot(c.id));
    });

    test('skips answered questions until all are answered', () {
      final day = DateTime(2026, 11, 2);
      final first = promptForDay(day);
      final next = promptForDay(day, answeredBeforeToday: {first.id});
      expect(next.id, isNot(first.id));

      final all = storyPrompts.map((p) => p.id).toSet();
      expect(promptForDay(day, answeredBeforeToday: all).id, first.id);
    });

    test('prompt ids are unique', () {
      expect(storyPrompts.map((p) => p.id).toSet().length, storyPrompts.length);
    });
  });

  group('contactForDay', () {
    final day = DateTime(2026, 11, 2, 10);
    Contact c(String id, [DateTime? last]) =>
        Contact(id: id, name: id, phone: '1', lastCalled: last);

    test('empty list gives nobody', () {
      expect(contactForDay(day, [], []), isNull);
    });

    test('never-called people come first, in list order', () {
      final list = [c('a', DateTime(2026, 10, 1)), c('b'), c('c')];
      expect(contactForDay(day, list, [])!.id, 'b');
    });

    test('longest since last call comes next', () {
      final list = [
        c('a', DateTime(2026, 10, 30)),
        c('b', DateTime(2026, 10, 1)),
      ];
      expect(contactForDay(day, list, [])!.id, 'b');
    });

    test('one suggestion a day: nothing after calling or "not today"', () {
      final list = [c('a'), c('b')];
      for (final outcome in CallOutcome.values) {
        final history = [
          CallEvent(
            day: dayKey(day),
            contactId: 'a',
            outcome: outcome,
            at: day,
          ),
        ];
        expect(contactForDay(day, list, history), isNull);
        expect(todaysCallEvent(day, history)!.outcome, outcome);
        expect(
          contactForDay(day.add(const Duration(days: 1)), list, history),
          isNotNull,
        );
      }
    });
  });

  test('sleepWindow lines up the last seven mornings', () {
    final today = DateTime(2026, 11, 7, 8);
    final entries = [
      SleepEntry(
        day: '2026-11-07',
        rating: SleepRating.good,
        recordedAt: today,
      ),
      SleepEntry(day: '2026-11-05', rating: SleepRating.bad, recordedAt: today),
      SleepEntry(day: '2026-10-20', rating: SleepRating.bad, recordedAt: today),
    ];
    expect(sleepWindow(today, entries), [
      null,
      null,
      null,
      null,
      SleepRating.bad,
      null,
      SleepRating.good,
    ]);
  });

  group('walkthrough engine', () {
    test('every walkthrough in the library completes on its golden path', () {
      for (final w in walkthroughLibrary) {
        final s = WalkthroughSession(w);
        var guard = 0;
        while (!s.completed && guard++ < 50) {
          final r = s.handle(goldenAction(s.step));
          expect(r.advanced, isTrue, reason: '${w.id} step ${s.index}');
        }
        expect(s.completed, isTrue, reason: w.id);
      }
    });

    test('library ids are unique and every step can be guided', () {
      expect(
        walkthroughLibrary.map((w) => w.id).toSet().length,
        walkthroughLibrary.length,
      );
      for (final w in walkthroughLibrary) {
        for (final st in w.steps) {
          expect(st.hint, isNotNull, reason: '${w.id} ${st.say}');
          if (st.expects == Expect.tap || st.expects == Expect.longPress) {
            expect(st.target, isNotNull, reason: w.id);
            // The target must be drawn on that step's screen.
            final ids = <String>{
              for (final e in st.view.elements)
                ...switch (e) {
                  MButton(:final id) => [id],
                  MTile(:final id) => [id],
                  MQr(:final id) => [id],
                  MGrid(:final items) => items.map((b) => b.id),
                  MIconBar(:final items) => items.map((b) => b.id),
                  MComposer(:final attachId, :final cameraId, :final micId) => [
                    attachId,
                    cameraId,
                    micId,
                  ],
                  _ => <String>[],
                },
            };
            expect(
              ids,
              contains(st.target),
              reason: '${w.id}: ${st.target} not on screen',
            );
          }
        }
      }
    });

    test('send-money flow deducts only the practice balance', () {
      final s = WalkthroughSession(sendMoneyWalkthrough);
      for (final a in const <MockAction>[
        Tap('start'),
        Tap('pay'),
        Tap('contact'),
        EnterNumber(250),
      ]) {
        expect(s.handle(a).advanced, isTrue);
      }
      expect(s.narration(s.step), contains('250'));
      expect(s.narration(s.step), contains(practiceRecipient));
      s.handle(const Tap('send'));
      s.handle(const EnterPin(4));
      expect(s.balance, practiceStartBalance - 250);
      expect(s.completed, isFalse);
      s.handle(const Tap('done'));
      expect(s.completed, isTrue);
    });

    test(
      'a different tap never says "wrong", it points at the right control',
      () {
        final s = WalkthroughSession(sendMoneyWalkthrough)
          ..handle(const Tap('start'));
        final r = s.handle(const Tap('scan'));
        expect(r.advanced, isFalse);
        expect(r.message, contains('பணம் அனுப்பு'));
        expect(r.message, isNot(contains('தவறு'))); // "wrong"
      },
    );

    test('safety walkthrough explains why when he chooses to tell the OTP', () {
      final s = WalkthroughSession(otpSafetyWalkthrough)
        ..handle(const Tap('start'))
        ..handle(const Tap('next'));
      final r = s.handle(const Tap('tell'));
      expect(r.advanced, isFalse);
      expect(r.message, contains('ஒருபோதும் OTP கேட்காது'));
      expect(s.handle(const Tap('hangup')).advanced, isTrue);
    });

    test('voice note needs press-and-hold; a plain tap gets a pointer', () {
      final s = WalkthroughSession(waVoiceNoteWalkthrough)
        ..handle(const Tap('start'))
        ..handle(const Tap('family'));
      final tap = s.handle(const Tap('mic'));
      expect(tap.advanced, isFalse);
      expect(tap.message, contains('பிடித்துக்கொண்டே'));
      expect(s.handle(const LongPress('mic')).advanced, isTrue);
    });

    test('bus ticket fixes the fare and fills the typed name', () {
      final s = WalkthroughSession(busTicketWalkthrough);
      for (final a in const <MockAction>[
        Tap('start'),
        Tap('search'),
        Tap('bus1'),
        Tap('seat5'),
        EnterText('ராமசாமி'),
      ]) {
        s.handle(a);
      }
      expect(s.amount, 420);
      expect(s.fill('{text}'), 'ராமசாமி');
      s.handle(const Tap('pay'));
      s.handle(const EnterPin(4));
      expect(s.balance, practiceStartBalance - 420);
    });

    test(
      'amount must be positive and within the practice balance; PIN 4 or 6',
      () {
        final s = WalkthroughSession(sendMoneyWalkthrough)
          ..handle(const Tap('start'))
          ..handle(const Tap('pay'))
          ..handle(const Tap('contact'));
        expect(s.handle(const EnterNumber(0)).advanced, isFalse);
        expect(s.handle(const EnterNumber(999999)).advanced, isFalse);
        s.handle(const EnterNumber(10));
        s.handle(const Tap('send'));
        expect(s.handle(const EnterPin(2)).advanced, isFalse);
        expect(s.handle(const EnterPin(6)).advanced, isTrue);
      },
    );

    test('restart is unlimited and resets the balance', () {
      final s = WalkthroughSession(sendMoneyWalkthrough);
      for (final a in const <MockAction>[
        Tap('start'),
        Tap('pay'),
        Tap('contact'),
        EnterNumber(100),
        Tap('send'),
        EnterPin(4),
      ]) {
        s.handle(a);
      }
      s.restart();
      expect(s.index, 0);
      expect(s.balance, practiceStartBalance);
      expect(s.amount, isNull);
    });
  });

  test('reminder plan is exactly three a day', () {
    final plan = reminderPlan(
      const ReminderSettings(medicineName: 'BP மாத்திரை'),
    );
    expect(plan.length, 3);
    expect(plan.map((p) => p.id).toSet().length, 3);
    expect(plan[1].body, contains('BP மாத்திரை'));
  });

  test('TimeOfDayMinutes labels in Tamil', () {
    expect(const TimeOfDayMinutes(7, 5).label, 'காலை 7:05');
    expect(const TimeOfDayMinutes(21, 0).label, 'இரவு 9:00');
    expect(const TimeOfDayMinutes(12, 30).label, 'மதியம் 12:30');
  });

  test('models round-trip through JSON', () {
    final story = Story(
      id: 's1',
      promptId: 'p',
      promptText: 'q',
      createdAt: DateTime(2026, 11, 2, 9),
      localAudioPath: '/a.m4a',
      replies: [
        StoryReply(
          id: 'r1',
          authorName: 'ராகுல்',
          createdAt: DateTime(2026, 11, 2, 10),
        ),
      ],
    );
    final back = Story.fromJson(story.toJson());
    expect(back.id, 's1');
    expect(back.replies.single.authorName, 'ராகுல்');
    expect(back.unheardReplies, 1);

    final r = ReminderSettings.fromJson(
      const ReminderSettings(
        medicine: TimeOfDayMinutes(9, 15),
        enabled: false,
      ).toJson(),
    );
    expect(r.medicine, const TimeOfDayMinutes(9, 15));
    expect(r.enabled, isFalse);
  });
}
