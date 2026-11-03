import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic/phase4.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/recorder.dart';

String eventWhen(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final p = d.hour < 12
      ? 'காலை'
      : d.hour < 16
      ? 'மதியம்'
      : d.hour < 19
      ? 'மாலை'
      : 'இரவு';
  return '${tamilDate(d)} · $p $h12:${d.minute.toString().padLeft(2, '0')}';
}

/// Local groups and events near him, curated by family. One tap to his
/// plan, one tap to invite a friend; afterwards, "did you go?".
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final up = s.upcoming;
    final ask = s.askAttended;

    return AppScreen(
      title: 'அருகில் நிகழ்ச்சிகள்',
      speakText: up.isEmpty
          ? 'இப்போது நிகழ்ச்சிகள் இல்லை.'
          : 'அடுத்த நிகழ்ச்சி: ${up.first.title}, ${up.first.place}.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in ask) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${e.title}-க்குப் போனீர்களா?', style: t.titleLarge),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => s.markAttended(e.id, true),
                          child: const Text('போனேன்'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => s.markAttended(e.id, false),
                          child: const Text('இல்லை'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (up.isEmpty)
            const NoteBox(
              text: 'இப்போது நிகழ்ச்சிகள் இல்லை. கோயில் விழா, ஓய்வுபெற்றோர் சங்கக் கூட்டம், நடைக் குழு போன்றவற்றைக் குடும்பத்தினர் சேர்ப்பார்கள்.',
            ),
          for (final e in up)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(e.title, style: t.titleLarge),
                    Text(
                      eventWhen(e.startsAt),
                      style: t.titleMedium?.copyWith(color: AppColors.primary),
                    ),
                    Text(e.place, style: t.bodyLarge),
                    if (e.note.isNotEmpty)
                      Text(
                        e.note,
                        style: t.bodyMedium?.copyWith(color: AppColors.muted),
                      ),
                    if (e.addedBy.isNotEmpty)
                      Text(
                        '${e.addedBy} சேர்த்தது',
                        style: t.bodyMedium?.copyWith(color: AppColors.muted),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await s.eventToPlan(e);
                              await s.speaker.speak('திட்டத்தில் சேர்த்தேன்.');
                            },
                            icon: const Icon(Icons.checklist, size: 26),
                            label: const Text('திட்டத்தில்'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => s.inviteToEvent(e),
                            icon: const Icon(Icons.person_add, size: 26),
                            label: const Text('நண்பரை அழை'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          const Divider(),
          Text(
            'குடும்பத்தினர் இந்த போனிலேயே சேர்க்க',
            style: t.titleMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          EventForm(
            onSave: (title, place, at, note) => s.addEventLocal(
              title: title,
              place: place,
              startsAt: at,
              note: note,
              addedBy: 'குடும்பம்',
            ),
          ),
        ],
      ),
    );
  }
}

/// Title, place, date, time. Used on his phone and on family phones.
class EventForm extends StatefulWidget {
  const EventForm({super.key, required this.onSave});
  final Future<void> Function(
    String title,
    String place,
    DateTime at,
    String note,
  )
  onSave;
  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final title = TextEditingController();
  final place = TextEditingController();
  final note = TextEditingController();
  DateTime? at;
  bool open = false;

  @override
  void dispose() {
    title.dispose();
    place.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now,
    );
    if (d == null || !mounted) return;
    final tm = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 17, minute: 0),
    );
    if (tm == null) return;
    setState(() => at = DateTime(d.year, d.month, d.day, tm.hour, tm.minute));
  }

  @override
  Widget build(BuildContext context) {
    if (!open) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => open = true),
        icon: const Icon(Icons.add, size: 28),
        label: const Text('நிகழ்ச்சி சேர்'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(
            labelText: 'என்ன (உதா: ஓய்வுபெற்றோர் சங்கக் கூட்டம்)',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: place,
          decoration: const InputDecoration(
            labelText: 'எங்கே (உதா: டிப்போ அருகே சங்க அலுவலகம், 2 கி.மீ)',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: note,
          decoration: const InputDecoration(labelText: 'குறிப்பு (விருப்பம்)'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.event, size: 26),
          label: Text(at == null ? 'தேதி, நேரம்' : eventWhen(at!)),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () async {
            if (title.text.trim().isEmpty || at == null) return;
            await widget.onSave(title.text, place.text, at!, note.text);
            setState(() {
              open = false;
              title.clear();
              place.clear();
              note.clear();
              at = null;
            });
          },
          child: const Text('சேமி'),
        ),
      ],
    );
  }
}

