import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// On-device storage. Everything works with no network: stories, the daily
/// plan of reminders, the call nudge and the sleep log all live here first.
/// Small records are JSON in SharedPreferences; audio files live in the app's
/// documents directory and only their paths are stored here.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  static const _kRole = 'role';
  static const _kName = 'displayName';
  static const _kContacts = 'contacts';
  static const _kCalls = 'callEvents';
  static const _kStories = 'stories';
  static const _kSleep = 'sleepEntries';
  static const _kReminders = 'reminders';
  static const _kDoneWalks = 'completedWalkthroughs';
  static const _kSyncUrl = 'syncUrl';
  static const _kSyncKey = 'syncKey';
  static const _kHousehold = 'householdCode';
  static const _kSeenFamilyStories = 'seenFamilyStories';
  static const _kPlan = 'planItems';
  static const _kHealth = 'healthEntries';
  static const _kSharing = 'sharing';
  static const _kQuestions = 'familyQuestions';
  static const _kRealWorld = 'realWorldDone';
  static const _kScamShared = 'scamShared';
  static const _kFollowUps = 'followUps';
  static const _kMemory = 'companionMemory';
  static const _kSessions = 'companionSessions';
  static const _kCompanion = 'companionSettings';
  static const _kAlerts = 'patternAlerts';
  static const _kAlertPerms = 'alertPermissions';
  static const _kGeminiKey = 'geminiKey';
  static const _kGeminiModel = 'geminiModel';
  static const _kFirstUse = 'firstUse';
  static const _kRepairs = 'repairs';
  static const _kLedger = 'ledger';
  static const _kLedgerOn = 'ledgerEnabled';
  static const _kEvents = 'events';
  static const _kHelpCode = 'helpCode';
  static const _kHelpJoined = 'helpJoined';
  static const _kCircleId = 'circleId';
  static const _kCircleCode = 'circleCode';
  static const _kNights = 'nights';
  static const _kActivity = 'dayActivity';
  static const _kBand = 'bandSettings';

  DeviceRole? get role {
    final r = _prefs.getString(_kRole);
    return r == null ? null : DeviceRole.values.byName(r);
  }

  Future<void> setRole(DeviceRole r) => _prefs.setString(_kRole, r.name);

  String get displayName => _prefs.getString(_kName) ?? '';
  Future<void> setDisplayName(String n) => _prefs.setString(_kName, n);

  List<T> _list<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> items) =>
      _prefs.setString(key, jsonEncode(items));

  List<Contact> get contacts => _list(_kContacts, Contact.fromJson);
  Future<void> saveContacts(List<Contact> c) =>
      _saveList(_kContacts, c.map((e) => e.toJson()).toList());

  List<CallEvent> get callEvents => _list(_kCalls, CallEvent.fromJson);
  Future<void> saveCallEvents(List<CallEvent> c) =>
      _saveList(_kCalls, c.map((e) => e.toJson()).toList());

  List<Story> get stories => _list(_kStories, Story.fromJson);
  Future<void> saveStories(List<Story> s) =>
      _saveList(_kStories, s.map((e) => e.toJson()).toList());

  List<SleepEntry> get sleepEntries => _list(_kSleep, SleepEntry.fromJson);
  Future<void> saveSleepEntries(List<SleepEntry> s) =>
      _saveList(_kSleep, s.map((e) => e.toJson()).toList());

  ReminderSettings get reminders {
    final raw = _prefs.getString(_kReminders);
    if (raw == null) return const ReminderSettings();
    try {
      return ReminderSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      return const ReminderSettings();
    }
  }

  Future<void> saveReminders(ReminderSettings r) =>
      _prefs.setString(_kReminders, jsonEncode(r.toJson()));

  Set<String> get completedWalkthroughs =>
      (_prefs.getStringList(_kDoneWalks) ?? []).toSet();
  Future<void> saveCompletedWalkthroughs(Set<String> ids) =>
      _prefs.setStringList(_kDoneWalks, ids.toList());

  /// Story ids a family phone has already opened (to mark new ones).
  Set<String> get seenFamilyStories =>
      (_prefs.getStringList(_kSeenFamilyStories) ?? []).toSet();
  Future<void> saveSeenFamilyStories(Set<String> ids) =>
      _prefs.setStringList(_kSeenFamilyStories, ids.toList());

  /// Optional family sync (Supabase free tier). All three must be set.
  String? get syncUrl => _prefs.getString(_kSyncUrl);
  String? get syncKey => _prefs.getString(_kSyncKey);
  String? get householdCode => _prefs.getString(_kHousehold);

  Future<void> saveSync({
    required String url,
    required String key,
    String? householdCode,
  }) async {
    await _prefs.setString(_kSyncUrl, url);
    await _prefs.setString(_kSyncKey, key);
    if (householdCode != null) {
      await _prefs.setString(_kHousehold, householdCode);
    }
  }

  Future<void> saveHouseholdCode(String code) =>
      _prefs.setString(_kHousehold, code);

  Future<void> clearSync() async {
    await _prefs.remove(_kSyncUrl);
    await _prefs.remove(_kSyncKey);
    await _prefs.remove(_kHousehold);
  }

  // ------------------------------------------------------------ Phase 2

  List<PlanItem> get planItems => _list(_kPlan, PlanItem.fromJson);
  Future<void> savePlanItems(List<PlanItem> p) =>
      _saveList(_kPlan, p.map((e) => e.toJson()).toList());

  List<HealthEntry> get healthEntries => _list(_kHealth, HealthEntry.fromJson);
  Future<void> saveHealthEntries(List<HealthEntry> h) =>
      _saveList(_kHealth, h.map((e) => e.toJson()).toList());

  List<FamilyQuestion> get questions =>
      _list(_kQuestions, FamilyQuestion.fromJson);
  Future<void> saveQuestions(List<FamilyQuestion> q) =>
      _saveList(_kQuestions, q.map((e) => e.toJson()).toList());

  SharingSettings get sharing {
    final raw = _prefs.getString(_kSharing);
    if (raw == null) return const SharingSettings();
    try {
      return SharingSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      return const SharingSettings();
    }
  }

  Future<void> saveSharing(SharingSettings s) =>
      _prefs.setString(_kSharing, jsonEncode(s.toJson()));

  /// Walkthroughs he has since done for real, by his own say-so.
  Set<String> get realWorldDone =>
      (_prefs.getStringList(_kRealWorld) ?? []).toSet();
  Future<void> saveRealWorldDone(Set<String> ids) =>
      _prefs.setStringList(_kRealWorld, ids.toList());

  /// Scam stories he has forwarded (ids).
  Set<String> get scamShared =>
      (_prefs.getStringList(_kScamShared) ?? []).toSet();
  Future<void> saveScamShared(Set<String> ids) =>
      _prefs.setStringList(_kScamShared, ids.toList());

  // ------------------------------------------------------------ Phase 3

  List<StoryFollowUp> get followUps =>
      _list(_kFollowUps, StoryFollowUp.fromJson);
  Future<void> saveFollowUps(List<StoryFollowUp> f) =>
      _saveList(_kFollowUps, f.map((e) => e.toJson()).toList());

  List<MemoryFact> get memory => _list(_kMemory, MemoryFact.fromJson);
  Future<void> saveMemory(List<MemoryFact> m) =>
      _saveList(_kMemory, m.map((e) => e.toJson()).toList());

  List<CompanionSessionLog> get sessions =>
      _list(_kSessions, CompanionSessionLog.fromJson);
  Future<void> saveSessions(List<CompanionSessionLog> s) =>
      _saveList(_kSessions, s.map((e) => e.toJson()).toList());

  List<PatternAlert> get alerts => _list(_kAlerts, PatternAlert.fromJson);
  Future<void> saveAlerts(List<PatternAlert> a) =>
      _saveList(_kAlerts, a.map((e) => e.toJson()).toList());

  CompanionSettings get companionSettings {
    final raw = _prefs.getString(_kCompanion);
    if (raw == null) return const CompanionSettings();
    try {
      return CompanionSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      return const CompanionSettings();
    }
  }

  Future<void> saveCompanionSettings(CompanionSettings c) =>
      _prefs.setString(_kCompanion, jsonEncode(c.toJson()));

  AlertPermissions get alertPermissions {
    final raw = _prefs.getString(_kAlertPerms);
    if (raw == null) return const AlertPermissions();
    try {
      return AlertPermissions.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      return const AlertPermissions();
    }
  }

  Future<void> saveAlertPermissions(AlertPermissions a) =>
      _prefs.setString(_kAlertPerms, jsonEncode(a.toJson()));

  /// Gemini free-tier key from Google AI Studio, entered by the family.
  String get geminiKey => _prefs.getString(_kGeminiKey) ?? '';
  String get geminiModel =>
      _prefs.getString(_kGeminiModel) ?? 'gemini-2.5-flash';
  Future<void> saveGemini({required String key, required String model}) async {
    await _prefs.setString(_kGeminiKey, key.trim());
    await _prefs.setString(
      _kGeminiModel,
      model.trim().isEmpty ? 'gemini-2.5-flash' : model.trim(),
    );
  }

  /// When the app was first set up on this phone.
  DateTime? get firstUse {
    final raw = _prefs.getString(_kFirstUse);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveFirstUse(DateTime d) =>
      _prefs.setString(_kFirstUse, d.toIso8601String());

  // ------------------------------------------------------------ Phase 4

  List<RepairEntry> get repairs => _list(_kRepairs, RepairEntry.fromJson);
  Future<void> saveRepairs(List<RepairEntry> r) =>
      _saveList(_kRepairs, r.map((e) => e.toJson()).toList());

  List<LedgerEntry> get ledger => _list(_kLedger, LedgerEntry.fromJson);
  Future<void> saveLedger(List<LedgerEntry> l) =>
      _saveList(_kLedger, l.map((e) => e.toJson()).toList());

  /// Off until he turns it on (roadmap: "Only if he wants it").
  bool get ledgerEnabled => _prefs.getBool(_kLedgerOn) ?? false;
  Future<void> setLedgerEnabled(bool v) => _prefs.setBool(_kLedgerOn, v);

  List<LocalEvent> get events => _list(_kEvents, LocalEvent.fromJson);
  Future<void> saveEvents(List<LocalEvent> e) =>
      _saveList(_kEvents, e.map((x) => x.toJson()).toList());

  /// Events he has answered "did you go?" for.
  Set<String> get eventsAnswered =>
      (_prefs.getStringList('eventsAnswered') ?? []).toSet();
  Future<void> saveEventsAnswered(Set<String> ids) =>
      _prefs.setStringList('eventsAnswered', ids.toList());

  String? get helpCode => _prefs.getString(_kHelpCode);
  Future<void> saveHelpCode(String c) => _prefs.setString(_kHelpCode, c);

  /// Friend phone: joined Appa's help code.
  bool get helpJoined => _prefs.getBool(_kHelpJoined) ?? false;
  Future<void> setHelpJoined(bool v) => _prefs.setBool(_kHelpJoined, v);

  String? get circleId => _prefs.getString(_kCircleId);
  String? get circleCode => _prefs.getString(_kCircleCode);
  Future<void> saveCircle({required String id, String? code}) async {
    await _prefs.setString(_kCircleId, id);
    if (code != null) await _prefs.setString(_kCircleCode, code);
  }

  // ------------------------------------------------------------ Phase 5

  List<NightSleep> get nights => _list(_kNights, NightSleep.fromJson);
  Future<void> saveNights(List<NightSleep> n) =>
      _saveList(_kNights, n.map((e) => e.toJson()).toList());

  List<DayActivity> get activity => _list(_kActivity, DayActivity.fromJson);
  Future<void> saveActivity(List<DayActivity> a) =>
      _saveList(_kActivity, a.map((e) => e.toJson()).toList());

  /// Day he said "don't ask" about hours slept.
  String? get hoursSkippedDay => _prefs.getString('hoursSkippedDay');
  Future<void> saveHoursSkippedDay(String d) =>
      _prefs.setString('hoursSkippedDay', d);

  BandSettings get band {
    final raw = _prefs.getString(_kBand);
    if (raw == null) return const BandSettings();
    try {
      return BandSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      return const BandSettings();
    }
  }

  Future<void> saveBand(BandSettings b) =>
      _prefs.setString(_kBand, jsonEncode(b.toJson()));
}
