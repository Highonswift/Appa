/// Plain data models. Everything is JSON-serialisable so it can live in
/// on-device storage and, optionally, be mirrored to Supabase.
library;

/// Calendar day key (local time), e.g. "2026-11-02".
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A person Appa might call. Added by family in settings, by name.
/// Who a contact is to Appa (Phase 3: the list grows beyond family).
enum ContactGroup { family, relative, colleague, friend, neighbour }

const contactGroupNames = {
  ContactGroup.family: 'குடும்பம்',
  ContactGroup.relative: 'உறவினர்',
  ContactGroup.colleague: 'டிப்போ / வேலை நண்பர்',
  ContactGroup.friend: 'நண்பர்',
  ContactGroup.neighbour: 'அக்கம்பக்கம்',
};

/// A person Appa might call. Added by family in settings, by name.
class Contact {
  Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.relation = '',
    this.lastCalled,
    this.group = ContactGroup.friend,
    this.birthdayMonth,
    this.birthdayDay,
  });

  final String id;
  final String name;
  final String phone;
  final String relation;
  final DateTime? lastCalled;
  final ContactGroup group;

  /// Birthday without a year (so nobody has to know it); both or neither.
  final int? birthdayMonth;
  final int? birthdayDay;

  bool get hasBirthday => birthdayMonth != null && birthdayDay != null;

  Contact copyWith({
    String? name,
    String? phone,
    String? relation,
    DateTime? lastCalled,
    ContactGroup? group,
    int? birthdayMonth,
    int? birthdayDay,
    bool clearBirthday = false,
  }) => Contact(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    relation: relation ?? this.relation,
    lastCalled: lastCalled ?? this.lastCalled,
    group: group ?? this.group,
    birthdayMonth: clearBirthday ? null : birthdayMonth ?? this.birthdayMonth,
    birthdayDay: clearBirthday ? null : birthdayDay ?? this.birthdayDay,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'relation': relation,
    'lastCalled': lastCalled?.toIso8601String(),
    'group': group.name,
    'birthdayMonth': birthdayMonth,
    'birthdayDay': birthdayDay,
  };

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    relation: j['relation'] as String? ?? '',
    lastCalled: j['lastCalled'] == null
        ? null
        : DateTime.parse(j['lastCalled'] as String),
    group: ContactGroup.values.asNameMap()[j['group']] ?? ContactGroup.friend,
    birthdayMonth: j['birthdayMonth'] as int?,
    birthdayDay: j['birthdayDay'] as int?,
  );
}

/// A voice reply from a family member to one of Appa's stories.
class StoryReply {
  StoryReply({
    required this.id,
    required this.authorName,
    required this.createdAt,
    this.localAudioPath,
    this.remoteAudioPath,
    this.listened = false,
  });

  final String id;
  final String authorName;
  final DateTime createdAt;
  final String? localAudioPath;
  final String? remoteAudioPath;
  final bool listened;

  StoryReply copyWith({
    String? localAudioPath,
    String? remoteAudioPath,
    bool? listened,
  }) => StoryReply(
    id: id,
    authorName: authorName,
    createdAt: createdAt,
    localAudioPath: localAudioPath ?? this.localAudioPath,
    remoteAudioPath: remoteAudioPath ?? this.remoteAudioPath,
    listened: listened ?? this.listened,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorName': authorName,
    'createdAt': createdAt.toIso8601String(),
    'localAudioPath': localAudioPath,
    'remoteAudioPath': remoteAudioPath,
    'listened': listened,
  };

  factory StoryReply.fromJson(Map<String, dynamic> j) => StoryReply(
    id: j['id'] as String,
    authorName: j['authorName'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
    localAudioPath: j['localAudioPath'] as String?,
    remoteAudioPath: j['remoteAudioPath'] as String?,
    listened: j['listened'] as bool? ?? false,
  );
}

/// One recorded answer to the story-of-the-day question.
/// One recorded answer to the story-of-the-day question.
class Story {
  Story({
    required this.id,
    required this.promptId,
    required this.promptText,
    required this.createdAt,
    this.localAudioPath,
    this.remoteAudioPath,
    this.replies = const [],
    this.transcript,
  });

  final String id;
  final String promptId;
  final String promptText;
  final DateTime createdAt;
  final String? localAudioPath;
  final String? remoteAudioPath;
  final List<StoryReply> replies;

  /// Written-out text of the recording (Phase 3 archive export).
  final String? transcript;