/// The TNSTC retirees circle: one voice prompt a week that everyone answers,
/// and the archive of everyone's answers. Used on his phone and on his old
/// colleagues' phones.
class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AppState>().loadCircle(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final week = s.thisWeek;
    final thisWeek = s.circleAnswers.where((a) => a.week == week).toList();
    final older = s.circleAnswers.where((a) => a.week != week).toList();
    final bdays = circleBirthdays(s.circleMembers, s.now);

    return AppScreen(
      title: 'டிப்போ நண்பர்கள் வட்டம்',
      bare: widget.embedded,
      speakText: 'இந்த வாரக் கேள்வி. ${s.circlePrompt}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${s.circleMembers.length} பேர்: ${s.circleMembers.map((m) => m.name).join(', ')}',
            style: t.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          for (final b in bdays) ...[
            const SizedBox(height: 10),
            NoteBox(
              icon: Icons.cake,
              color: AppColors.accent,
              text: b.inDays == 0
                  ? 'இன்று ${b.member.name}-இன் பிறந்தநாள்'
                  : '${b.inDays} நாளில் ${b.member.name}-இன் பிறந்தநாள்',
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'இந்த வாரக் கேள்வி',
                  style: t.titleMedium?.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(s.circlePrompt, style: t.headlineSmall),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (s.answeredCircleThisWeek)
            const NoteBox(
              icon: Icons.check_circle,
              color: AppColors.callGreen,
              text: 'இந்த வாரம் பதில் சொல்லிவிட்டீர்கள். மற்றவர்களுடையதைக் கேளுங்கள்.',
            )
          else
            VoiceRecorder(
              fileName: 'circle-${DateTime.now().millisecondsSinceEpoch}.m4a',
              startLabel: 'பதில் சொல்ல அழுத்துங்கள்',
              saveLabel: 'எல்லோருக்கும் அனுப்பு',
              onSaved: (p) async {
                final ok = await s.answerCircle(p);
                await s.speaker.speak(
                  ok
                      ? 'அனுப்பப்பட்டது.'
                      : 'அனுப்ப முடியவில்லை. இணையத்தைப் பாருங்கள்.',
                );
              },
            ),
          const SizedBox(height: 24),
          Text('இந்த வாரம் (${thisWeek.length})', style: t.titleLarge),
          const SizedBox(height: 8),
          if (thisWeek.isEmpty)
            Text(
              'இன்னும் யாரும் சொல்லவில்லை.',
              style: t.bodyLarge?.copyWith(color: AppColors.muted),
            ),
          for (final a in thisWeek) _AnswerTile(a: a),
          if (older.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('முந்தைய வாரங்கள்', style: t.titleLarge),
            const SizedBox(height: 8),
            for (final a in older.take(40)) _AnswerTile(a: a, showWeek: true),
          ],
        ],
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({required this.a, this.showWeek = false});
  final CircleAnswer a;
  final bool showWeek;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        minVerticalPadding: 14,
        leading: const Icon(
          Icons.play_circle,
          size: 38,
          color: AppColors.primary,
        ),
        title: Text(
          a.mine ? '${a.authorName} (நீங்கள்)' : a.authorName,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          showWeek
              ? '${a.week} · ${tamilDate(a.createdAt)}'
              : tamilDate(a.createdAt),
        ),
        onTap: () async =>
            s.audio.play(await s.sync.circleSignedUrl(a.audioPath)),
      ),
    );
  }
}

/// Friend phone: ask Appa about something he knows.
class AskAppaTab extends StatefulWidget {
  const AskAppaTab({super.key});
  @override
  State<AskAppaTab> createState() => _AskAppaTabState();
}

