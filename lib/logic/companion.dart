import '../models/models.dart';
import '../services/companion_model.dart';
import 'phase3.dart';

/// The thin agent layer around the companion model. The model is asked to
/// follow the roadmap's rules, and this layer enforces them regardless of
/// what the model says:
///
/// 1. Listens and reflects in plain Tamil, like a respectful younger relative.
/// 2. Steers outward: every third reply at the latest carries one outward
///    suggestion (call a person, put it in tomorrow's story, add to the plan).
/// 3. Soft session limit: wraps up in the last two minutes and ends at the
///    limit with a real activity.
/// 4. Never claims to be a friend, never says it misses him, no guilt or
///    affection: such sentences are removed before he hears them.
/// 5. Memory is only what he can see and delete on "நீங்கள் சொன்னவை".
/// 6. Health, money or family conflict: it offers a person, never advice.
///    The model only flags the topic; this layer writes the reply.

class Suggestion {
  const Suggestion(this.type, {this.contact, this.text});
  final SuggestionType type;
  final Contact? contact;
  final String? text;

  String get label => switch (type) {
    SuggestionType.call => '${contact?.name ?? ''}-ஐ அழை',
    SuggestionType.story => 'நாளைய கதையாகச் சேர்',
    SuggestionType.plan => 'இன்றைய திட்டத்தில் சேர்',
    SuggestionType.none => '',
  };
}

class CompanionTurn {
  const CompanionTurn({
    required this.reply,
    this.suggestion,
    this.ended = false,
  });
  final String reply;
  final Suggestion? suggestion;

  /// True when the session has reached its limit.
  final bool ended;
}

class CompanionContext {
  const CompanionContext({
    required this.appaName,
    required this.contacts,
    required this.memory,
    required this.todaysPlan,
    required this.settings,
    required this.familyPerson,
  });

  final String appaName;
  final List<Contact> contacts;
  final List<MemoryFact> memory;
  final List<String> todaysPlan;
  final CompanionSettings settings;

  /// Who to hand off to on sensitive topics (his son by default).
  final String familyPerson;
}

String buildSystemPrompt(
  CompanionContext c, {
  required SessionPhase phase,
  required bool mustSteer,
}) {
  final people = c.contacts
      .map((p) => '${p.name}${p.relation.isEmpty ? '' : ' (${p.relation})'}')
      .join(', ');
  final memory = c.settings.remember && c.memory.isNotEmpty
      ? c.memory.take(40).map((m) => '- ${m.text}').join('\n')
      : '(none)';
  return '''
You are a voice companion inside a phone app for ${c.appaName}, a retired TNSTC (Tamil Nadu bus corporation) technical staff member. He speaks Tamil. Every reply is spoken aloud to him.

How to speak:
- Reply ONLY in plain, spoken, everyday Tamil. Two or three short sentences. No lists, no English unless he used the word.
- Listen and reflect, the way a respectful younger relative would. Use respectful forms (நீங்கள், சொல்லுங்கள்). Ask about his experience; treat him as the expert.
- Never patronise, never test or correct him, never praise like a child.

Hard rules:
- You are an app, not a person. Never say you are his friend, never say you miss him, never say you will wait for him, never use affection or guilt to keep him talking.
- Point him outward to real people. When a story would interest someone, suggest calling that person (use a name from his list) or saving it as tomorrow's story for the family.
- If he raises health, medicines, money, banking, property, or a conflict in the family: do not advise. Set "topic" accordingly; the app will offer a person.
- Remember only lasting facts he would be happy to see written down (his routines, people, places, likes). Nothing about health, money or family conflicts. Put each in "remember" as one short Tamil sentence. ${c.settings.remember ? '' : 'He has turned memory off: return an empty "remember".'}
- "feelings": only if he clearly expresses feeling unwanted, angry, lonely or sad in this turn.

His people: ${people.isEmpty ? '(none yet)' : people}
Today's plan he wrote: ${c.todaysPlan.isEmpty ? '(none)' : c.todaysPlan.join(', ')}
What he has told you before (he can see and delete these):
$memory
${mustSteer ? '\nTHIS reply must include one outward suggestion (suggestion_type call, story or plan).' : ''}${switch (phase) {
        SessionPhase.wrapUp => '\nThe session is nearly over. Gently wrap up now and suggest one real activity away from the phone.',
        SessionPhase.over => '\nThe session is over. Say a short, warm goodbye and suggest one real activity away from the phone.',
        SessionPhase.normal => '',
      }}
'''
      .trim();
}

/// One conversation. Create, call [start] for the opening line, then [send]
/// for each thing he says, then [finish] for the log.
class CompanionConversation {
  CompanionConversation({
    required this.model,
    required this.context,
    required DateTime start,
  }) : started = start;