  bool get synced => remoteAudioPath != null;
  int get unheardReplies => replies.where((r) => !r.listened).length;

  Story copyWith({
    String? remoteAudioPath,
    String? localAudioPath,
    List<StoryReply>? replies,
    String? transcript,
  }) => Story(
    id: id,
    promptId: promptId,
    promptText: promptText,
    createdAt: createdAt,
    localAudioPath: localAudioPath ?? this.localAudioPath,
    remoteAudioPath: remoteAudioPath ?? this.remoteAudioPath,
    replies: replies ?? this.replies,
    transcript: transcript ?? this.transcript,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'promptId': promptId,
    'promptText': promptText,
    'createdAt': createdAt.toIso8601String(),
    'localAudioPath': localAudioPath,
    'remoteAudioPath': remoteAudioPath,
    'replies': replies.map((r) => r.toJson()).toList(),
    'transcript': transcript,
  };

  factory Story.fromJson(Map<String, dynamic> j) => Story(
    id: j['id'] as String,
    promptId: j['promptId'] as String? ?? '',
    promptText: j['promptText'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
    localAudioPath: j['localAudioPath'] as String?,
    remoteAudioPath: j['remoteAudioPath'] as String?,
    replies: ((j['replies'] as List?) ?? [])
        .map((e) => StoryReply.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    transcript: j['transcript'] as String?,
  );
}

enum SleepRating { good, okay, bad }

/// The one-tap morning answer to "how did you sleep?".
class SleepEntry {
  SleepEntry({
    required this.day,
    required this.rating,
    required this.recordedAt,
  });

  final String day; // dayKey of the morning it was recorded
  final SleepRating rating;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
    'day': day,
    'rating': rating.name,
    'recordedAt': recordedAt.toIso8601String(),
  };

  factory SleepEntry.fromJson(Map<String, dynamic> j) => SleepEntry(
    day: j['day'] as String,
    rating: SleepRating.values.byName(j['rating'] as String),
    recordedAt: DateTime.parse(j['recordedAt'] as String),
  );
}

/// What happened with the daily call nudge.
enum CallOutcome { called, notToday }

/// His one-tap answer after a call ("Good call?"), used to tune who is
/// suggested next. Null when he skipped the question.
enum CallRating { good, okay, notGood }

class CallEvent {
  CallEvent({
    required this.day,
    required this.contactId,
    required this.outcome,
    required this.at,
    this.rating,
  });

  final String day;
  final String contactId;
  final CallOutcome outcome;
  final DateTime at;
  final CallRating? rating;

  CallEvent withRating(CallRating r) => CallEvent(
    day: day,
    contactId: contactId,
    outcome: outcome,
    at: at,
    rating: r,
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'contactId': contactId,
    'outcome': outcome.name,
    'at': at.toIso8601String(),
    'rating': rating?.name,
  };

  factory CallEvent.fromJson(Map<String, dynamic> j) => CallEvent(
    day: j['day'] as String,
    contactId: j['contactId'] as String,
    outcome: CallOutcome.values.byName(j['outcome'] as String),
    at: DateTime.parse(j['at'] as String),
    rating: CallRating.values.asNameMap()[j['rating']],
  );
}

/// A time of day, stored as minutes since midnight.
class TimeOfDayMinutes {
  const TimeOfDayMinutes(this.hour, this.minute);
  final int hour;
  final int minute;

  int get totalMinutes => hour * 60 + minute;
  factory TimeOfDayMinutes.fromTotal(int m) =>
      TimeOfDayMinutes((m ~/ 60) % 24, m % 60);

  /// Tamil 12-hour label, e.g. "காலை 7:00", "இரவு 9:30".
  String get label {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12
        ? 'காலை'
        : hour < 16
        ? 'மதியம்'
        : hour < 19
        ? 'மாலை'
        : 'இரவு';
    return '$period $h12:${minute.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      other is TimeOfDayMinutes && other.hour == hour && other.minute == minute;
  @override
  int get hashCode => totalMinutes;
}

/// The three daily reminders. The roadmap caps notifications at three a day,
/// so this is the complete set: nothing else in the app may notify.
class ReminderSettings {
  const ReminderSettings({
    this.morningCheckIn = const TimeOfDayMinutes(7, 0),
    this.medicine = const TimeOfDayMinutes(8, 30),
    this.windDown = const TimeOfDayMinutes(21, 0),
    this.medicineName = '',
    this.enabled = true,
  });

