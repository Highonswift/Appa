import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'data/local_store.dart';
import 'data/scam_stories.dart';
import 'data/story_prompts.dart';
import 'logic/daily_picker.dart';
import 'logic/phase2.dart';
import 'models/models.dart';
import 'services/audio.dart';
import 'services/dictation.dart';
import 'services/phone.dart';
import 'services/reminders.dart';
import 'services/speech.dart';
import 'services/sync.dart';

/// The whole app's state. One ChangeNotifier, deliberately simple: one user,
/// one phone, a handful of lists.
class AppState extends ChangeNotifier {
  AppState({
    required this.store,
    required this.speaker,
    required this.audio,
    required this.reminders,
    required this.phone,
    required this.sync,
    required this.dictation,
    required this.sharer,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _load();
  }

  final LocalStore store;
  final Speaker speaker;
  final VoiceAudio audio;
  final Reminders reminders;
  final Phone phone;
  final FamilySync sync;
  final Dictation dictation;
  final Sharer sharer;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  DateTime get now => _clock();

  late DeviceRole? role;
  late String displayName;
  late List<Contact> contacts;
  late List<CallEvent> callEvents;
  late List<Story> stories;
  late List<SleepEntry> sleepEntries;
  late ReminderSettings reminderSettings;
  late Set<String> completedWalkthroughs;
  late List<PlanItem> planItems;
  late List<HealthEntry> healthEntries;
  late List<FamilyQuestion> questions;
  late SharingSettings sharing;
  late Set<String> realWorldDone;
  late Set<String> scamShared;

  /// Last sync problem, shown quietly in settings, never to Appa.
  String? syncError;
  bool syncing = false;

  void _load() {
    role = store.role;
    displayName = store.displayName;
    contacts = store.contacts;
    callEvents = store.callEvents;
    stories = store.stories..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    sleepEntries = store.sleepEntries;
    reminderSettings = store.reminders;
    completedWalkthroughs = store.completedWalkthroughs;
    planItems = store.planItems;
    healthEntries = store.healthEntries;
    questions = store.questions
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    sharing = store.sharing;
    realWorldDone = store.realWorldDone;
    scamShared = store.scamShared;
  }

  // ---------------------------------------------------------------- setup

  bool get isSetUp => role != null;

  Future<void> completeSetup({
    required DeviceRole role,
    required String name,
  }) async {
    this.role = role;
    displayName = name.trim();
    await store.setRole(role);
    await store.setDisplayName(displayName);
    if (role == DeviceRole.appa) await reminders.schedule(reminderSettings);
    notifyListeners();
  }

  // ---------------------------------------------------------------- stories

  /// Today's question. Stable for the whole day, even after he answers it.
  StoryPrompt get todaysPrompt {
    final today = dayKey(now);
    final answeredBefore = stories
        .where((s) => dayKey(s.createdAt) != today)
        .map((s) => s.promptId)
        .toSet();
    return promptForDay(now, answeredBeforeToday: answeredBefore);
  }

  bool get answeredToday =>
      stories.any((s) => dayKey(s.createdAt) == dayKey(now));

  int get unheardReplies => stories.fold(0, (n, s) => n + s.unheardReplies);

  Future<Story> saveStory({
    required String audioPath,
    StoryPrompt? prompt,
  }) async {
    final p = prompt ?? todaysPrompt;
    final story = Story(
      id: _uuid.v4(),
      promptId: p.id,
      promptText: p.tamil,
      createdAt: now,
      localAudioPath: audioPath,
    );
    stories = [story, ...stories];
    await store.saveStories(stories);
    notifyListeners();
    await pushStories();
    return story;
  }

  Future<void> deleteStory(String id) async {
    stories = stories.where((s) => s.id != id).toList();
    await store.saveStories(stories);
    notifyListeners();
  }

  /// A reply recorded on this same phone (for example Ragul sitting with him
  /// on a visit). Works without sync.
  Future<void> addLocalReply({
    required String storyId,
    required String author,
    required String audioPath,
  }) async {
    stories = [
      for (final s in stories)
        if (s.id == storyId)
          s.copyWith(
            replies: [
              ...s.replies,
              StoryReply(
                id: _uuid.v4(),
                authorName: author,
                createdAt: now,
                localAudioPath: audioPath,
              ),
            ],
          )
        else
          s,
    ];
    await store.saveStories(stories);
    notifyListeners();
  }

  Future<void> markReplyHeard(String storyId, String replyId) async {
    stories = [
      for (final s in stories)
        if (s.id == storyId)
          s.copyWith(
            replies: [
              for (final r in s.replies)
                r.id == replyId ? r.copyWith(listened: true) : r,
            ],
          )
        else
          s,
    ];
    await store.saveStories(stories);
    notifyListeners();
    if (sync.connected) {
      try {
        await sync.markReplyHeard(replyId);
      } catch (e) {
        syncError = '$e';
      }
    }
  }

  // ---------------------------------------------------------------- calls

  Contact? get todaysContact => contactForDay(now, contacts, callEvents);
  CallEvent? get todaysCall => todaysCallEvent(now, callEvents);

  Contact? contactById(String id) {
    for (final c in contacts) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> callContact(Contact c) async {
    final ok = await phone.call(c.phone);
    if (!ok) return;
    final t = now;
    callEvents = [
      ...callEvents,
      CallEvent(
        day: dayKey(t),
        contactId: c.id,
        outcome: CallOutcome.called,
        at: t,
      ),
    ];
    contacts = [
      for (final x in contacts) x.id == c.id ? x.copyWith(lastCalled: t) : x,
    ];
    await store.saveCallEvents(callEvents);
    await store.saveContacts(contacts);
    notifyListeners();
  }

  /// "Not today" — accepted without question, no guilt, no re-asking today.
  Future<void> notToday(Contact c) async {
    final t = now;
    callEvents = [
      ...callEvents,
      CallEvent(
        day: dayKey(t),
        contactId: c.id,
        outcome: CallOutcome.notToday,
        at: t,
      ),
    ];
    await store.saveCallEvents(callEvents);
    notifyListeners();
  }

  Future<void> saveContact(Contact c) async {
    final exists = contacts.any((x) => x.id == c.id);
    contacts = exists
        ? [for (final x in contacts) x.id == c.id ? c : x]
        : [...contacts, c];
    await store.saveContacts(contacts);
    notifyListeners();
  }

  Future<void> removeContact(String id) async {
    contacts = contacts.where((c) => c.id != id).toList();
    await store.saveContacts(contacts);
    notifyListeners();
  }

  String newId() => _uuid.v4();

  // ---------------------------------------------------------------- sleep

  SleepEntry? get todaysSleep => sleepEntryFor(now, sleepEntries);

  Future<void> rateSleep(SleepRating r) async {
    final t = now;
    final key = dayKey(t);
    sleepEntries = [
      ...sleepEntries.where((e) => e.day != key),
      SleepEntry(day: key, rating: r, recordedAt: t),
    ];
    await store.saveSleepEntries(sleepEntries);
    notifyListeners();
    await _mirror(
      'sleep',
      () => sync.upsertSleep(sleepEntries.where((e) => e.day == key).toList()),
    );
  }

  List<SleepRating?> get lastWeekSleep => sleepWindow(now, sleepEntries);

  // ---------------------------------------------------------------- reminders

  Future<void> updateReminders(ReminderSettings s) async {
    reminderSettings = s;
    await store.saveReminders(s);
    await reminders.schedule(s);
    notifyListeners();
  }

  // ---------------------------------------------------------------- walkthroughs

  /// Acknowledged once, quietly. Returns true the first time only.
  Future<bool> markWalkthroughDone(String id) async {
    if (completedWalkthroughs.contains(id)) return false;
    completedWalkthroughs = {...completedWalkthroughs, id};
    await store.saveCompletedWalkthroughs(completedWalkthroughs);
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------- family sync

  bool get syncConfigured => store.syncUrl != null && store.syncKey != null;

  /// Reconnect on start if sync was set up before. Never blocks the app.
  Future<void> resumeSync() async {
    final url = store.syncUrl, key = store.syncKey, code = store.householdCode;
    if (url == null || key == null || code == null) return;
    try {
      await sync.connect(url: url, key: key);
      await sync.resume(householdCode: code);
      syncError = null;
      if (role == DeviceRole.appa) {
        await pullReplies();
        await pullPhase2();
      } else {
        await loadFamilyExtras();
      }
    } catch (e) {
      syncError = '$e';
    }
    notifyListeners();
  }

  /// Set up sync from settings. Appa's phone creates the household; a family
  /// phone joins with [joinCode].
  Future<String?> setUpSync({
    required String url,
    required String key,
    String? joinCode,
  }) async {
    syncing = true;
    notifyListeners();
    try {
      await sync.connect(url: url.trim(), key: key.trim());
      String code;
      if (role == DeviceRole.appa) {
        code = await sync.createHousehold(displayName: displayName);
      } else {
        if (joinCode == null || joinCode.trim().isEmpty) {
          throw ArgumentError('Join code needed');
        }
        await sync.joinHousehold(code: joinCode, displayName: displayName);
        code = joinCode.trim().toUpperCase();
      }
      await store.saveSync(
        url: url.trim(),
        key: key.trim(),
        householdCode: code,
      );
      syncError = null;
      if (role == DeviceRole.appa) await pushStories();
      return code;
    } catch (e) {
      syncError = '$e';
      return null;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// Upload stories not yet shared. Called after each recording; failures
  /// are retried next time (offline-first).
  Future<void> pushStories() async {
    if (!sync.connected || role != DeviceRole.appa) return;
    var changed = false;
    final updated = <Story>[];
    for (final s in stories) {
      if (!s.synced && s.localAudioPath != null) {
        try {
          final path = await sync.uploadStory(s);
          updated.add(s.copyWith(remoteAudioPath: path));
          changed = true;
          continue;
        } catch (e) {
          syncError = '$e';
        }
      }
      updated.add(s);
    }
    if (changed) {
      stories = updated;
      await store.saveStories(stories);
      notifyListeners();
    }
  }

  /// Fetch family voice replies and keep a local copy so they play offline.
  Future<void> pullReplies() async {
    if (!sync.connected || role != DeviceRole.appa) return;
    try {
      await pushStories();
      final remote = await sync.fetchReplies();
      var next = stories;
      for (final r in remote) {
        final idx = next.indexWhere((s) => s.id == r.storyId);
        if (idx < 0) continue;
        final s = next[idx];
        if (s.replies.any((x) => x.id == r.id)) continue;
        final local = await audio.filePath('reply-${r.id}.m4a');
        await sync.downloadToFile(r.audioPath, local);
        final reply = StoryReply(
          id: r.id,
          authorName: r.authorName,
          createdAt: r.createdAt,
          localAudioPath: local,
          remoteAudioPath: r.audioPath,
          listened: r.listened,
        );
        next = [...next]..[idx] = s.copyWith(replies: [...s.replies, reply]);
      }
      stories = next;
      await store.saveStories(stories);
      syncError = null;
    } catch (e) {
      syncError = '$e';
    }
    notifyListeners();
  }

  // Family side -----------------------------------------------------------

  List<RemoteStory> familyStories = [];

  Set<String> get seenFamilyStories => store.seenFamilyStories;

  Future<void> loadFamilyStories() async {
    if (!sync.connected) return;
    syncing = true;
    notifyListeners();
    try {
      familyStories = await sync.fetchStories();
      syncError = null;
    } catch (e) {
      syncError = '$e';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> markFamilyStorySeen(String id) async {
    await store.saveSeenFamilyStories({...store.seenFamilyStories, id});
    notifyListeners();
  }

  Future<bool> sendFamilyReply({
    required String storyId,
    required String audioPath,
  }) async {
    try {
      await sync.uploadReply(
        storyId: storyId,
        localPath: audioPath,
        authorName: displayName,
      );
      await loadFamilyStories();
      return true;
    } catch (e) {
      syncError = '$e';
      notifyListeners();
      return false;
    }
  }

  // ================================================================ Phase 2

  /// Runs a mirror write only while that kind is shared and sync is on.
  /// Failures are kept quiet (offline-first) and retried on the next push.
  Future<void> _mirror(String kind, Future<void> Function() write) async {
    if (role != DeviceRole.appa || !sync.connected) return;
    final on = switch (kind) {
      'health' => sharing.health,
      'sleep' => sharing.sleep,
      'plan' => sharing.plan,
      _ => true,
    };
    if (!on) return;
    try {
      await write();
    } catch (e) {
      syncError = '$e';
    }
  }

  /// Appa's phone: bring in family questions and plan requests, and push
  /// whatever he has shared.
  Future<void> pullPhase2() async {
    if (!sync.connected || role != DeviceRole.appa) return;
    try {
      await sync.setSharing(sharing);
      final requests = await sync.takePlanRequests();
      for (final r in requests) {
        if (familyCanAdd(r.addedBy ?? '', r.day, planItems)) {
          planItems = [...planItems, r];
        }
      }
      if (requests.isNotEmpty) await store.savePlanItems(planItems);
      await _pullQuestions();
      await _pushShared();
      syncError = null;
    } catch (e) {
      syncError = '$e';
    }
    notifyListeners();
  }

  Future<void> _pushShared() async {
    final since = dayKey(now.subtract(const Duration(days: 90)));
    await _mirror('health', () => sync.upsertHealth(healthEntries));
    await _mirror(
      'sleep',
      () => sync.upsertSleep(
        sleepEntries.where((e) => e.day.compareTo(since) >= 0).toList(),
      ),
    );
    await _mirror(
      'plan',
      () => sync.upsertPlan(
        planItems.where((p) => p.day.compareTo(since) >= 0).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------- sharing

  /// He turns each item on or off himself. Off deletes the family's copy.
  Future<void> updateSharing(SharingSettings s) async {
    sharing = s;
    await store.saveSharing(s);
    notifyListeners();
    if (role == DeviceRole.appa && sync.connected) {
      try {
        await sync.setSharing(s);
        await _pushShared();
      } catch (e) {
        syncError = '$e';
      }
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- plan

  String get todayKey => dayKey(now);
  String get tomorrowKey => dayKey(now.add(const Duration(days: 1)));

  List<PlanItem> planForDay(String day) => planFor(day, planItems);

  Future<void> addPlanItem(String text, {String? day, String? addedBy}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final item = PlanItem(
      id: _uuid.v4(),
      day: day ?? todayKey,
      text: t,
      createdAt: now,
      addedBy: addedBy,
    );
    planItems = [...planItems, item];
    await store.savePlanItems(planItems);
    notifyListeners();
    await _mirror('plan', () => sync.upsertPlan([item]));
  }

  /// A family member adding on Appa's phone: one item a day each.
  Future<bool> addFamilyPlanItem({
    required String author,
    required String text,
  }) async {
    final a = author.trim().isEmpty ? 'குடும்பம்' : author.trim();
    if (!familyCanAdd(a, todayKey, planItems)) return false;
    await addPlanItem(text, addedBy: a);
    return true;
  }

  Future<void> togglePlanItem(String id) async {
    PlanItem? changed;
    planItems = [
      for (final p in planItems)
        if (p.id == id) changed = p.copyWith(done: !p.done) else p,
    ];
    await store.savePlanItems(planItems);
    notifyListeners();
    if (changed != null) {
      await _mirror('plan', () => sync.upsertPlan([changed!]));
    }
  }

  Future<void> removePlanItem(String id) async {
    planItems = planItems.where((p) => p.id != id).toList();
    await store.savePlanItems(planItems);
    notifyListeners();
    await _mirror('plan', () => sync.deletePlan(id));
  }

  /// Copy yesterday's own items (not family requests) to [day], unticked.
  Future<int> repeatYesterday(String day) async {
    final d = DateTime.parse(day);
    final yesterday = dayKey(d.subtract(const Duration(days: 1)));
    final existing = planForDay(day).map((p) => p.text).toSet();
    final copy = planForDay(yesterday)
        .where((p) => p.addedBy == null && !existing.contains(p.text));
    var n = 0;
    for (final p in copy) {
      await addPlanItem(p.text, day: day);
      n++;
    }
    return n;
  }

  // ---------------------------------------------------------------- health

  /// Saves a reading; returns a gentle message instead if it looks mistyped.
  Future<String?> addHealth(HealthKind kind, int? value, [int? value2]) async {
    final problem = validateHealth(kind, value, value2);
    if (problem != null) return problem;
    final e = HealthEntry(
      id: _uuid.v4(),
      at: now,
      kind: kind,
      value: value!,
      value2: value2,
    );
    healthEntries = [...healthEntries, e];
    await store.saveHealthEntries(healthEntries);
    notifyListeners();
    await _mirror('health', () => sync.upsertHealth([e]));
    return null;
  }

  Future<void> removeHealth(String id) async {
    healthEntries = healthEntries.where((e) => e.id != id).toList();
    await store.saveHealthEntries(healthEntries);
    notifyListeners();
    await _mirror('health', () => sync.deleteHealth(id));
  }

  List<HealthEntry> healthOf(HealthKind kind, {int days = 56}) =>
      healthSeries(healthEntries, kind, now, days: days);

  // ---------------------------------------------------------------- questions

  int get unansweredQuestions => questions.where((q) => !q.answered).length;

  /// A family member asking on Appa's phone (works with no internet).
  Future<void> addLocalQuestion({
    required String author,
    String? text,
    String? audioPath,
  }) async {
    if ((text == null || text.trim().isEmpty) && audioPath == null) return;
    final q = FamilyQuestion(
      id: _uuid.v4(),
      authorName: author.trim().isEmpty ? 'குடும்பம்' : author.trim(),
      createdAt: now,
      text: text?.trim().isEmpty ?? true ? null : text!.trim(),
      localAudioPath: audioPath,
    );
    questions = [q, ...questions];
    await store.saveQuestions(questions);
    notifyListeners();
  }

  Future<void> answerQuestion(String id, String audioPath) async {
    questions = [
      for (final q in questions)
        q.id == id
            ? q.copyWith(answerLocalPath: audioPath, answeredAt: now)
            : q,
    ];
    await store.saveQuestions(questions);
    notifyListeners();
    if (sync.connected && role == DeviceRole.appa) {
      final q = questions.firstWhere((x) => x.id == id);
      if (q.remoteAudioPath != null || q.text != null) {
        try {
          final remote = await sync.answerQuestion(
            questionId: id,
            localPath: audioPath,
          );
          questions = [
            for (final x in questions)
              x.id == id ? x.copyWith(answerRemotePath: remote) : x,
          ];
          await store.saveQuestions(questions);
        } catch (e) {
          syncError = '$e';
        }
        notifyListeners();
      }
    }
  }

  Future<void> _pullQuestions() async {
    final remote = await sync.fetchQuestions();
    var next = [...questions];
    for (final r in remote) {
      final i = next.indexWhere((q) => q.id == r.id);
      if (i >= 0) continue;
      var q = r;
      if (r.remoteAudioPath != null) {
        final local = await audio.filePath('question-${r.id}.m4a');
        await sync.downloadToFile(r.remoteAudioPath!, local);
        q = q.copyWith(localAudioPath: local);
      }
      next.add(q);
    }
    // Answers recorded while offline: upload now.
    for (final q in next.where(
      (q) =>
          q.answered && q.answerRemotePath == null && q.answerLocalPath != null,
    )) {
      if (!remote.any((r) => r.id == q.id)) continue;
      final path = await sync.answerQuestion(
        questionId: q.id,
        localPath: q.answerLocalPath!,
      );
      next = [
        for (final x in next)
          x.id == q.id ? x.copyWith(answerRemotePath: path) : x,
      ];
    }
    next.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    questions = next;
    await store.saveQuestions(questions);
  }

  // ---------------------------------------------------------------- learning

  Future<void> markRealWorldDone(String walkthroughId) async {
    realWorldDone = {...realWorldDone, walkthroughId};
    await store.saveRealWorldDone(realWorldDone);
    notifyListeners();
  }

  ScamStory get thisWeeksScam => scamForWeek(now);
  List<ScamStory> get scamHistory => scamArchive(now);

  /// Opens the share sheet; he picks the friends.
  Future<void> shareScam(ScamStory story) async {
    final ok = await sharer.shareText(story.shareText(displayName));
    if (ok) {
      scamShared = {...scamShared, story.id};
      await store.saveScamShared(scamShared);
      notifyListeners();
    }
  }

  WeeklyReview get review => weeklyReview(
    now: now,
    stories: stories,
    calls: callEvents,
    walkthroughsDone: completedWalkthroughs,
    realWorldDone: realWorldDone,
    questions: questions,
    sleep: sleepEntries,
    plan: planItems,
  );

  // ---------------------------------------------------------------- family phone

  SharingSettings familySharing = const SharingSettings();
  List<HealthEntry> familyHealth = [];
  List<SleepEntry> familySleep = [];
  List<PlanItem> familyPlan = [];
  List<FamilyQuestion> familyQuestions = [];

  Future<void> loadFamilyExtras() async {
    if (!sync.connected || role != DeviceRole.family) return;
    try {
      familySharing = await sync.fetchSharing();
      familyQuestions = await sync.fetchQuestions();
      familyHealth = familySharing.health ? await sync.fetchHealth() : [];
      familySleep = familySharing.sleep ? await sync.fetchSleep() : [];
      familyPlan = familySharing.plan ? await sync.fetchPlan() : [];
      syncError = null;
    } catch (e) {
      syncError = '$e';
    }
    notifyListeners();
  }

  Future<bool> askFamilyQuestion({String? text, String? audioPath}) async {
    try {
      await sync.askQuestion(
        id: _uuid.v4(),
        text: text,
        localAudioPath: audioPath,
        authorName: displayName,
      );
      await loadFamilyExtras();
      return true;
    } catch (e) {
      syncError = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPlanRequest(String text) async {
    try {
      await sync.sendPlanRequest(
        day: todayKey,
        text: text.trim(),
        authorName: displayName,
      );
      return true;
    } catch (e) {
      syncError = '$e';
      notifyListeners();
      return false;
    }
  }
}