class _AskAppaTabState extends State<AskAppaTab> {
  final text = TextEditingController();
  String topic = helpTopics.first;
  bool voice = false;
  String? note;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _sent(bool ok) async => setState(() {
    note = ok
        ? 'அனுப்பப்பட்டது. அவர் பதில் சொன்னதும் இங்கே கேட்கலாம்.'
        : 'அனுப்ப முடியவில்லை.';
    if (ok) text.clear();
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'அவருக்கு நன்கு தெரிந்த விஷயங்களில் உண்மையான கேள்விகளைக் கேளுங்கள். அவர் குரலில் பதில் சொல்வார்.',
          style: t.bodyLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in helpTopics)
              ChoiceChip(
                label: Text(h, style: const TextStyle(fontSize: 18)),
                selected: topic == h,
                onSelected: (_) => setState(() => topic = h),
              ),
          ],
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
              labelText: 'உதா: லாரி ஸ்டார்ட் ஆகும்போது கரும்புகை வருகிறது. என்ன பார்க்க வேண்டும்?',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () async {
              if (text.text.trim().isEmpty) return;
              await _sent(
                await s.askHelp(text: text.text.trim(), topic: topic),
              );
            },
            child: const Text('கேள்'),
          ),
        ] else
          VoiceRecorder(
            fileName: 'help-${DateTime.now().millisecondsSinceEpoch}.m4a',
            startLabel: 'கேள்வி கேட்க அழுத்துங்கள்',
            saveLabel: 'அனுப்பு',
            onSaved: (p) async =>
                _sent(await s.askHelp(audioPath: p, topic: topic)),
          ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(note!, style: t.bodyMedium),
          ),
        const SizedBox(height: 24),
        for (final q in s.friendQuestions)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              minVerticalPadding: 14,
              leading: Icon(
                q.answered ? Icons.check_circle : Icons.hourglass_empty,
                size: 32,
                color: q.answered ? AppColors.callGreen : AppColors.muted,
              ),
              title: Text(q.text ?? 'குரல் கேள்வி', style: t.titleMedium),
              subtitle: Text(
                '${q.topic ?? ''} · ${q.answered ? 'பதில் வந்துவிட்டது — கேட்க அழுத்துங்கள்' : 'பதிலுக்குக் காத்திருக்கிறது'}',
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

/// Friend phone (helpers and circle members): never sees his stories,
/// health or plan.
class FriendHomeScreen extends StatefulWidget {
  const FriendHomeScreen({super.key});
  @override
  State<FriendHomeScreen> createState() => _FriendHomeScreenState();
}

class _FriendHomeScreenState extends State<FriendHomeScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final tabs = <({String label, IconData icon, Widget body})>[
      if (s.helpJoined)
        (label: 'கேளுங்கள்', icon: Icons.help, body: const AskAppaTab()),
      if (s.inCircle)
        (
          label: 'வட்டம்',
          icon: Icons.groups,
          body: const CircleScreen(embedded: true),
        ),
      (label: 'சேர', icon: Icons.vpn_key, body: const FriendJoinTab()),
    ];
    final i = tab.clamp(0, tabs.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tabs[i].label == 'சேர'
              ? 'குறியீடு போட்டுச் சேருங்கள்'
              : tabs[i].label,
        ),
      ),
      body: SafeArea(child: tabs[i].body),
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: i,
              onDestinationSelected: (v) => setState(() => tab = v),
              destinations: [
                for (final x in tabs)
                  NavigationDestination(icon: Icon(x.icon), label: x.label),
              ],
            ),
    );
  }
}

class FriendJoinTab extends StatefulWidget {
  const FriendJoinTab({super.key});
  @override
  State<FriendJoinTab> createState() => _FriendJoinTabState();
}

class _FriendJoinTabState extends State<FriendJoinTab> {
  late final url = TextEditingController(
    text: context.read<AppState>().store.syncUrl ?? '',
  );
  late final key = TextEditingController(
    text: context.read<AppState>().store.syncKey ?? '',
  );
  final code = TextEditingController();
  String? note;

  @override
  void dispose() {
    url.dispose();
    key.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'அவர் அனுப்பிய செய்தியில் உள்ள குறியீட்டைப் போடுங்கள். H-இல் தொடங்கினால் அவரிடம் கேள்வி கேட்கலாம்; C-இல் தொடங்கினால் டிப்போ நண்பர்கள் வட்டம்.',
          style: t.bodyLarge,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: url,
          decoration: const InputDecoration(
            labelText: 'Supabase URL (குடும்பத்தினர் தருவார்கள்)',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: key,
          decoration: const InputDecoration(
            labelText: 'Publishable (anon) key',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: code,
          textCapitalization: TextCapitalization.characters,
          style: t.headlineSmall,
          decoration: const InputDecoration(labelText: 'குறியீடு'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: s.syncing
              ? null
              : () async {
                  final kind = await s.joinWithCode(
                    url: url.text,
                    key: key.text,
                    code: code.text,
                  );
                  setState(
                    () => note = switch (kind) {
                      'circle' => 'வட்டத்தில் சேர்ந்துவிட்டீர்கள்.',
                      'help' =>
                        'சேர்ந்துவிட்டீர்கள். இப்போது கேள்வி கேட்கலாம்.',
                      _ => 'சேர முடியவில்லை: ${s.syncError ?? ''}',
                    },
                  );
                },
          child: Text(s.syncing ? 'சேர்கிறது…' : 'சேர்'),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(note!, style: t.bodyLarge),
          ),
      ],
    );
  }
}
