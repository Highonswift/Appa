import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/recorder.dart';

/// Family question board (first version): family ask, Appa answers by voice.
class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});
  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<AppState>();
      final n = s.unansweredQuestions;
      if (n > 0) {
        s.speaker.speak(
          'குடும்பத்தினர் உங்களிடம் $n கேள்வி கேட்டிருக்கிறார்கள்.',
        );
      }
      s.pullPhase2();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final waiting = s.questions.where((q) => !q.answered).toList();
    final answered = s.questions.where((q) => q.answered).toList();

    return AppScreen(
      title: 'குடும்பத்தின் கேள்விகள்',
      speakText: waiting.isEmpty
          ? 'இப்போது புதிய கேள்வி இல்லை.'
          : 'குடும்பத்தினர் உங்களிடம் ${waiting.length} கேள்வி கேட்டிருக்கிறார்கள்.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (waiting.isEmpty)
            const NoteBox(
              icon: Icons.mark_chat_read,
              text: 'இப்போது புதிய கேள்வி இல்லை. குடும்பத்தினர் கேட்டதும் இங்கே வரும்.',
            ),
          for (final q in waiting) ...[
            _QuestionTile(q: q),
            const SizedBox(height: 12),
          ],
          if (answered.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'நீங்கள் பதில் சொன்னவை (${answered.length})',
              style: t.titleLarge,
            ),
            const SizedBox(height: 10),
            for (final q in answered) ...[
              _QuestionTile(q: q),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'குடும்பத்தினர் இந்த போனிலேயே கேள்வி கேட்க',
            style: t.titleMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          const _LocalAsk(),
        ],
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.q});
  final FamilyQuestion q;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => QuestionDetailScreen(id: q.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                q.answered ? Icons.check_circle : Icons.help_outline,
                size: 36,
                color: q.answered ? AppColors.callGreen : AppColors.accent,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${q.authorName} கேட்டது', style: t.titleMedium),
                    Text(
                      q.text ?? 'குரலில் கேட்டிருக்கிறார்கள்',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class QuestionDetailScreen extends StatefulWidget {
  const QuestionDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  void _ask() {
    final s = context.read<AppState>();
    final q = s.questions.where((x) => x.id == widget.id).firstOrNull;
    if (q == null) return;
    if (q.text != null) {
      s.speaker.speak('${q.authorName} கேட்கிறார்கள்: ${q.text}');
    } else if (q.localAudioPath != null) {
      s.audio.play(q.localAudioPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final q = s.questions.where((x) => x.id == widget.id).firstOrNull;
    if (q == null) {
      return const AppScreen(
        title: 'கேள்வி',
        body: Text('இந்தக் கேள்வி இல்லை.'),
      );
    }

    return AppScreen(
      title: '${q.authorName} கேட்டது',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (q.text != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(q.text!, style: t.headlineSmall),
            ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _ask,
            icon: const Icon(Icons.volume_up, size: 32),
            label: const Text('கேள்வியைக் கேளுங்கள்'),
          ),
          const SizedBox(height: 28),
          if (q.answered) ...[
            const NoteBox(
              icon: Icons.check_circle,
              color: AppColors.callGreen,
              text: 'நீங்கள் பதில் சொல்லிவிட்டீர்கள்.',
            ),
            const SizedBox(height: 12),
            if (q.answerLocalPath != null)
              FilledButton.icon(
                onPressed: () => s.audio.play(q.answerLocalPath!),
                icon: const Icon(Icons.play_arrow_rounded, size: 36),
                label: const Text('உங்கள் பதிலைக் கேளுங்கள்'),
              ),
          ] else
            VoiceRecorder(
              fileName: 'answer-${q.id}.m4a',
              startLabel: 'பதில் சொல்ல அழுத்துங்கள்',
              saveLabel: 'பதிலை அனுப்பு',
              onSaved: (path) async {
                await s.answerQuestion(q.id, path);
                await s.speaker.speak(
                  'நன்றி. ${q.authorName} உங்கள் பதிலைக் கேட்பார்கள்.',
                );
              },
            ),
        ],
      ),
    );
  }
}

class _LocalAsk extends StatefulWidget {
  const _LocalAsk();
  @override
  State<_LocalAsk> createState() => _LocalAskState();
}

class _LocalAskState extends State<_LocalAsk> {
  final name = TextEditingController();
  final text = TextEditingController();
  bool open = false;

  @override
  void dispose() {
    name.dispose();
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!open) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => open = true),
        icon: const Icon(Icons.add_comment, size: 28),
        label: const Text('கேள்வி சேர்'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'உங்கள் பெயர்'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: text,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'கேள்வி (உதா: பைக்கில் சத்தம் வருகிறது, என்ன பார்க்க வேண்டும்?)',
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () async {
            await context.read<AppState>().addLocalQuestion(
              author: name.text,
              text: text.text,
            );
            setState(() {
              open = false;
              text.clear();
            });
          },
          child: const Text('சேர்'),
        ),
      ],
    );
  }
}
