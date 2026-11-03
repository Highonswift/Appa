import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Optional family sync over Supabase (free tier: 500 MB database, 1 GB file
/// storage, anonymous sign-in). Without it the app is fully usable on one
/// phone; with it, family members hear Appa's stories on their own phones
/// and send voice replies back.
///
/// Schema and row-level security: `supabase/schema.sql`. Every row and every
/// voice file is scoped to one household; a phone joins a household with a
/// six-character code shown on Appa's phone.
abstract class FamilySync {
  bool get connected;

  /// Signed in to the backend (even without a household, e.g. a friend who
  /// only joined the retirees circle).
  bool get online;
  String? get householdCode;

  Future<void> connect({required String url, required String key});

  /// Appa's phone: create the household and get its join code.
  Future<String> createHousehold({required String displayName});

  /// A family phone: join with the code from Appa's phone.
  Future<void> joinHousehold({
    required String code,
    required String displayName,
  });

  /// Restore a previous session's household on app start.
  Future<void> resume({required String householdCode});

  // Appa side
  Future<String> uploadStory(Story story);
  Future<List<RemoteReply>> fetchReplies();
  Future<String> downloadToFile(String remotePath, String localPath);
  Future<void> markReplyHeard(String replyId);

  // Family side
  Future<List<RemoteStory>> fetchStories();
  Future<void> uploadReply({
    required String storyId,
    required String localPath,
    required String authorName,
  });
  Future<String> signedUrl(String remotePath);

  // ---------------------------------------------------------- Phase 2

  /// Appa's phone: what he agreed to share. Revoking clears that data.
  Future<void> setSharing(SharingSettings s);

  /// Family phone: what Appa has agreed to share.
  Future<SharingSettings> fetchSharing();

  // Appa side mirrors (only called while that item is shared)
  Future<void> upsertHealth(List<HealthEntry> entries);
  Future<void> deleteHealth(String id);
  Future<void> upsertSleep(List<SleepEntry> entries);
  Future<void> upsertPlan(List<PlanItem> items);
  Future<void> deletePlan(String id);

  /// Removes everything of one kind ('health', 'sleep', 'plan').
  Future<void> clearShared(String kind);

  // Family reads
  Future<List<HealthEntry>> fetchHealth();
  Future<List<SleepEntry>> fetchSleep();
  Future<List<PlanItem>> fetchPlan();

  /// Family phone: one plan item a day for Appa (a request, not an order).
  Future<void> sendPlanRequest({
    required String day,
    required String text,
    required String authorName,
  });

  /// Appa's phone: fetch and remove pending plan requests.
  Future<List<PlanItem>> takePlanRequests();

  // Question board
  Future<void> askQuestion({
    required String id,
    String? text,
    String? localAudioPath,
    required String authorName,
    bool outside = false,
    String? topic,
  });
  Future<List<FamilyQuestion>> fetchQuestions();
  Future<String> answerQuestion({
    required String questionId,
    required String localPath,
  });

  // ---------------------------------------------------------- Phase 3

  /// Family: a follow-up question about one of his stories.
  Future<void> addFollowUp({
    required String id,
    required String storyId,
    required String text,
    required String authorName,
  });

  /// Appa: follow-ups not yet asked.
  Future<List<StoryFollowUp>> fetchFollowUps();
  Future<void> markFollowUpUsed(String id, String day);

  /// Appa: the story's written-out text, for the family's archive.
  Future<void> setTranscript(String storyId, String transcript);

  /// Appa: a short pattern note he agreed to send (never a transcript).
  Future<void> sendAlert({
    required String id,
    required String kind,
    required String note,
  });

  /// Family: notes not yet acknowledged.
  Future<List<FamilyAlert>> fetchAlerts();
  Future<void> ackAlert(String id);

  // ---------------------------------------------------------- Phase 4

  /// Appa: a code that lets outside helpers ask him questions (and nothing
  /// else). Same code each time once made.
  Future<String> helpCode();

  /// Any phone: join with a help code or a circle code. Returns which.
  Future<({String kind, String id})> joinByCode({
    required String code,
    required String displayName,
  });

  /// Events curated by family.
  Future<void> addEvent(LocalEvent e);
  Future<List<LocalEvent>> fetchEvents();
  Future<void> setEventAttended(String id, bool attended);

  /// Retirees circle (not tied to the family household).
  Future<({String id, String code})> createCircle({
    required String name,
    required String displayName,
  });
  void useCircle(String circleId);
  Future<List<CircleMember>> fetchCircleMembers();
  Future<void> setCircleBirthday(int? month, int? day);
  Future<List<CircleAnswer>> fetchCircleAnswers();
  Future<void> uploadCircleAnswer({
    required String week,
    required String localPath,
    required String authorName,
  });
  Future<String> circleSignedUrl(String path);

  // ---------------------------------------------------------- Phase 5

  /// Appa: per-day sleep hours and walked/not, only the columns he shares
  /// (others are sent as null). Never step counts.
  Future<void> upsertBody(
    List<({String day, int? sleepMinutes, bool? walked})> rows,
  );

  /// Family: what he shares.
  Future<List<({String day, int? sleepMinutes, bool? walked})>> fetchBody();
}

class FamilyAlert {
  const FamilyAlert({
    required this.id,
    required this.note,
    required this.createdAt,
  });
  final String id;
  final String note;
  final DateTime createdAt;
}

class RemoteStory {
  RemoteStory({
    required this.id,
    required this.promptText,
    required this.audioPath,
    required this.createdAt,
    required this.replyAuthors,
    this.transcript,
  });
  final String id;
  final String promptText;
  final String audioPath;
  final DateTime createdAt;
  final List<String> replyAuthors;
  final String? transcript;
}

class RemoteReply {
  RemoteReply({
    required this.id,
    required this.storyId,
    required this.authorName,
    required this.audioPath,
    required this.createdAt,
    required this.listened,
  });
  final String id;
  final String storyId;
  final String authorName;
  final String audioPath;
  final DateTime createdAt;
  final bool listened;
}

class SupabaseFamilySync implements FamilySync {
  static const bucket = 'voice';

  SupabaseClient? _client;
  String? _householdId;
  String? _code;

  @override
  bool get connected => _client != null && _householdId != null;

  @override
  bool get online => _client != null;

  @override
  String? get householdCode => _code;

  SupabaseClient get _c {
    final c = _client;
    if (c == null) throw StateError('Family sync is not connected');
    return c;
  }

  String get _hh {
    final h = _householdId;
    if (h == null) throw StateError('No household yet');
    return h;
  }

  @override
  Future<void> connect({required String url, required String key}) async {
    if (_client != null) return;
    try {
      await Supabase.initialize(url: url, publishableKey: key);
    } on AssertionError {
      // Already initialised in this process.
    }
    _client = Supabase.instance.client;
    if (_c.auth.currentSession == null) {
      await _c.auth.signInAnonymously();
    }
  }

  @override
  Future<String> createHousehold({required String displayName}) async {
    final res = await _c.rpc(
      'create_household',
      params: {'p_display_name': displayName},
    );
    final row = Map<String, dynamic>.from((res as List).first as Map);
    _householdId = row['household_id'] as String;
    _code = row['join_code'] as String;
    return _code!;
  }

  @override
  Future<void> joinHousehold({
    required String code,
    required String displayName,
  }) async {
    final res = await _c.rpc(
      'join_household',
      params: {
        'p_code': code.trim().toUpperCase(),
        'p_display_name': displayName,
      },
    );
    _householdId = res as String;
    _code = code.trim().toUpperCase();
  }

  @override
  Future<void> resume({required String householdCode}) async {
    final res = await _c.rpc('my_household');
    if (res == null) throw StateError('This phone is not in a household');
    _householdId = res as String;
    _code = householdCode;
  }

  @override
  Future<String> uploadStory(Story story) async {
    final local = story.localAudioPath;
    if (local == null) throw StateError('Story has no audio');
    final path = '$_hh/stories/${story.id}.m4a';
    await _c.storage
        .from(bucket)
        .upload(
          path,
          File(local),
          fileOptions: const FileOptions(
            contentType: 'audio/mp4',
            upsert: true,
          ),
        );
    await _c.from('stories').upsert({
      'id': story.id,
      'household_id': _hh,
      'prompt_id': story.promptId,
      'prompt_text': story.promptText,
      'audio_path': path,
      'created_at': story.createdAt.toUtc().toIso8601String(),
    });
    return path;
  }

  @override
  Future<List<RemoteReply>> fetchReplies() async {
    final rows = await _c
        .from('replies')
        .select('id, story_id, author_name, audio_path, created_at, listened')
        .eq('household_id', _hh)
        .order('created_at');
    return [
      for (final r in rows)
        RemoteReply(
          id: r['id'] as String,
          storyId: r['story_id'] as String,
          authorName: r['author_name'] as String? ?? '',
          audioPath: r['audio_path'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          listened: r['listened'] as bool? ?? false,
        ),
    ];
  }

  @override
  Future<String> downloadToFile(String remotePath, String localPath) async {
    final bytes = await _c.storage.from(bucket).download(remotePath);
    final f = File(localPath);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
    return localPath;
  }

  @override
  Future<void> markReplyHeard(String replyId) async {
    await _c.from('replies').update({'listened': true}).eq('id', replyId);
  }

  @override
  Future<List<RemoteStory>> fetchStories() async {
    final rows = await _c
        .from('stories')
        .select(
          'id, prompt_text, audio_path, created_at, transcript, replies(author_name)',
        )
        .eq('household_id', _hh)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        RemoteStory(
          id: r['id'] as String,
          promptText: r['prompt_text'] as String? ?? '',
          audioPath: r['audio_path'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          replyAuthors: [
            for (final rep in (r['replies'] as List? ?? []))
              (rep as Map)['author_name'] as String? ?? '',
          ],
          transcript: r['transcript'] as String?,
        ),
    ];
  }

  @override
  Future<void> uploadReply({
    required String storyId,
    required String localPath,
    required String authorName,
  }) async {
    final id =
        '${DateTime.now().millisecondsSinceEpoch}-${authorName.hashCode.abs()}';
    final path = '$_hh/replies/$storyId/$id.m4a';
    await _c.storage
        .from(bucket)
        .upload(
          path,
          File(localPath),
          fileOptions: const FileOptions(
            contentType: 'audio/mp4',
            upsert: true,
          ),
        );
    await _c.from('replies').insert({
      'story_id': storyId,
      'household_id': _hh,
      'author_name': authorName,
      'audio_path': path,
    });
  }

  @override
  Future<String> signedUrl(String remotePath) =>
      _c.storage.from(bucket).createSignedUrl(remotePath, 60 * 60);

  // ---------------------------------------------------------- Phase 2

  @override
  Future<void> setSharing(SharingSettings s) async {
    await _c.from('sharing').upsert({
      'household_id': _hh,
      'health': s.health,
      'sleep': s.sleep,
      'plan': s.plan,
      'walk': s.walk,
      'sleep_hours': s.sleepHours,
    });
    if (!s.health) await clearShared('health');
    if (!s.sleep) await clearShared('sleep');
    if (!s.plan) await clearShared('plan');
  }

  @override
  Future<SharingSettings> fetchSharing() async {
    final row = await _c
        .from('sharing')
        .select('health, sleep, plan, walk, sleep_hours')
        .eq('household_id', _hh)
        .maybeSingle();
    if (row == null) return const SharingSettings();
    return SharingSettings.fromJson({...row, 'sleepHours': row['sleep_hours']});
  }

  @override
  Future<void> upsertHealth(List<HealthEntry> entries) async {
    if (entries.isEmpty) return;
    await _c.from('health_entries').upsert([
      for (final e in entries)
        {
          'id': e.id,
          'household_id': _hh,
          'at': e.at.toUtc().toIso8601String(),
          'kind': e.kind.name,
          'value': e.value,
          'value2': e.value2,
        },
    ]);
  }

  @override
  Future<void> deleteHealth(String id) async {
    await _c.from('health_entries').delete().eq('id', id);
  }

  @override
  Future<void> upsertSleep(List<SleepEntry> entries) async {
    if (entries.isEmpty) return;
    await _c.from('sleep_entries').upsert([
      for (final e in entries)
        {
          'household_id': _hh,
          'day': e.day,
          'rating': e.rating.name,
          'recorded_at': e.recordedAt.toUtc().toIso8601String(),
        },
    ], onConflict: 'household_id,day');
  }

  @override
  Future<void> upsertPlan(List<PlanItem> items) async {
    if (items.isEmpty) return;
    await _c.from('plan_items').upsert([
      for (final p in items)
        {
          'id': p.id,
          'household_id': _hh,
          'day': p.day,
          'text': p.text,
          'done': p.done,
          'added_by': p.addedBy,
          'created_at': p.createdAt.toUtc().toIso8601String(),
        },
    ]);
  }

  @override
  Future<void> deletePlan(String id) async {
    await _c.from('plan_items').delete().eq('id', id);
  }

  @override
  Future<void> clearShared(String kind) async {
    final table = switch (kind) {
      'health' => 'health_entries',
      'sleep' => 'sleep_entries',
      'plan' => 'plan_items',
      _ => throw ArgumentError(kind),
    };
    await _c.from(table).delete().eq('household_id', _hh);
  }

  @override
  Future<List<HealthEntry>> fetchHealth() async {
    final rows = await _c
        .from('health_entries')
        .select('id, at, kind, value, value2')
        .eq('household_id', _hh)
        .order('at');
    return [
      for (final r in rows)
        HealthEntry(
          id: r['id'] as String,
          at: DateTime.parse(r['at'] as String).toLocal(),
          kind: HealthKind.values.byName(r['kind'] as String),
          value: r['value'] as int,
          value2: r['value2'] as int?,
        ),
    ];
  }

  @override
  Future<List<SleepEntry>> fetchSleep() async {
    final rows = await _c
        .from('sleep_entries')
        .select('day, rating, recorded_at')
        .eq('household_id', _hh)
        .order('day');
    return [
      for (final r in rows)
        SleepEntry(
          day: r['day'] as String,
          rating: SleepRating.values.byName(r['rating'] as String),
          recordedAt: DateTime.parse(r['recorded_at'] as String).toLocal(),
        ),
    ];
  }

  @override
  Future<List<PlanItem>> fetchPlan() async {
    final rows = await _c
        .from('plan_items')
        .select('id, day, text, done, added_by, created_at')
        .eq('household_id', _hh)
        .order('created_at');
    return [for (final r in rows) _planFromRow(r)];
  }

  PlanItem _planFromRow(Map<String, dynamic> r) => PlanItem(
    id: r['id'] as String,
    day: r['day'] as String,
    text: r['text'] as String? ?? '',
    done: r['done'] as bool? ?? false,
    addedBy: (r['added_by'] ?? r['author_name']) as String?,
    createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
  );

  @override
  Future<void> sendPlanRequest({
    required String day,
    required String text,
    required String authorName,
  }) async {
    await _c.from('plan_requests').insert({
      'household_id': _hh,
      'day': day,
      'text': text,
      'author_name': authorName,
    });
  }

  @override
  Future<List<PlanItem>> takePlanRequests() async {
    final rows = await _c
        .from('plan_requests')
        .select('id, day, text, author_name, created_at')
        .eq('household_id', _hh)
        .order('created_at');
    final items = [for (final r in rows) _planFromRow(r)];
    if (items.isNotEmpty) {
      await _c.from('plan_requests').delete().inFilter('id', [
        for (final i in items) i.id,
      ]);
    }
    return items;
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
    String? path;
    if (localAudioPath != null) {
      path = '$_hh/questions/$id.m4a';
      await _c.storage
          .from(bucket)
          .upload(
            path,
            File(localAudioPath),
            fileOptions: const FileOptions(
              contentType: 'audio/mp4',
              upsert: true,
            ),
          );
    }
    await _c.from('questions').insert({
      'id': id,
      'household_id': _hh,
      'author_name': authorName,
      'text': text,
      'audio_path': path,
      'outside': outside,
      'topic': topic,
    });
  }

  @override
  Future<List<FamilyQuestion>> fetchQuestions() async {
    final rows = await _c
        .from('questions')
        .select(
          'id, author_name, text, audio_path, answer_path, answered_at, created_at, outside, topic',
        )
        .eq('household_id', _hh)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        FamilyQuestion(
          id: r['id'] as String,
          authorName: r['author_name'] as String? ?? '',
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          text: r['text'] as String?,
          remoteAudioPath: r['audio_path'] as String?,
          answerRemotePath: r['answer_path'] as String?,
          answeredAt: r['answered_at'] == null
              ? null
              : DateTime.parse(r['answered_at'] as String).toLocal(),
          outside: r['outside'] as bool? ?? false,
          topic: r['topic'] as String?,
        ),
    ];
  }

  @override
  Future<String> answerQuestion({
    required String questionId,
    required String localPath,
  }) async {
    final path = '$_hh/answers/$questionId.m4a';
    await _c.storage
        .from(bucket)
        .upload(
          path,
          File(localPath),
          fileOptions: const FileOptions(
            contentType: 'audio/mp4',
            upsert: true,
          ),
        );
    await _c
        .from('questions')
        .update({
          'answer_path': path,
          'answered_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', questionId);
    return path;
  }
  // ---------------------------------------------------------- Phase 3

  @override
  Future<void> addFollowUp({
    required String id,
    required String storyId,
    required String text,
    required String authorName,
  }) async {
    await _c.from('story_followups').insert({
      'id': id,
      'household_id': _hh,
      'story_id': storyId,
      'text': text,
      'author_name': authorName,
    });
  }

  @override
  Future<List<StoryFollowUp>> fetchFollowUps() async {
    final rows = await _c
        .from('story_followups')
        .select('id, story_id, text, author_name, created_at, used_on')
        .eq('household_id', _hh)
        .order('created_at');
    return [
      for (final r in rows)
        StoryFollowUp(
          id: r['id'] as String,
          storyId: r['story_id'] as String,
          text: r['text'] as String? ?? '',
          authorName: r['author_name'] as String? ?? '',
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          usedOnDay: r['used_on'] as String?,
        ),
    ];
  }

  @override
  Future<void> markFollowUpUsed(String id, String day) async {
    await _c.from('story_followups').update({'used_on': day}).eq('id', id);
  }

  @override
  Future<void> setTranscript(String storyId, String transcript) async {
    await _c
        .from('stories')
        .update({'transcript': transcript})
        .eq('id', storyId);
  }

  @override
  Future<void> sendAlert({
    required String id,
    required String kind,
    required String note,
  }) async {
    await _c.from('alerts').upsert({
      'id': id,
      'household_id': _hh,
      'kind': kind,
      'note': note,
    });
  }

  @override
  Future<List<FamilyAlert>> fetchAlerts() async {
    final rows = await _c
        .from('alerts')
        .select('id, note, created_at')
        .eq('household_id', _hh)
        .isFilter('acknowledged_at', null)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        FamilyAlert(
          id: r['id'] as String,
          note: r['note'] as String? ?? '',
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        ),
    ];
  }

  @override
  Future<void> ackAlert(String id) async {
    await _c
        .from('alerts')
        .update({'acknowledged_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
  // ---------------------------------------------------------- Phase 4

  String? _circleId;

  String get _cid {
    final c = _circleId;
    if (c == null) throw StateError('Not in a circle');
    return c;
  }

  @override
  void useCircle(String circleId) => _circleId = circleId;

  @override
  Future<String> helpCode() async => await _c.rpc('help_code') as String;

  @override
  Future<({String kind, String id})> joinByCode({
    required String code,
    required String displayName,
  }) async {
    final res = Map<String, dynamic>.from(
      await _c.rpc(
        'join_by_code',
        params: {
          'p_code': code.trim().toUpperCase(),
          'p_display_name': displayName,
        },
      ) as Map,
    );
    final kind = res['kind'] as String;
    final id = res['id'] as String;
    if (kind == 'circle') {
      _circleId = id;
    } else {
      _householdId = id;
      _code ??= code.trim().toUpperCase();
    }
    return (kind: kind, id: id);
  }

  @override
  Future<void> addEvent(LocalEvent e) async {
    await _c.from('events').insert({
      'id': e.id,
      'household_id': _hh,
      'title': e.title,
      'place': e.place,
      'starts_at': e.startsAt.toUtc().toIso8601String(),
      'note': e.note,
      'added_by': e.addedBy,
    });
  }

  @override
  Future<List<LocalEvent>> fetchEvents() async {
    final rows = await _c
        .from('events')
        .select('id, title, place, starts_at, note, added_by, attended')
        .eq('household_id', _hh)
        .order('starts_at');
    return [
      for (final r in rows)
        LocalEvent(
          id: r['id'] as String,
          title: r['title'] as String? ?? '',
          place: r['place'] as String? ?? '',
          startsAt: DateTime.parse(r['starts_at'] as String).toLocal(),
          note: r['note'] as String? ?? '',
          addedBy: r['added_by'] as String? ?? '',
          attended: r['attended'] as bool? ?? false,
        ),
    ];
  }

  @override
  Future<void> setEventAttended(String id, bool attended) async {
    await _c.from('events').update({'attended': attended}).eq('id', id);
  }

  @override
  Future<({String id, String code})> createCircle({
    required String name,
    required String displayName,
  }) async {
    final row = Map<String, dynamic>.from(
      (await _c.rpc(
            'create_circle',
            params: {'p_name': name, 'p_display_name': displayName},
          ) as List).first
          as Map,
    );
    _circleId = row['circle_id'] as String;
    return (id: _circleId!, code: row['join_code'] as String);
  }

  @override
  Future<List<CircleMember>> fetchCircleMembers() async {
    final rows = await _c
        .from('circle_members')
        .select('display_name, birthday_month, birthday_day')
        .eq('circle_id', _cid)
        .order('joined_at');
    return [
      for (final r in rows)
        CircleMember(
          name: r['display_name'] as String? ?? '',
          birthdayMonth: r['birthday_month'] as int?,
          birthdayDay: r['birthday_day'] as int?,
        ),
    ];
  }

  @override
  Future<void> setCircleBirthday(int? month, int? day) async {
    await _c
        .from('circle_members')
        .update({'birthday_month': month, 'birthday_day': day})
        .eq('circle_id', _cid)
        .eq('user_id', _c.auth.currentUser!.id);
  }

  @override
  Future<List<CircleAnswer>> fetchCircleAnswers() async {
    final me = _c.auth.currentUser?.id;
    final rows = await _c
        .from('circle_answers')
        .select('id, week, author_id, author_name, audio_path, created_at')
        .eq('circle_id', _cid)
        .order('created_at', ascending: false)
        .limit(200);
    return [
      for (final r in rows)
        CircleAnswer(
          id: r['id'] as String,
          week: r['week'] as String,
          authorName: r['author_name'] as String? ?? '',
          audioPath: r['audio_path'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          mine: r['author_id'] == me,
        ),
    ];
  }

  @override
  Future<void> uploadCircleAnswer({
    required String week,
    required String localPath,
    required String authorName,
  }) async {
    final id = '${DateTime.now().millisecondsSinceEpoch}';
    final path = '$_cid/$week/$id.m4a';
    await _c.storage
        .from('circle')
        .upload(
          path,
          File(localPath),
          fileOptions: const FileOptions(
            contentType: 'audio/mp4',
            upsert: true,
          ),
        );
    await _c.from('circle_answers').insert({
      'circle_id': _cid,
      'week': week,
      'author_name': authorName,
      'audio_path': path,
    });
  }

  @override
  Future<String> circleSignedUrl(String path) =>
      _c.storage.from('circle').createSignedUrl(path, 60 * 60);
  // ---------------------------------------------------------- Phase 5

  @override
  Future<void> upsertBody(
    List<({String day, int? sleepMinutes, bool? walked})> rows,
  ) async {
    if (rows.isEmpty) return;
    await _c.from('body_days').upsert([
      for (final r in rows)
        {
          'household_id': _hh,
          'day': r.day,
          'sleep_minutes': r.sleepMinutes,
          'walked': r.walked,
        },
    ], onConflict: 'household_id,day');
  }

  @override
  Future<List<({String day, int? sleepMinutes, bool? walked})>>
  fetchBody() async {
    final rows = await _c
        .from('body_days')
        .select('day, sleep_minutes, walked')
        .eq('household_id', _hh)
        .order('day');
    return [
      for (final r in rows)
        (
          day: r['day'] as String,
          sleepMinutes: r['sleep_minutes'] as int?,
          walked: r['walked'] as bool?,
        ),
    ];
  }
}

/// Used when sync is not set up. Every remote call is a quiet no-op.
class NoFamilySync implements FamilySync {
  @override
  bool get connected => false;
  @override
  bool get online => connected;
  @override
  String? get householdCode => null;
  @override
  Future<void> connect({required String url, required String key}) async =>
      debugPrint('Family sync not available in this build');
  @override
  Future<String> createHousehold({required String displayName}) =>
      throw UnsupportedError('no sync');
  @override
  Future<void> joinHousehold({
    required String code,
    required String displayName,
  }) => throw UnsupportedError('no sync');
  @override
  Future<void> resume({required String householdCode}) async {}
  @override
  Future<String> uploadStory(Story story) => throw UnsupportedError('no sync');
  @override
  Future<List<RemoteReply>> fetchReplies() async => [];
  @override
  Future<String> downloadToFile(String remotePath, String localPath) =>
      throw UnsupportedError('no sync');
  @override
  Future<void> markReplyHeard(String replyId) async {}
  @override
  Future<List<RemoteStory>> fetchStories() async => [];
  @override
  Future<void> uploadReply({
    required String storyId,
    required String localPath,
    required String authorName,
  }) => throw UnsupportedError('no sync');
  @override
  Future<String> signedUrl(String remotePath) =>
      throw UnsupportedError('no sync');

  @override
  Future<void> setSharing(SharingSettings s) async {}
  @override
  Future<SharingSettings> fetchSharing() async => const SharingSettings();
  @override
  Future<void> upsertHealth(List<HealthEntry> entries) async {}
  @override
  Future<void> deleteHealth(String id) async {}
  @override
  Future<void> upsertSleep(List<SleepEntry> entries) async {}
  @override
  Future<void> upsertPlan(List<PlanItem> items) async {}
  @override
  Future<void> deletePlan(String id) async {}
  @override
  Future<void> clearShared(String kind) async {}
  @override
  Future<List<HealthEntry>> fetchHealth() async => [];
  @override
  Future<List<SleepEntry>> fetchSleep() async => [];
  @override
  Future<List<PlanItem>> fetchPlan() async => [];
  @override
  Future<void> sendPlanRequest({
    required String day,
    required String text,
    required String authorName,
  }) => throw UnsupportedError('no sync');
  @override
  Future<List<PlanItem>> takePlanRequests() async => [];
  @override
  Future<void> askQuestion({
    required String id,
    String? text,
    String? localAudioPath,
    required String authorName,
    bool outside = false,
    String? topic,
  }) => throw UnsupportedError('no sync');
  @override
  Future<List<FamilyQuestion>> fetchQuestions() async => [];
  @override
  Future<String> answerQuestion({
    required String questionId,
    required String localPath,
  }) => throw UnsupportedError('no sync');
  @override
  Future<void> addFollowUp({
    required String id,
    required String storyId,
    required String text,
    required String authorName,
  }) => throw UnsupportedError('no sync');
  @override
  Future<List<StoryFollowUp>> fetchFollowUps() async => [];
  @override
  Future<void> markFollowUpUsed(String id, String day) async {}
  @override
  Future<void> setTranscript(String storyId, String transcript) async {}
  @override
  Future<void> sendAlert({
    required String id,
    required String kind,
    required String note,
  }) => throw UnsupportedError('no sync');
  @override
  Future<List<FamilyAlert>> fetchAlerts() async => [];
  @override
  Future<void> ackAlert(String id) async {}
  @override
  Future<String> helpCode() => throw UnsupportedError('no sync');
  @override
  Future<({String kind, String id})> joinByCode({
    required String code,
    required String displayName,
  }) => throw UnsupportedError('no sync');
  @override
  Future<void> addEvent(LocalEvent e) => throw UnsupportedError('no sync');
  @override
  Future<List<LocalEvent>> fetchEvents() async => [];
  @override
  Future<void> setEventAttended(String id, bool attended) async {}
  @override
  Future<({String id, String code})> createCircle({
    required String name,
    required String displayName,
  }) => throw UnsupportedError('no sync');
  @override
  void useCircle(String circleId) {}
  @override
  Future<List<CircleMember>> fetchCircleMembers() async => [];
  @override
  Future<void> setCircleBirthday(int? month, int? day) async {}
  @override
  Future<List<CircleAnswer>> fetchCircleAnswers() async => [];
  @override
  Future<void> uploadCircleAnswer({
    required String week,
    required String localPath,
    required String authorName,
  }) => throw UnsupportedError('no sync');
  @override
  Future<String> circleSignedUrl(String path) =>
      throw UnsupportedError('no sync');
  @override
  Future<void> upsertBody(
    List<({String day, int? sleepMinutes, bool? walked})> rows,
  ) async {}
  @override
  Future<List<({String day, int? sleepMinutes, bool? walked})>>
  fetchBody() async => [];
}