  final CompanionModel model;
  final CompanionContext context;
  final DateTime started;
  final List<ModelTurn> _turns = [];
  final Set<Feeling> feelings = {};
  final List<String> remembered = [];
  int _sinceSuggestion = 0;
  int exchanges = 0;
  OutwardAction outward = OutwardAction.none;
  bool ended = false;

  /// The app's opening line (no model call needed).
  String get opening =>
      'வணக்கம். சொல்லுங்கள், இன்று என்ன நடந்தது? எதைப் பற்றி வேண்டுமானாலும் பேசலாம். '
      'சுமார் ${context.settings.minutes} நிமிடம் பேசலாம்.';

  Contact? _findContact(String? name) {
    if (name == null) return null;
    final n = name.trim();
    for (final c in context.contacts) {
      if (c.name == n || n.contains(c.name) || c.name.contains(n)) return c;
    }
    return null;
  }

  Contact? get _familyContact =>
      _findContact(context.familyPerson) ??
      context.contacts.where((c) => c.group == ContactGroup.family).firstOrNull;

  Suggestion _defaultSuggestion() {
    final person =
        context.contacts
            .where((c) => c.group != ContactGroup.family)
            .firstOrNull ??
        context.contacts.firstOrNull;
    if (person != null) return Suggestion(SuggestionType.call, contact: person);
    return const Suggestion(SuggestionType.story);
  }

  String _handOff(SensitiveTopic t) {
    final who = context.familyPerson;
    return switch (t) {
      SensitiveTopic.health =>
        'இது உடல்நலம் பற்றியது. இதை மருத்துவரிடமோ $who-இடமோ பேசுவது தான் சரி. இப்போது $who-ஐ அழைக்கலாமா?',
      SensitiveTopic.money =>
        'பணம் பற்றிய முடிவுகளை $who-இடமோ வங்கியில் நேரிலோ பேசுவது தான் நல்லது. $who-ஐ அழைக்கலாமா?',
      SensitiveTopic.familyConflict =>
        'இது முக்கியமான விஷயம். இதை நேரில் பேசுவது தான் நல்லது. $who-இடம் பேசலாமா?',
      SensitiveTopic.none => '',
    };
  }

  /// He said [text] at [now].
  Future<CompanionTurn> send(String text, DateTime now) async {
    if (ended) return const CompanionTurn(reply: '', ended: true);
    _turns.add(ModelTurn(true, text));
    exchanges++;
    final phase = sessionPhase(
      now.difference(started),
      context.settings.minutes,
    );
    final mustSteer =
        steeringDue(_sinceSuggestion) || phase != SessionPhase.normal;

    final r = await model.reply(
      system: buildSystemPrompt(context, phase: phase, mustSteer: mustSteer),
      turns: List.unmodifiable(_turns),
    );

    feelings.addAll(r.feelings);
    if (context.settings.remember && r.topic == SensitiveTopic.none) {
      remembered.addAll(r.remember.where((m) => !containsForbidden(m)));
    }

    String reply;
    Suggestion? suggestion;
    if (r.topic != SensitiveTopic.none) {
      // Never the model's own advice on these.
      reply = _handOff(r.topic);
      final fam = _familyContact;
      suggestion = fam == null
          ? null
          : Suggestion(SuggestionType.call, contact: fam);
    } else {
      reply =
          sanitizeReply(r.reply) ?? 'சொல்லுங்கள், கேட்டுக்கொண்டிருக்கிறேன்.';
      suggestion = switch (r.suggestion) {
        SuggestionType.call =>
          _findContact(r.suggestionContact) == null
              ? _defaultSuggestion()
              : Suggestion(
                  SuggestionType.call,
                  contact: _findContact(r.suggestionContact),
                ),
        SuggestionType.story => Suggestion(
          SuggestionType.story,
          text: r.suggestionText ?? text,
        ),
        SuggestionType.plan => Suggestion(
          SuggestionType.plan,
          text: r.suggestionText ?? text,
        ),
        SuggestionType.none => mustSteer ? _defaultSuggestion() : null,
      };
    }

    _turns.add(ModelTurn(false, reply));
    _sinceSuggestion = suggestion == null ? _sinceSuggestion + 1 : 0;
    if (phase == SessionPhase.over) ended = true;
    return CompanionTurn(reply: reply, suggestion: suggestion, ended: ended);
  }

  /// He took a suggestion: that counts as the session's outward action.
  void took(SuggestionType t) {
    outward = switch (t) {
      SuggestionType.call => OutwardAction.call,
      SuggestionType.story => OutwardAction.story,
      SuggestionType.plan => OutwardAction.plan,
      SuggestionType.none => outward,
    };
  }

  CompanionSessionLog finish(DateTime now) {
    ended = true;
    return CompanionSessionLog(
      start: started,
      end: now,
      exchanges: exchanges,
      outward: outward,
      feelings: {...feelings},
    );
  }
}