  final TimeOfDayMinutes morningCheckIn;
  final TimeOfDayMinutes medicine;
  final TimeOfDayMinutes windDown;
  final String medicineName;
  final bool enabled;

  ReminderSettings copyWith({
    TimeOfDayMinutes? morningCheckIn,
    TimeOfDayMinutes? medicine,
    TimeOfDayMinutes? windDown,
    String? medicineName,
    bool? enabled,
  }) => ReminderSettings(
    morningCheckIn: morningCheckIn ?? this.morningCheckIn,
    medicine: medicine ?? this.medicine,
    windDown: windDown ?? this.windDown,
    medicineName: medicineName ?? this.medicineName,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toJson() => {
    'morningCheckIn': morningCheckIn.totalMinutes,
    'medicine': medicine.totalMinutes,
    'windDown': windDown.totalMinutes,
    'medicineName': medicineName,
    'enabled': enabled,
  };

  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
    morningCheckIn: TimeOfDayMinutes.fromTotal(
      j['morningCheckIn'] as int? ?? 420,
    ),
    medicine: TimeOfDayMinutes.fromTotal(j['medicine'] as int? ?? 510),
    windDown: TimeOfDayMinutes.fromTotal(j['windDown'] as int? ?? 1260),
    medicineName: j['medicineName'] as String? ?? '',
    enabled: j['enabled'] as bool? ?? true,
  );
}

/// Which side of the family this phone is.
/// Which kind of phone this is. [friend]: someone outside the family — a
/// helper who asks Appa questions, and/or a member of his retirees circle
/// (Phase 4). A friend phone never sees his stories, health or plan.
enum DeviceRole { appa, family, friend }

// ============================================================== Phase 2

/// One line of the daily plan he builds himself.
class PlanItem {
  PlanItem({
    required this.id,
    required this.day,
    required this.text,
    required this.createdAt,
    this.done = false,
    this.addedBy,
  });

  final String id;

  /// dayKey of the day the item is for.
  final String day;
  final String text;
  final DateTime createdAt;
  final bool done;

  /// null when Appa wrote it; otherwise the family member who asked
  /// (roadmap: "Amma can add one item a day").
  final String? addedBy;

  PlanItem copyWith({bool? done, String? text}) => PlanItem(
    id: id,
    day: day,
    text: text ?? this.text,
    createdAt: createdAt,
    done: done ?? this.done,
    addedBy: addedBy,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'done': done,
    'addedBy': addedBy,
  };

  factory PlanItem.fromJson(Map<String, dynamic> j) => PlanItem(
    id: j['id'] as String,
    day: j['day'] as String,
    text: j['text'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
    done: j['done'] as bool? ?? false,
    addedBy: j['addedBy'] as String?,
  );
}

enum HealthKind { bp, sugarFasting, sugarAfterFood }

/// A BP or sugar reading he (or Amma) noted down.
class HealthEntry {
  HealthEntry({
    required this.id,
    required this.at,
    required this.kind,
    required this.value,
    this.value2,
  });

  final String id;
  final DateTime at;
  final HealthKind kind;

  /// BP: systolic (top number). Sugar: mg/dL.
  final int value;

  /// BP: diastolic (bottom number). Null for sugar.
  final int? value2;

  String get display => kind == HealthKind.bp ? '$value/$value2' : '$value';

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'kind': kind.name,
    'value': value,
    'value2': value2,
  };

  factory HealthEntry.fromJson(Map<String, dynamic> j) => HealthEntry(
    id: j['id'] as String,
    at: DateTime.parse(j['at'] as String),
    kind: HealthKind.values.byName(j['kind'] as String),
    value: j['value'] as int,
    value2: j['value2'] as int?,
  );
}

/// What Appa has agreed the family may see. Stories are always shared once
/// sync is on (that is the point of them); everything else is off until he
/// turns it on, and he can turn any of it off again (roadmap: "Appa owns his
/// data").
class SharingSettings {
  const SharingSettings({
    this.health = false,
    this.sleep = false,
    this.plan = false,
  });
  final bool health;
  final bool sleep;
  final bool plan;

  SharingSettings copyWith({bool? health, bool? sleep, bool? plan}) =>
      SharingSettings(
        health: health ?? this.health,
        sleep: sleep ?? this.sleep,
        plan: plan ?? this.plan,
      );

