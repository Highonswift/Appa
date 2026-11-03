import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic/companion.dart';
import '../services/companion_model.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The Tamil voice companion. He speaks, it listens and reflects, and it
/// keeps pointing him back to people. Nothing said here is saved: only the
/// session's length, whether it ended in a call / story / plan, and any
/// facts he can see and delete on "நீங்கள் சொன்னவை".
class CompanionScreen extends StatefulWidget {
  const CompanionScreen({super.key});
  @override
  State<CompanionScreen> createState() => _CompanionScreenState();
}

class _Line {
  _Line(this.fromAppa, this.text, [this.suggestion]);
  final bool fromAppa;
  final String text;
  Suggestion? suggestion;
}

class _CompanionScreenState extends State<CompanionScreen> {
  late final AppState s = context.read<AppState>();
  late final CompanionConversation conv = s.startCompanion();
  final lines = <_Line>[];
  final typed = TextEditingController();
  bool listening = false;
  bool thinking = false;
  bool finished = false;
  String partial = '';
  String? problem;

  @override
  void initState() {
    super.initState();
    lines.add(_Line(false, conv.opening));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => s.speaker.speak(conv.opening),
    );
  }

  @override
  void dispose() {
    typed.dispose();
    if (!finished) {
      // Leaving by the back button still records the session's numbers.
      s.endCompanion(conv);
    }
    s.speaker.stop();
    s.dictation.stop();
    super.dispose();
  }

  Future<void> _listen() async {
    if (listening) {
      await s.dictation.stop();
      setState(() => listening = false);
      return;
    }
    if (!await s.dictation.available()) {
      setState(
        () => problem =
            'இந்த போனில் தமிழ்ப் பேச்சு அறிதல் இல்லை. கீழே எழுதியும் பேசலாம்.',
      );
      return;
    }
    await s.speaker.stop();
    setState(() {
      listening = true;
      partial = '';
      problem = null;
    });
    await s.dictation.listen(
      onText: (text, isFinal) {
        if (!mounted) return;
        setState(() => partial = text);
        if (isFinal) {
          setState(() => listening = false);
          _say(text);
        }
      },
    );
  }

  Future<void> _say(String text) async {
    if (text.trim().isEmpty || thinking || finished) return;
    setState(() {
      lines.add(_Line(true, text.trim()));
      partial = '';
      thinking = true;
      problem = null;
    });
    try {
      final turn = await conv.send(text.trim(), s.now);
      if (!mounted) return;
      setState(() {
        lines.add(_Line(false, turn.reply, turn.suggestion));
        thinking = false;
      });
      await s.speaker.speak(turn.reply);
      if (turn.ended) await _finish(speak: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        thinking = false;
        problem = 'இப்போது இணைக்க முடியவில்லை. இணையம் உள்ளதா என்று பாருங்கள்.';
      });
    }
  }

  Future<void> _take(Suggestion sug, _Line line) async {
    await s.takeSuggestion(conv, sug);
    setState(() => line.suggestion = null);
    final msg = switch (sug.type) {
      SuggestionType.call => '',
      SuggestionType.story => 'சரி. நாளைய கதைக் கேள்வியாகச் சேர்த்தேன்.',
      SuggestionType.plan => 'சரி. இன்றைய திட்டத்தில் சேர்த்தேன்.',
      SuggestionType.none => '',
    };
    if (msg.isNotEmpty) await s.speaker.speak(msg);
  }

  Future<void> _finish({bool speak = true}) async {
    if (finished) return;
    finished = true;
    await s.endCompanion(conv);
    if (speak) await s.speaker.speak('சரி. பிறகு பேசலாம்.');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppScreen(
      title: 'பேசலாம்',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'இது ஒரு ஆப். நீங்கள் சொல்வது சேமிக்கப்படாது.',
            style: t.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          for (final l in lines) ...[
            _Bubble(line: l),
            if (l.suggestion != null && !finished) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _take(l.suggestion!, l),
                icon: Icon(switch (l.suggestion!.type) {
                  SuggestionType.call => Icons.call,
                  SuggestionType.story => Icons.auto_stories,
                  _ => Icons.checklist,
                }, size: 30),
                label: Text(l.suggestion!.label),
                style: FilledButton.styleFrom(
                  backgroundColor: l.suggestion!.type == SuggestionType.call
                      ? AppColors.callGreen
                      : AppColors.primary,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          if (partial.isNotEmpty)
            Text(partial, style: t.bodyLarge?.copyWith(color: AppColors.muted)),
          if (thinking)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (problem != null) NoteBox(text: problem!, color: AppColors.accent),
          const SizedBox(height: 16),
          if (finished) ...[
            const NoteBox(
              icon: Icons.check_circle,
              color: AppColors.callGreen,
              text: 'பேசி முடிந்தது. இப்போது ஒருவரை அழைக்கலாம், அல்லது ஒரு நடை போகலாம்.',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('திரும்ப'),
            ),
          ] else ...[
            Center(
              child: Semantics(
                button: true,
                label: listening ? 'நிறுத்து' : 'பேசுங்கள்',
                child: GestureDetector(
                  onTap: thinking ? null : _listen,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: listening ? AppColors.accent : AppColors.primary,
                    ),
                    child: Icon(
                      listening ? Icons.stop_rounded : Icons.mic,
                      size: 76,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              listening ? 'கேட்கிறேன்…' : 'அழுத்திப் பேசுங்கள்',
              textAlign: TextAlign.center,
              style: t.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: typed,
                    decoration: const InputDecoration(
                      labelText: 'அல்லது எழுதுங்கள்',
                    ),
                    onSubmitted: (v) {
                      _say(v);
                      typed.clear();
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'அனுப்பு',
                  iconSize: 32,
                  onPressed: () {
                    _say(typed.text);
                    typed.clear();
                  },
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _finish, child: const Text('போதும்')),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.line});
  final _Line line;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Align(
      alignment: line.fromAppa ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: line.fromAppa ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDDDDD)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(line.text, style: t.bodyLarge)),
            if (!line.fromAppa)
              IconButton(
                tooltip: 'மீண்டும் கேள்',
                icon: const Icon(Icons.volume_up, color: AppColors.primary),
                onPressed: () =>
                    context.read<AppState>().speaker.speak(line.text),
              ),
          ],
        ),
      ),
    );
  }
}

