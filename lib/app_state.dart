import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'data/local_store.dart';
import 'data/scam_stories.dart';
import 'data/story_prompts.dart';
import 'logic/daily_picker.dart';
import 'logic/archive_export.dart';
import 'logic/companion.dart';
import 'logic/phase2.dart';
import 'logic/phase3.dart';
import 'logic/phase4.dart';
import 'models/models.dart';
import 'services/audio.dart';
import 'services/companion_model.dart';
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
    CompanionModel? companionModel,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _fixedModel = companionModel {
    _load();
  }

  /// Set in tests; otherwise built from the key saved in settings.
  final CompanionModel? _fixedModel;
  late CompanionModel companionModel;

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
  late List<StoryFollowUp> followUps;
  late List<MemoryFact> memory;
  late List<CompanionSessionLog> sessions;
  late CompanionSettings companionSettings;
  late List<PatternAlert> alerts;
  late List<RepairEntry> repairs;
  late List<LedgerEntry> ledger;
  late bool ledgerEnabled;
  late List<LocalEvent> events;
  late AlertPermissions alertPermissions;
  DateTime? firstUse;

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
    followUps = store.followUps;
    memory = store.memory;
    sessions = store.sessions;
    companionSettings = store.companionSettings;
    alerts = store.alerts;
    alertPermissions = store.alertPermissions;
    firstUse = store.firstUse;
    repairs = store.repairs..sort((a, b) => b.at.compareTo(a.at));
    ledger = store.ledger;
    ledgerEnabled = store.ledgerEnabled;
    events = store.events;
    _buildModel();
  }

  void _buildModel() {
    companionModel =
        _fixedModel ??
        (store.geminiKey.isEmpty
            ? NoCompanionModel()
            : GeminiCompanionModel(
                apiKey: store.geminiKey,
                model: store.geminiModel,
              ));
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
    if (firstUse == null) {
      firstUse = now;
      await store.saveFirstUse(now);
    }
    if (role == DeviceRole.appa) await reminders.schedule(reminderSettings);
    notifyListeners();
  }

  // ---------------------------------------------------------------- stories

  /// Today's question. Stable for the whole day, even after he answers it.
  StoryPrompt get todaysPrompt {
    final assigned = followUps
        .where((f) => f.usedOnDay == dayKey(now))
        .firstOrNull;
    if (assigned != null) return followUpPrompt(assigned);
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

  Contact? get todaysContact => tunedContactForDay(now, contacts, callEvents);
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
    if (role == DeviceRole.friend) return _resumeFriend();
    if (url == null || key == null || code == null) return;
    try {
      await sync.connect(url: url, key: key);
      await sync.resume(householdCode: code);
      syncError = null;
      if (role == DeviceRole.appa) {
        await pullReplies();
        await pullPhase2();
        await pullPhase3();
        await pullPhase4();
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
      familyAlerts = await sync.fetchAlerts();
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

  // ================================================================ Phase 3

  // ---------------------------------------------------------------- calls

  /// The call he made today and hasn't rated ("Good call?"), if any.
  CallEvent? get unratedCall => unratedCallToday(now, callEvents);

  /// One tap after a call. Tunes who is suggested next.
  Future<void> rateCall(CallRating r) async {
    final target = unratedCall;
    if (target == null) return;
    callEvents = [
      for (final e in callEvents) identical(e, target) ? e.withRating(r) : e,
    ];
    await store.saveCallEvents(callEvents);
    notifyListeners();
  }

  /// Birthdays and festivals today and tomorrow.
  List<Occasion> get occasions => upcomingOccasions(now, contacts);

  // ---------------------------------------------------------------- story archive

  StoryPrompt followUpPrompt(StoryFollowUp f) => StoryPrompt(
    'followup:${f.storyId}:${f.id}',
    '${f.authorName} கேட்கிறார்கள்: ${f.text}',
    '',
  );

  /// Turns the oldest waiting follow-up into today's question, once a day,
  /// and only if he hasn't already answered today's question.
  Future<void> ensureTodaysFollowUp() async {
    if (answeredToday) return;
    final r = followUpForDay(todayKey, followUps);
    if (!r.assign || r.followUp == null) return;
    final used = r.followUp!.usedOn(todayKey);
    followUps = [for (final f in followUps) f.id == used.id ? used : f];
    await store.saveFollowUps(followUps);
    notifyListeners();
    if (sync.connected && role == DeviceRole.appa && used.storyId.isNotEmpty) {
      try {
        await sync.markFollowUpUsed(used.id, todayKey);
      } catch (e) {
        syncError = '$e';
      }
    }
  }

  /// A follow-up asked on this phone (family on a visit, or the companion's
  /// "put that in tomorrow's story"). Becomes a later day's question.
  Future<void> addFollowUp({
    required String storyId,
    required String text,
    required String author,
  }) async {
    if (text.trim().isEmpty) return;
    followUps = [
      ...followUps,
      StoryFollowUp(
        id: _uuid.v4(),
        storyId: storyId,
        text: text.trim(),
        authorName: author.trim(),
        createdAt: now,
      ),
    ];
    await store.saveFollowUps(followUps);
    notifyListeners();
  }

  int get waitingFollowUps =>
      followUps.where((f) => f.usedOnDay == null).length;

  StoryTheme themeOf(Story s) {
    if (!s.promptId.startsWith('followup:')) return themeOfPrompt(s.promptId);
    final parentId = s.promptId.split(':')[1];
    final parent = stories.where((x) => x.id == parentId).firstOrNull;
    return parent == null ? StoryTheme.life : themeOf(parent);
  }

  Map<StoryTheme, List<Story>> get storiesByTheme {
    final out = {for (final t in StoryTheme.values) t: <Story>[]};
    for (final st in stories) {
      out[themeOf(st)]!.add(st);
    }
    return out;
  }

  /// Appa's phone: bring in family follow-ups.
  Future<void> pullPhase3() async {
    if (!sync.connected || role != DeviceRole.appa) return;
    try {
      final remote = await sync.fetchFollowUps();
      final known = {for (final f in followUps) f.id};
      final added = remote.where((r) => !known.contains(r.id)).toList();
      if (added.isNotEmpty) {
        followUps = [...followUps, ...added];
        await store.saveFollowUps(followUps);
      }
      await ensureTodaysFollowUp();
      syncError = null;
    } catch (e) {
      syncError = '$e';
    }
    notifyListeners();
  }

  bool transcribing = false;

  /// Writes out a story's text (sent to the model for transcription only).
  Future<bool> transcribeStory(String id) async {
    final st = stories.where((x) => x.id == id).firstOrNull;
    if (st == null || st.localAudioPath == null || !companionModel.configured) {
      return false;
    }
    String? text;
    try {
      text = await companionModel.transcribe(st.localAudioPath!);
    } catch (e) {
      syncError = '$e';
    }
    if (text == null || text.isEmpty) return false;
    stories = [
      for (final x in stories) x.id == id ? x.copyWith(transcript: text) : x,
    ];
    await store.saveStories(stories);
    notifyListeners();
    if (sync.connected && role == DeviceRole.appa && st.synced) {
      try {
        await sync.setTranscript(id, text);
      } catch (e) {
        syncError = '$e';
      }
    }
    return true;
  }

  Future<int> transcribeAll() async {
    transcribing = true;
    notifyListeners();
    var n = 0;
    for (final st in stories.where((x) => x.transcript == null).toList()) {
      if (await transcribeStory(st.id)) n++;
    }
    transcribing = false;
    notifyListeners();
    return n;
  }

  /// Zips every story's audio plus one transcript file and opens the share
  /// sheet, so he can give the archive to his grandchildren.
  Future<bool> exportArchive() async {
    final themed = [
      for (final t in StoryTheme.values)
        for (final st in storiesByTheme[t]!.reversed) (theme: t, story: st),
    ];
    final bytes = buildArchiveZip(
      appaName: displayName,
      items: themed,
      readAudio: (p) => File(p).readAsBytesSync(),
    );
    final path = await audio.filePath('appa-kathaigal.zip');
    await File(path).writeAsBytes(bytes, flush: true);
    return sharer.shareFiles([path], '$displayName அவர்களின் கதைகள்');
  }

  // ---------------------------------------------------------------- companion

  bool get companionAvailable =>
      role == DeviceRole.appa &&
      companionSettings.enabled &&
      companionModel.configured;

  String get familyPerson => alertPermissions.recipient;

  CompanionConversation startCompanion() => CompanionConversation(
    model: companionModel,
    context: CompanionContext(
      appaName: displayName,
      contacts: contacts,
      memory: memory,
      todaysPlan: planForDay(todayKey).map((p) => p.text).toList(),
      settings: companionSettings,
      familyPerson: familyPerson,
    ),
    start: now,
  );

  /// He tapped the suggestion's button.
  Future<void> takeSuggestion(CompanionConversation c, Suggestion sug) async {
    c.took(sug.type);
    switch (sug.type) {
      case SuggestionType.call:
        if (sug.contact != null) await callContact(sug.contact!);
      case SuggestionType.story:
        await addFollowUp(
          storyId: '',
          text:
              'இன்று பேசியதை குடும்பத்துக்கு விரிவாகச் சொல்லுங்கள்: ${sug.text ?? ''}',
          author: 'நீங்கள்',
        );
      case SuggestionType.plan:
        await addPlanItem(sug.text ?? '');
      case SuggestionType.none:
        break;
    }
  }

  /// Saves the numbers (no transcript) and anything he let it remember.
  Future<void> endCompanion(CompanionConversation c) async {
    final log = c.finish(now);
    sessions = [...sessions, log];
    await store.saveSessions(sessions);
    if (companionSettings.remember && c.remembered.isNotEmpty) {
      final have = memory.map((m) => m.text).toSet();
      memory = [
        ...memory,
        for (final t in c.remembered.toSet())
          if (!have.contains(t))
            MemoryFact(id: _uuid.v4(), text: t, createdAt: now),
      ];
      await store.saveMemory(memory);
    }
    notifyListeners();
    await checkPatterns();
  }

  Future<void> deleteMemory(String id) async {
    memory = memory.where((m) => m.id != id).toList();
    await store.saveMemory(memory);
    notifyListeners();
  }

  Future<void> clearMemory() async {
    memory = [];
    await store.saveMemory(memory);
    notifyListeners();
  }

  /// [byAppa] is true when he changed it on his own companion screen.
  Future<void> updateCompanionSettings(
    CompanionSettings c, {
    bool byAppa = true,
  }) async {
    companionSettings = c.copyWith(
      changedByAppa: companionSettings.changedByAppa || byAppa,
    );
    await store.saveCompanionSettings(companionSettings);
    if (!companionSettings.remember) await clearMemory();
    notifyListeners();
  }

  Future<void> saveGemini({required String key, required String model}) async {
    await store.saveGemini(key: key, model: model);
    _buildModel();
    notifyListeners();
  }

  CompanionStats get companionReview => companionStats(now, sessions);

  // ---------------------------------------------------------------- patterns

  PatternAlert? get pendingAlert =>
      alerts.where((a) => a.decision == AlertDecision.pending).firstOrNull;

  /// Looks for patterns. With a standing permission he set (and sync on),
  /// the note goes straight away and he is told; otherwise he is asked.
  Future<void> checkPatterns() async {
    if (role != DeviceRole.appa) return;
    final found = detectPatterns(
      now: now,
      sleep: sleepEntries,
      calls: callEvents,
      contacts: contacts,
      sessions: sessions,
      alerts: alerts,
      firstUse: firstUse,
    );
    if (found.isEmpty) return;
    for (final k in found) {
      var a = PatternAlert(
        id: _uuid.v4(),
        kind: k,
        noticedOn: todayKey,
        decision: AlertDecision.pending,
      );
      if (alertPermissions.always.contains(k) && sync.connected) {
        if (await _sendAlert(a)) a = a.decide(AlertDecision.told, now);
      }
      alerts = [...alerts, a];
    }
    await store.saveAlerts(alerts);
    notifyListeners();
  }

  Future<bool> _sendAlert(PatternAlert a) async {
    final note = alertNote(a.kind, displayName);
    if (sync.connected) {
      try {
        await sync.sendAlert(id: a.id, kind: a.kind.name, note: note);
        return true;
      } catch (e) {
        syncError = '$e';
        return false;
      }
    }
    // No sync: the share sheet opens and he picks his son himself.
    return sharer.shareText(note);
  }

  Future<void> decideAlert(String id, {required bool tell}) async {
    final a = alerts.where((x) => x.id == id).firstOrNull;
    if (a == null) return;
    var decided = a.decide(AlertDecision.notTold, now);
    if (tell && await _sendAlert(a)) {
      decided = a.decide(AlertDecision.told, now);
    }
    alerts = [for (final x in alerts) x.id == id ? decided : x];
    await store.saveAlerts(alerts);
    notifyListeners();
  }

  Future<void> updateAlertPermissions(AlertPermissions p) async {
    alertPermissions = p;
    await store.saveAlertPermissions(p);
    notifyListeners();
  }

  // ---------------------------------------------------------------- family phone (Phase 3)

  List<FamilyAlert> familyAlerts = [];

  Future<void> loadFamilyAlerts() async {
    if (!sync.connected || role != DeviceRole.family) return;
    try {
      familyAlerts = await sync.fetchAlerts();
    } catch (e) {
      syncError = '$e';
    }
    notifyListeners();
  }

  Future<void> ackFamilyAlert(String id) async {
    try {
      await sync.ackAlert(id);
      familyAlerts = familyAlerts.where((a) => a.id != id).toList();
    } catch (e) {
      syncError = '$e';
    }
    notifyListeners();
  }

  Future<bool> askFollowUp({
    required String storyId,
    required String text,
  }) async {
    try {
      await sync.addFollowUp(
        id: _uuid.v4(),
        storyId: storyId,
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

  // ================================================================ Phase 4

  // ---------------------------------------------------------------- repair diary

  Future<void> addRepair({
    required String item,
    String note = '',
    String? photoPath,
    String? audioPath,
    String? forWhom,
  }) async {
    if (item.trim().isEmpty) return;
    repairs = [
      RepairEntry(
        id: _uuid.v4(),
        at: now,
        item: item.trim(),
        note: note.trim(),
        photoPath: photoPath,
        audioPath: audioPath,
        forWhom: (forWhom ?? '').trim().isEmpty ? null : forWhom!.trim(),
      ),
      ...repairs,
    ];
    await store.saveRepairs(repairs);
    notifyListeners();
  }

  Future<void> removeRepair(String id) async {
    repairs = repairs.where((r) => r.id != id).toList();
    await store.saveRepairs(repairs);
    notifyListeners();
  }

  // ---------------------------------------------------------------- household ledger

  Future<void> setLedgerEnabled(bool v) async {
    ledgerEnabled = v;
    await store.setLedgerEnabled(v);
    notifyListeners();
  }

  Future<void> addLedger(String item, int amount) async {
    if (item.trim().isEmpty || amount <= 0) return;
    ledger = [
      ...ledger,
      LedgerEntry(id: _uuid.v4(), at: now, item: item.trim(), amount: amount),
    ];
    await store.saveLedger(ledger);
    notifyListeners();
  }

  /// "காய்கறி 200" said or typed. Returns a gentle message if unclear.
  Future<String?> addLedgerSpoken(String text) async {
    final p = parseLedgerUtterance(text);
    if (p == null) {
      return 'எதற்கு, எவ்வளவு என்று சொல்லுங்கள். உதாரணமாக: காய்கறி 200.';
    }
    await addLedger(p.item, p.amount);
    return null;
  }

  Future<void> removeLedger(String id) async {
    ledger = ledger.where((e) => e.id != id).toList();
    await store.saveLedger(ledger);
    notifyListeners();
  }

  MonthLedger ledgerMonth(int year, int month) =>
      ledgerForMonth(ledger, year, month);

  // ---------------------------------------------------------------- local events

  List<LocalEvent> get upcoming => upcomingEvents(events, now);
  List<LocalEvent> get askAttended =>
      eventsToAskAbout(events, now, answered: store.eventsAnswered);

  /// Family adding an event on his phone.
  Future<void> addEventLocal({
    required String title,
    required String place,
    required DateTime startsAt,
    String note = '',
    String addedBy = '',
  }) async {
    final e = LocalEvent(
      id: _uuid.v4(),
      title: title.trim(),
      place: place.trim(),
      startsAt: startsAt,
      note: note.trim(),
      addedBy: addedBy.trim(),
    );
    events = [...events, e];
    await store.saveEvents(events);
    notifyListeners();
  }

  Future<void> markAttended(String id, bool attended) async {
    events = [
      for (final e in events) e.id == id ? e.copyWith(attended: attended) : e,
    ];
    await store.saveEvents(events);
    await store.saveEventsAnswered({...store.eventsAnswered, id});
    notifyListeners();
    if (sync.connected && role == DeviceRole.appa) {
      try {
        await sync.setEventAttended(id, attended);
      } catch (e) {
        syncError = '$e';
      }
    }
  }

  /// One tap: into his plan for that day.
  Future<void> eventToPlan(LocalEvent e) =>
      addPlanItem('${e.title} — ${e.place}', day: dayKey(e.startsAt));

  /// One tap: invite a friend (he picks who in the share sheet).
  Future<bool> inviteToEvent(LocalEvent e) =>
      sharer.shareText(eventInvite(e, displayName));

  /// Appa's phone: bring in family-curated events and the circle.
  Future<void> pullPhase4() async {
    if (role != DeviceRole.appa) return;
    try {
      if (sync.connected) {
        final remote = await sync.fetchEvents();
        final local = {for (final e in events) e.id: e};
        events = [
          for (final r in remote)
            local[r.id]?.attended == true ? r.copyWith(attended: true) : r,
          ...events.where((e) => !remote.any((r) => r.id == e.id)),
        ];
        await store.saveEvents(events);
      }
      if (store.circleId != null) {
        sync.useCircle(store.circleId!);
        await loadCircle();
      }
    } catch (e) {
      syncError = '$e';
    }
    notifyListeners();
  }

  /// Family phone: add an event for Appa.
  Future<bool> addFamilyEvent({
    required String title,
    required String place,
    required DateTime startsAt,
    String note = '',
  }) async {
    try {
      await sync.addEvent(
        LocalEvent(
          id: _uuid.v4(),
          title: title.trim(),
          place: place.trim(),
          startsAt: startsAt,
          note: note.trim(),
          addedBy: displayName,
        ),
      );
      return true;
    } catch (e) {
      syncError = '$e';
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------- help others

  String? get helpCode => store.helpCode;

  int get unansweredOutside =>
      questions.where((q) => q.outside && !q.answered).length;

  /// Appa's phone: make (once) and share the help code with his words.
  Future<String?> ensureHelpCode() async {
    if (store.helpCode != null) return store.helpCode;
    if (!sync.connected || role != DeviceRole.appa) return null;
    try {
      final c = await sync.helpCode();
      await store.saveHelpCode(c);
      notifyListeners();
      return c;
    } catch (e) {
      syncError = '$e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> shareHelpCode() async {
    final code = await ensureHelpCode();
    if (code == null) return false;
    return sharer.shareText(
      'வண்டி, வீட்டுப் பழுது, மின்சாரம், அரசு அலுவலகம், ஓய்வூதியம் பற்றி ஏதாவது கேட்க வேண்டுமா? '
      '"அப்பா" ஆப்பில் "நண்பர்" என்று தேர்ந்தெடுத்து, இந்தக் குறியீட்டைப் போடுங்கள்: $code\n— $displayName',
    );
  }

  // ---------------------------------------------------------------- friend phone

  bool get helpJoined => store.helpJoined;
  bool get inCircle => store.circleId != null;
  List<FamilyQuestion> friendQuestions = [];

  Future<void> _resumeFriend() async {
    final url = store.syncUrl, key = store.syncKey;
    if (url == null || key == null) return;
    try {
      await sync.connect(url: url, key: key);
      if (store.helpJoined) {
        await sync.resume(householdCode: store.householdCode ?? '');
        friendQuestions = await sync.fetchQuestions();
      }
      if (store.circleId != null) {
        sync.useCircle(store.circleId!);
        await loadCircle();
      }
      syncError = null;
    } catch (e) {
      syncError = '$e';
    }
    notifyListeners();
  }

  /// Friend phone (or Appa/family for a circle code): join with a code.
  Future<String?> joinWithCode({
    required String url,
    required String key,
    required String code,
  }) async {
    syncing = true;
    notifyListeners();
    try {
      await sync.connect(url: url.trim(), key: key.trim());
      final r = await sync.joinByCode(code: code, displayName: displayName);
      if (r.kind == 'circle') {
        await store.saveCircle(id: r.id, code: code.trim().toUpperCase());
        await store.saveSync(
          url: url.trim(),
          key: key.trim(),
          householdCode: store.householdCode,
        );
        await loadCircle();
      } else {
        await store.setHelpJoined(true);
        await store.saveSync(
          url: url.trim(),
          key: key.trim(),
          householdCode: code.trim().toUpperCase(),
        );
        friendQuestions = await sync.fetchQuestions();
      }
      syncError = null;
      return r.kind;
    } catch (e) {
      syncError = '$e';
      return null;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<bool> askHelp({
    String? text,
    String? audioPath,
    required String topic,
  }) async {
    try {
      await sync.askQuestion(
        id: _uuid.v4(),
        text: text,
        localAudioPath: audioPath,
        authorName: displayName,
        outside: true,
        topic: topic,
      );
      friendQuestions = await sync.fetchQuestions();
      notifyListeners();
      return true;
    } catch (e) {
      syncError = '$e';
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------- retirees circle

  List<CircleMember> circleMembers = [];
  List<CircleAnswer> circleAnswers = [];

  String get thisWeek => weekKey(now);
  String get circlePrompt => circlePromptFor(now);
  bool get answeredCircleThisWeek =>
      circleAnswers.any((a) => a.mine && a.week == thisWeek);

  Future<String?> createCircle(String name) async {
    try {
      final r = await sync.createCircle(
        name: name.trim(),
        displayName: displayName,
      );
      await store.saveCircle(id: r.id, code: r.code);
      await loadCircle();
      return r.code;
    } catch (e) {
      syncError = '$e';
      notifyListeners();
      return null;
    }
  }

  Future<void> loadCircle() async {
    if (store.circleId == null || !sync.online) return;
    try {
      circleMembers = await sync.fetchCircleMembers();
      circleAnswers = await sync.fetchCircleAnswers();
    } catch (e) {
      syncError = '$e';
    }
    notifyListeners();
  }

  Future<bool> answerCircle(String audioPath) async {
    try {
      await sync.uploadCircleAnswer(
        week: thisWeek,
        localPath: audioPath,
        authorName: displayName,
      );
      await loadCircle();
      return true;
    } catch (e) {
      syncError = '$e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> shareCircleCode() async {
    final code = store.circleCode;
    if (code == null) return false;
    return sharer.shareText(
      'நம் பழைய டிப்போ நண்பர்கள் வட்டம். வாரம் ஒரு கேள்வி, எல்லோரும் குரலில் பதில் சொல்லலாம். '
      '"அப்பா" ஆப்பில் "நண்பர்" என்று தேர்ந்தெடுத்து, இந்தக் குறியீட்டைப் போடுங்கள்: $code\n— $displayName',
    );
  }

  PurposeReview get purpose => purposeReview(
    now: now,
    questions: questions,
    events: events,
    repairs: repairs,
    ledger: ledger,
  );
}