  Map<String, dynamic> toJson() => {
    'health': health,
    'sleep': sleep,
    'plan': plan,
  };

  factory SharingSettings.fromJson(Map<String, dynamic> j) => SharingSettings(
    health: j['health'] as bool? ?? false,
    sleep: j['sleep'] as bool? ?? false,
    plan: j['plan'] as bool? ?? false,
  );
}

/// A question from family for Appa, answered by voice.
class FamilyQuestion {
  FamilyQuestion({
    required this.id,
    required this.authorName,
    required this.createdAt,
    this.text,
    this.localAudioPath,
    this.remoteAudioPath,
    this.answerLocalPath,
    this.answerRemotePath,
    this.answeredAt,
    this.outside = false,
    this.topic,
  });

  final String id;
  final String authorName;
  final DateTime createdAt;

  /// Phase 4 "Help others": asked by someone outside the immediate family.
  final bool outside;

  /// For outside questions: what it is about (see `helpTopics`).
  final String? topic;

  /// Typed question (read aloud to him), or null if asked by voice.
  final String? text;
  final String? localAudioPath;
  final String? remoteAudioPath;
  final String? answerLocalPath;
  final String? answerRemotePath;
  final DateTime? answeredAt;

  bool get answered => answeredAt != null;

  FamilyQuestion copyWith({
    String? localAudioPath,
    String? answerLocalPath,
    String? answerRemotePath,
    DateTime? answeredAt,
  }) => FamilyQuestion(
    id: id,
    authorName: authorName,
    createdAt: createdAt,
    text: text,
    localAudioPath: localAudioPath ?? this.localAudioPath,
    remoteAudioPath: remoteAudioPath,
    answerLocalPath: answerLocalPath ?? this.answerLocalPath,
    answerRemotePath: answerRemotePath ?? this.answerRemotePath,
    answeredAt: answeredAt ?? this.answeredAt,
    outside: outside,
    topic: topic,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'outside': outside,
    'topic': topic,
    'authorName': authorName,
    'createdAt': createdAt.toIso8601String(),
    'text': text,
    'localAudioPath': localAudioPath,
    'remoteAudioPath': remoteAudioPath,
    'answerLocalPath': answerLocalPath,
    'answerRemotePath': answerRemotePath,
    'answeredAt': answeredAt?.toIso8601String(),
  };

  factory FamilyQuestion.fromJson(Map<String, dynamic> j) => FamilyQuestion(
    id: j['id'] as String,
    authorName: j['authorName'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
    text: j['text'] as String?,
    localAudioPath: j['localAudioPath'] as String?,
    remoteAudioPath: j['remoteAudioPath'] as String?,
    answerLocalPath: j['answerLocalPath'] as String?,
    answerRemotePath: j['answerRemotePath'] as String?,
    answeredAt: j['answeredAt'] == null
        ? null
        : DateTime.parse(j['answeredAt'] as String),
    outside: j['outside'] as bool? ?? false,
    topic: j['topic'] as String?,
  );
}

// ============================================================== Phase 3

/// A follow-up question from family about one of his stories. It becomes a
/// later day's story question (roadmap: "Family can ask follow-up questions,
/// which generate the next day's prompt").
class StoryFollowUp {
  StoryFollowUp({
    required this.id,
    required this.storyId,
    required this.text,
    required this.authorName,
    required this.createdAt,
    this.usedOnDay,
  });

  final String id;
  final String storyId;
  final String text;
  final String authorName;
  final DateTime createdAt;

  /// dayKey of the day it was asked as the story question.
  final String? usedOnDay;

  StoryFollowUp usedOn(String day) => StoryFollowUp(
    id: id,
    storyId: storyId,
    text: text,
    authorName: authorName,
    createdAt: createdAt,
    usedOnDay: day,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'storyId': storyId,
    'text': text,
    'authorName': authorName,
    'createdAt': createdAt.toIso8601String(),
    'usedOnDay': usedOnDay,
  };