/// "What you told me": every remembered fact, deletable, plus his own
/// companion settings.
class MemoryScreen extends StatelessWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final c = s.companionSettings;

    return AppScreen(
      title: 'நீங்கள் சொன்னவை',
      speakText: s.memory.isEmpty
          ? 'நான் எதையும் நினைவில் வைத்திருக்கவில்லை.'
          : 'நான் நினைவில் வைத்திருப்பவை: ${s.memory.map((m) => m.text).join('. ')}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'பேசும்போது நீங்கள் சொன்னதில் இவற்றை மட்டும் நினைவில் வைத்திருக்கிறேன். வேண்டாதவற்றை நீக்கலாம்.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 14),
          if (s.memory.isEmpty)
            const NoteBox(text: 'இப்போது எதுவும் இல்லை.')
          else ...[
            for (final m in s.memory)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  minVerticalPadding: 14,
                  title: Text(m.text, style: t.titleMedium),
                  trailing: IconButton(
                    tooltip: 'நீக்கு',
                    icon: const Icon(Icons.delete_outline, size: 30),
                    onPressed: () => s.deleteMemory(m.id),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: s.clearMemory,
              icon: const Icon(Icons.delete_sweep, size: 28),
              label: const Text('எல்லாவற்றையும் நீக்கு'),
            ),
          ],
          const SizedBox(height: 28),
          Text('உங்கள் விருப்பம்', style: t.titleLarge),
          const SizedBox(height: 8),
          SwitchListTile(
            value: c.enabled,
            onChanged: (v) => s.updateCompanionSettings(c.copyWith(enabled: v)),
            title: const Text(
              'பேசும் வசதி இயக்கத்தில்',
              style: TextStyle(fontSize: 20),
            ),
          ),
          SwitchListTile(
            value: c.remember,
            onChanged: (v) =>
                s.updateCompanionSettings(c.copyWith(remember: v)),
            title: const Text(
              'நான் சொன்னதை நினைவில் வை',
              style: TextStyle(fontSize: 20),
            ),
            subtitle: const Text('நிறுத்தினால், மேலே உள்ளவை அழிந்துவிடும்'),
          ),
          const SizedBox(height: 8),
          Text('ஒரு முறை எவ்வளவு நேரம் பேசலாம்', style: t.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 5, label: Text('5 நிமி')),
              ButtonSegment(value: 10, label: Text('10 நிமி')),
              ButtonSegment(value: 15, label: Text('15 நிமி')),
            ],
            selected: {c.minutes},
            onSelectionChanged: (v) =>
                s.updateCompanionSettings(c.copyWith(minutes: v.first)),
          ),
        ],
      ),
    );
  }
}
