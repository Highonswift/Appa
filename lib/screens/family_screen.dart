import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/sync.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/recorder.dart';
import 'routine_screen.dart';
import 'settings_screen.dart';
import '../logic/daily_picker.dart';
import '../models/models.dart';
import '../widgets/health_chart.dart';
import 'world_screens.dart';
import '../logic/phase5.dart' show hoursLabel;

/// Family phone: hear Appa's stories and send a voice reply.

/// Family phone: four tabs. Family see only what Appa has shared.
class FamilyHomeScreen extends StatefulWidget {
  const FamilyHomeScreen({super.key});
  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final s = context.read<AppState>();
    await s.loadFamilyStories();
    await s.loadFamilyExtras();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final titles = [
      'அப்பாவின் கதைகள்',
      'அப்பாவிடம் கேளுங்கள்',
      'அப்பாவின் நாள்',
      'அமைப்புகள்',
    ];

    Widget body;
    if (tab == 3) {
      body = const SettingsScreen(embedded: true);
    } else if (!s.sync.connected) {
      body = ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          NoteBox(
            text:
                'அப்பாவின் கதைகளைக் கேட்க, அமைப்புகளில் Supabase விவரங்களும் '
                'அப்பாவின் போனில் உள்ள குடும்பக் குறியீடும் போடுங்கள்.',
          ),
        ],
      );
    } else {
      body = Column(
        children: [
          for (final a in s.familyAlerts)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: AppColors.accent, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      a.note,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => s.ackFamilyAlert(a.id),
                    child: const Text('சரி'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: switch (tab) {
                0 => const _StoriesTab(),
                1 => const _AskTab(),
                _ => const _DayTab(),
              },
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(titles[tab])),
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories),
            label: 'கதைகள்',
          ),
          NavigationDestination(
            icon: Icon(Icons.question_answer),
            label: 'கேள்விகள்',
          ),
          NavigationDestination(icon: Icon(Icons.today), label: 'அவர் நாள்'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'அமைப்பு'),
        ],
      ),
    );
  }
}

class _StoriesTab extends StatelessWidget {
  const _StoriesTab();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final seen = s.seenFamilyStories;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'வணக்கம் ${s.displayName}. ஒவ்வொரு வாரமும் குறைந்தது இரண்டு கதைக்குப் பதில் சொல்லுங்கள்; அவர் கவனிப்பார்.',
          style: t.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        if (s.syncing && s.familyStories.isEmpty)
          const Center(child: CircularProgressIndicator()),
        if (!s.syncing && s.familyStories.isEmpty)
          const NoteBox(
            text: 'இன்னும் கதைகள் இல்லை. அப்பா முதல் கதையைச் சொன்னதும் இங்கே வரும்.',
          ),
        for (final story in s.familyStories) ...[
          Card(
            child: ListTile(
              minVerticalPadding: 16,
              leading: Icon(
                seen.contains(story.id) ? Icons.graphic_eq : Icons.fiber_new,
                size: 34,
                color: seen.contains(story.id)
                    ? AppColors.primary
                    : AppColors.accent,
              ),
              title: Text(story.promptText, style: t.titleMedium),
              subtitle: Text(
                '${tamilDate(story.createdAt)}'
                '${story.replyAuthors.isEmpty ? '' : ' · பதில்: ${story.replyAuthors.join(', ')}'}',
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FamilyStoryScreen(story: story),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Ask Appa for his advice, by voice or text, and hear his answers.
class _AskTab extends StatefulWidget {
  const _AskTab();
  @override
  State<_AskTab> createState() => _AskTabState();
}

class _AskTabState extends State<_AskTab> {
  final text = TextEditingController();
  bool voice = false;
  String? note;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _sent(bool ok) async {
    setState(() {
      note = ok
          ? 'அனுப்பப்பட்டது. அப்பா பதில் சொன்னதும் இங்கே வரும்.'
          : 'அனுப்ப முடியவில்லை. இணையத்தைப் பாருங்கள்.';
      if (ok) {
        text.clear();
        voice = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'அவருக்குத் தெரிந்ததைக் கேளுங்கள்: வண்டி, வீட்டு வேலை, பழைய கதை, ஆலோசனை. உண்மையான கேள்விகளை மட்டும்.',
          style: t.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('எழுதி'),
              icon: Icon(Icons.edit),
            ),
            ButtonSegment(
              value: true,
              label: Text('பேசி'),
              icon: Icon(Icons.mic),
            ),
          ],
          selected: {voice},
          onSelectionChanged: (v) => setState(() => voice = v.first),
        ),
        const SizedBox(height: 12),
        if (!voice) ...[
          TextField(
            controller: text,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'உதா: அப்பா, பைக்கில் சத்தம் வருகிறது. என்ன பார்க்க வேண்டும்?',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () async {
              if (text.text.trim().isEmpty) return;
              await _sent(await s.askFamilyQuestion(text: text.text.trim()));
            },
            child: const Text('அப்பாவிடம் கேள்'),
          ),
        ] else
          VoiceRecorder(
            fileName: 'question-${DateTime.now().millisecondsSinceEpoch}.m4a',
            startLabel: 'கேள்வி கேட்க அழுத்துங்கள்',
            saveLabel: 'அனுப்பு',
            onSaved: (path) async =>
                _sent(await s.askFamilyQuestion(audioPath: path)),
          ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(note!, style: t.bodyMedium),
          ),
        const SizedBox(height: 24),
        for (final q in s.familyQuestions)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              minVerticalPadding: 14,
              leading: Icon(
                q.answered ? Icons.check_circle : Icons.hourglass_empty,
                color: q.answered ? AppColors.callGreen : AppColors.muted,
                size: 32,
              ),
              title: Text(q.text ?? 'குரல் கேள்வி', style: t.titleMedium),
              subtitle: Text(
                '${q.authorName} · ${q.answered ? 'அப்பா பதில் சொன்னார் — கேட்க அழுத்துங்கள்' : 'பதிலுக்குக் காத்திருக்கிறது'}',
              ),
              onTap: q.answerRemotePath == null
                  ? null
                  : () async => s.audio.play(
                      await s.sync.signedUrl(q.answerRemotePath!),
                    ),
            ),
          ),
      ],
    );
  }
}

/// What Appa has chosen to share about his day, plus one request a day.
class _DayTab extends StatefulWidget {
  const _DayTab();
  @override
  State<_DayTab> createState() => _DayTabState();
}

class _DayTabState extends State<_DayTab> {
  final request = TextEditingController();
  String? note;