  factory StoryFollowUp.fromJson(Map<String, dynamic> j) => StoryFollowUp(
    id: j['id'] as String,
    storyId: j['storyId'] as String? ?? '',
    text: j['text'] as String? ?? '',
    authorName: j['authorName'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
    usedOnDay: j['usedOnDay'] as String?,
  );
}

/// Something he told the companion that it may remember. Shown to him on
/// "நீங்கள் சொன்னவை" and deletable one by one or all at once.
class MemoryFact {
  MemoryFact({required this.id, required this.text, required this.createdAt});
  final String id;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MemoryFact.fromJson(Map<String, dynamic> j) => MemoryFact(
    id: j['id'] as String,
    text: j['text'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

/// Feelings the companion noticed in a session. Only these labels are kept,
/// never what he said.
enum Feeling { unwanted, angry, lonely, sad }

/// What a companion session ended in.
enum OutwardAction { none, call, story, plan }

/// One companion conversation, as numbers only. No transcript is stored.
class CompanionSessionLog {
  CompanionSessionLog({
    required this.start,
    required this.end,
    required this.exchanges,
    required this.outward,
    this.feelings = const {},
  });

  final DateTime start;
  final DateTime end;
  final int exchanges;
  final OutwardAction outward;
  final Set<Feeling> feelings;

  Duration get length => end.difference(start);

  Map<String, dynamic> toJson() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'exchanges': exchanges,
    'outward': outward.name,
    'feelings': feelings.map((f) => f.name).toList(),
  };

  factory CompanionSessionLog.fromJson(Map<String, dynamic> j) =>
      CompanionSessionLog(
        start: DateTime.parse(j['start'] as String),
        end: DateTime.parse(j['end'] as String),
        exchanges: j['exchanges'] as int? ?? 0,
        outward:
            OutwardAction.values.asNameMap()[j['outward']] ??
            OutwardAction.none,
        feelings: {
          for (final f in (j['feelings'] as List? ?? []))
            if (Feeling.values.asNameMap()[f] != null)
              Feeling.values.asNameMap()[f]!,
        },
      );
}

/// His companion settings. He can change every one of these himself (exit
/// criterion: "he has turned off or adjusted at least one companion setting
/// himself").
class CompanionSettings {
  const CompanionSettings({
    this.enabled = true,
    this.minutes = 15,
    this.remember = true,
    this.changedByAppa = false,
  });

  final bool enabled;

  /// Soft session limit: 5, 10 or 15 (roadmap: about 15; shrink it if
  /// sessions lengthen).
  final int minutes;
  final bool remember;

  /// Set the first time he changes anything here himself.
  final bool changedByAppa;

  CompanionSettings copyWith({
    bool? enabled,
    int? minutes,
    bool? remember,
    bool? changedByAppa,
  }) => CompanionSettings(
    enabled: enabled ?? this.enabled,
    minutes: minutes ?? this.minutes,
    remember: remember ?? this.remember,
    changedByAppa: changedByAppa ?? this.changedByAppa,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'minutes': minutes,
    'remember': remember,
    'changedByAppa': changedByAppa,
  };

  factory CompanionSettings.fromJson(Map<String, dynamic> j) =>
      CompanionSettings(
        enabled: j['enabled'] as bool? ?? true,
        minutes: j['minutes'] as int? ?? 15,
        remember: j['remember'] as bool? ?? true,
        changedByAppa: j['changedByAppa'] as bool? ?? false,
      );
}

/// The patterns the app watches for (roadmap Phase 3 "Pattern surfacing").
enum PatternKind { badSleep, lowMood, noCalls }

/// A pattern noticed and what Appa decided about telling the family.
enum AlertDecision { pending, told, notTold }

class PatternAlert {
  PatternAlert({
    required this.id,
    required this.kind,
    required this.noticedOn,
    required this.decision,
    this.decidedAt,
  });

  final String id;
  final PatternKind kind;
  final String noticedOn; // dayKey
  final AlertDecision decision;
  final DateTime? decidedAt;

  PatternAlert decide(AlertDecision d, DateTime at) => PatternAlert(
    id: id,
    kind: kind,
    noticedOn: noticedOn,
    decision: d,
    decidedAt: at,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'noticedOn': noticedOn,
    'decision': decision.name,
    'decidedAt': decidedAt?.toIso8601String(),
  };

  factory PatternAlert.fromJson(Map<String, dynamic> j) => PatternAlert(
    id: j['id'] as String,
    kind: PatternKind.values.byName(j['kind'] as String),
    noticedOn: j['noticedOn'] as String,
    decision: AlertDecision.values.byName(j['decision'] as String),
    decidedAt: j['decidedAt'] == null
        ? null
        : DateTime.parse(j['decidedAt'] as String),
  );
}

/// Standing permissions he set himself: "you may always tell my son about
/// this". Off by default.
class AlertPermissions {
  const AlertPermissions({this.always = const {}, this.recipient = 'ராகுல்'});
  final Set<PatternKind> always;

  /// Who receives the short note.
  final String recipient;

  AlertPermissions copyWith({Set<PatternKind>? always, String? recipient}) =>
      AlertPermissions(
        always: always ?? this.always,
        recipient: recipient ?? this.recipient,
      );

  Map<String, dynamic> toJson() => {
    'always': always.map((k) => k.name).toList(),
    'recipient': recipient,
  };

  factory AlertPermissions.fromJson(Map<String, dynamic> j) => AlertPermissions(
    always: {
      for (final k in (j['always'] as List? ?? []))
        if (PatternKind.values.asNameMap()[k] != null)
          PatternKind.values.asNameMap()[k]!,
    },
    recipient: j['recipient'] as String? ?? 'ராகுல்',
  );
}

// ============================================================== Phase 4

/// Something he fixed or looked after (roadmap: "the bike, the water pump,
/// the fan, a neighbour's scooter. Photos, voice notes, dates").
class RepairEntry {
  RepairEntry({
    required this.id,
    required this.at,
    required this.item,
    this.note = '',
    this.photoPath,
    this.audioPath,
    this.forWhom,
  });

  final String id;
  final DateTime at;
  final String item;
  final String note;
  final String? photoPath;
  final String? audioPath;

  /// Null when it was his own; otherwise who he fixed it for.
  final String? forWhom;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'item': item,
    'note': note,
    'photoPath': photoPath,
    'audioPath': audioPath,
    'forWhom': forWhom,
  };

  factory RepairEntry.fromJson(Map<String, dynamic> j) => RepairEntry(
    id: j['id'] as String,
    at: DateTime.parse(j['at'] as String),
    item: j['item'] as String? ?? '',
    note: j['note'] as String? ?? '',
    photoPath: j['photoPath'] as String?,
    audioPath: j['audioPath'] as String?,
    forWhom: j['forWhom'] as String?,
  );
}

/// One line of the household ledger he keeps, if he wants to.
class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.at,
    required this.item,
    required this.amount,
  });
  final String id;
  final DateTime at;
  final String item;