  @override
  void dispose() {
    request.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final sh = s.familySharing;
    final today = s.todayKey;
    final plan = s.familyPlan.where((p) => p.day == today).toList();
    final bp = s.familyHealth.where((e) => e.kind == HealthKind.bp).toList();
    final from = DateTime(
      s.now.year,
      s.now.month,
      s.now.day,
    ).subtract(const Duration(days: 55));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('அருகில் நடக்கும் நிகழ்ச்சி சேர்க்க', style: t.titleLarge),
        const SizedBox(height: 6),
        Text(
          'கோயில் விழா, ஓய்வுபெற்றோர் சங்கம், நடைக் குழு, நூலகம்: சில கி.மீ.க்குள். அவர் போனில் தெரியும்.',
          style: t.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        EventForm(
          onSave: (title, place, at, note) async {
            await s.addFamilyEvent(
              title: title,
              place: place,
              startsAt: at,
              note: note,
            );
          },
        ),
        const SizedBox(height: 28),
        Text('ஒரு வேலை கேளுங்கள் (நாளுக்கு ஒன்று)', style: t.titleLarge),
        const SizedBox(height: 6),
        Text(
          'உத்தரவாக இல்லை, கோரிக்கையாக அவர் திட்டத்தில் வரும்.',
          style: t.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: request,
          decoration: const InputDecoration(
            labelText: 'உதா: மாலை காய்கறி வாங்கி வர முடியுமா?',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () async {
            if (request.text.trim().isEmpty) return;
            final ok = await s.sendPlanRequest(request.text);
            setState(() {
              note = ok ? 'அனுப்பப்பட்டது.' : 'இன்று ஏற்கனவே ஒன்று கேட்டிருக்கிறீர்கள், அல்லது இணையம் இல்லை.';
              if (ok) request.clear();
            });
          },
          child: const Text('கேள்'),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(note!, style: t.bodyMedium),
          ),
        const SizedBox(height: 28),
        Text('இன்றைய திட்டம்', style: t.titleLarge),
        const SizedBox(height: 8),
        if (!sh.plan)
          Text(
            'அப்பா திட்டத்தைப் பகிரவில்லை.',
            style: t.bodyLarge?.copyWith(color: AppColors.muted),
          )
        else if (plan.isEmpty)
          Text(
            'இன்னும் எழுதவில்லை.',
            style: t.bodyLarge?.copyWith(color: AppColors.muted),
          )
        else
          for (final p in plan)
            ListTile(
              leading: Icon(
                p.done ? Icons.check_box : Icons.check_box_outline_blank,
                color: AppColors.primary,
                size: 30,
              ),
              title: Text(p.text, style: t.titleMedium),
              subtitle: p.addedBy == null ? null : Text('${p.addedBy} கேட்டது'),
            ),
        const SizedBox(height: 24),
        if (sh.walk || sh.sleepHours) ...[
          Text('அவர் உடல் (அவர் பகிர்ந்தவை)', style: t.titleLarge),
          const SizedBox(height: 8),
          if (sh.walk)
            Text(
              'கடந்த 7 நாளில் நடந்த நாட்கள்: ${s.familyBody.where((b) => b.walked == true && DateTime.parse(b.day).isAfter(s.now.subtract(const Duration(days: 7)))).length}',
              style: t.bodyLarge,
            ),
          if (sh.sleepHours)
            for (final b
                in s.familyBody
                    .where((b) => b.sleepMinutes != null)
                    .toList()
                    .reversed
                    .take(7))
              Text(
                '${b.day}: ${hoursLabel(b.sleepMinutes!)}',
                style: t.bodyLarge,
              ),
          const SizedBox(height: 24),
        ],
        Text('தூக்கம், கடந்த 7 நாள்', style: t.titleLarge),
        const SizedBox(height: 8),
        if (!sh.sleep)
          Text(
            'அப்பா தூக்கத்தைப் பகிரவில்லை.',
            style: t.bodyLarge?.copyWith(color: AppColors.muted),
          )
        else
          SleepWeek(ratings: sleepWindow(s.now, s.familySleep), today: s.now),
        const SizedBox(height: 24),
        Text('BP (mmHg)', style: t.titleLarge),
        const SizedBox(height: 8),
        if (!sh.health)
          Text(
            'அப்பா உடல்நல அளவுகளைப் பகிரவில்லை.',
            style: t.bodyLarge?.copyWith(color: AppColors.muted),
          )
        else
          HealthChart(
            unit: 'mmHg',
            from: from,
            to: s.now,
            series: [
              ChartSeries('மேல் எண்', [
                for (final e in bp) (e.at, e.value),
              ], seriesBlue),
              ChartSeries('கீழ் எண்', [
                for (final e in bp) (e.at, e.value2 ?? 0),
              ], seriesOrange),
            ],
          ),
        const SizedBox(height: 20),
        Text(
          'அவர் எதைப் பகிர்வது என்பதை அவரே முடிவு செய்கிறார்.',
          style: t.bodyMedium?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class FamilyStoryScreen extends StatefulWidget {
  const FamilyStoryScreen({super.key, required this.story});
  final RemoteStory story;
  @override
  State<FamilyStoryScreen> createState() => _FamilyStoryScreenState();
}

class _FamilyStoryScreenState extends State<FamilyStoryScreen> {
  bool sent = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AppState>().markFamilyStorySeen(widget.story.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final t = Theme.of(context).textTheme;

    return AppScreen(
      title: tamilDate(widget.story.createdAt),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.story.promptText, style: t.headlineSmall),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              final url = await s.sync.signedUrl(widget.story.audioPath);
              await s.audio.play(url);
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 38),
            label: const Text('அப்பாவின் கதையைக் கேளுங்கள்'),
          ),
          if (widget.story.transcript != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(widget.story.transcript!, style: t.bodyLarge),
            ),
          ],
          const SizedBox(height: 24),
          _FollowUpAsk(storyId: widget.story.id),
          const SizedBox(height: 32),
          Text('குரல் பதில்', style: t.titleLarge),
          const SizedBox(height: 6),
          Text(
            'ஒரு கேள்வி கேளுங்கள், அல்லது உங்களுக்கு என்ன பிடித்தது என்று சொல்லுங்கள்.',
            style: t.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          if (sent)
            const NoteBox(
              icon: Icons.check_circle,
              color: AppColors.callGreen,
              text: 'அனுப்பப்பட்டது. அப்பா கேட்பார்.',
            )
          else
            VoiceRecorder(
              fileName:
                  'family-reply-${DateTime.now().millisecondsSinceEpoch}.m4a',
              startLabel: 'பதில் சொல்ல அழுத்துங்கள்',
              saveLabel: 'அனுப்பு',
              onSaved: (path) async {
                final ok = await s.sendFamilyReply(
                  storyId: widget.story.id,
                  audioPath: path,
                );
                if (mounted) {
                  setState(() {
                    sent = ok;
                    failed = !ok;
                  });
                }
              },
            ),
          if (failed) ...[
            const SizedBox(height: 10),
            Text(
              'அனுப்ப முடியவில்லை. இணையம் உள்ளதா என்று பார்த்து மீண்டும் முயற்சிக்கவும்.',
              style: t.bodyMedium?.copyWith(color: AppColors.accent),
            ),
          ],
        ],
      ),
    );
  }
}

/// A follow-up question about this story; it becomes his question on a
/// later day (roadmap: "Family can ask follow-up questions, which generate
/// the next day's prompt").
class _FollowUpAsk extends StatefulWidget {
  const _FollowUpAsk({required this.storyId});
  final String storyId;
  @override
  State<_FollowUpAsk> createState() => _FollowUpAskState();
}

class _FollowUpAskState extends State<_FollowUpAsk> {
  final text = TextEditingController();
  String? note;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('இதைப் பற்றி இன்னும் கேட்க', style: t.titleLarge),
        const SizedBox(height: 6),
        Text(
          'நாளைய கதைக் கேள்வியாக அவருக்கு வரும்.',
          style: t.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: text,
          decoration: const InputDecoration(
            labelText: 'உதா: அந்த நண்பர் இப்போது எங்கே இருக்கிறார்?',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            if (text.text.trim().isEmpty) return;
            final ok = await context.read<AppState>().askFollowUp(
              storyId: widget.storyId,
              text: text.text,
            );
            setState(() {
              note = ok ? 'அனுப்பப்பட்டது.' : 'அனுப்ப முடியவில்லை.';
              if (ok) text.clear();
            });
          },
          child: const Text('கேள்'),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(note!, style: t.bodyMedium),
          ),
      ],
    );
  }
}