  /// Whole rupees.
  final int amount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'item': item,
    'amount': amount,
  };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
    id: j['id'] as String,
    at: DateTime.parse(j['at'] as String),
    item: j['item'] as String? ?? '',
    amount: j['amount'] as int? ?? 0,
  );
}

/// A temple event, association meeting, walking group or reading group,
/// curated by family (roadmap: "Curated by family at first, not scraped").
class LocalEvent {
  LocalEvent({
    required this.id,
    required this.title,
    required this.place,
    required this.startsAt,
    this.note = '',
    this.addedBy = '',
    this.attended = false,
  });

  final String id;
  final String title;
  final String place;
  final DateTime startsAt;
  final String note;
  final String addedBy;

  /// He tapped "போனேன்" (I went) afterwards.
  final bool attended;

  LocalEvent copyWith({bool? attended}) => LocalEvent(
    id: id,
    title: title,
    place: place,
    startsAt: startsAt,
    note: note,
    addedBy: addedBy,
    attended: attended ?? this.attended,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'place': place,
    'startsAt': startsAt.toIso8601String(),
    'note': note,
    'addedBy': addedBy,
    'attended': attended,
  };

  factory LocalEvent.fromJson(Map<String, dynamic> j) => LocalEvent(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    place: j['place'] as String? ?? '',
    startsAt: DateTime.parse(j['startsAt'] as String),
    note: j['note'] as String? ?? '',
    addedBy: j['addedBy'] as String? ?? '',
    attended: j['attended'] as bool? ?? false,
  );
}

/// A member of the retirees circle, as other members see them.
class CircleMember {
  const CircleMember({
    required this.name,
    this.birthdayMonth,
    this.birthdayDay,
  });
  final String name;
  final int? birthdayMonth;
  final int? birthdayDay;
}

/// One voice answer to a circle's weekly prompt.
class CircleAnswer {
  const CircleAnswer({
    required this.id,
    required this.week,
    required this.authorName,
    required this.audioPath,
    required this.createdAt,
    this.mine = false,
  });

  final String id;

  /// ISO week key, e.g. "2026-W45".
  final String week;
  final String authorName;
  final String audioPath;
  final DateTime createdAt;
  final bool mine;
}
