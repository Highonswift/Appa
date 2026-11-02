import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic/phase2.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The daily plan he owns: he writes it, it only shows what he wrote, and it
/// never nags (no reminders come from it).
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  bool tomorrow = false;
  final input = TextEditingController();

  @override
  void initState() {
    super.initState();
    // In the evening, default to planning tomorrow ("the night before").
    tomorrow = context.read<AppState>().now.hour >= 19;
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> _add(AppState s, String text) async {
    await s.addPlanItem(text, day: tomorrow ? s.tomorrowKey : s.todayKey);
    input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final day = tomorrow ? s.tomorrowKey : s.todayKey;
    final items = s.planForDay(day);
    final done = items.where((i) => i.done).length;
    final existing = items.map((i) => i.text).toSet();

    final speak = items.isEmpty
        ? 'இன்னும் திட்டம் இல்லை. கீழே சேர்க்கலாம்.'
        : '${tomorrow ? 'நாளைய' : 'இன்றைய'} திட்டம்: ${items.map((i) => i.text).join(', ')}.';

    return AppScreen(
      title: tomorrow ? 'நாளைய திட்டம்' : 'இன்றைய திட்டம்',
      speakText: speak,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('இன்று')),
              ButtonSegment(value: true, label: Text('நாளை')),
            ],
            selected: {tomorrow},
            onSelectionChanged: (v) => setState(() => tomorrow = v.first),
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size.fromHeight(56)),
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (items.isNotEmpty)
            Text(
              '${items.length}-இல் $done முடிந்தது',
              style: t.titleMedium?.copyWith(color: AppColors.muted),
            ),
          const SizedBox(height: 8),
          for (final item in items) ...[
            _PlanRow(item: item),
            const SizedBox(height: 10),
          ],
          if (items.isEmpty)
            const NoteBox(
              text: 'இன்னும் எதுவும் எழுதவில்லை. கீழே உள்ளவற்றில் இருந்து தேர்ந்தெடுக்கலாம், அல்லது பேசிச் சேர்க்கலாம்.',
            ),
          const SizedBox(height: 24),
          Text('சேர்க்க', style: t.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final sug in planSuggestions.where(
                (x) => !existing.contains(x),
              ))
                ActionChip(
                  label: Text(sug, style: const TextStyle(fontSize: 20)),
                  avatar: const Icon(Icons.add, size: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  onPressed: () => _add(s, sug),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  style: t.titleMedium,
                  decoration: const InputDecoration(labelText: 'வேறு ஏதாவது'),
                  onSubmitted: (v) => _add(s, v),
                ),
              ),
              const SizedBox(width: 8),
              DictateButton(controller: input),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => _add(s, input.text),
            child: const Text('சேர்'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final n = await s.repeatYesterday(day);
              if (!context.mounted) return;
              final msg = n == 0
                  ? 'நேற்றைய திட்டத்தில் புதிதாகச் சேர்க்க எதுவும் இல்லை.'
                  : '$n வேலை சேர்க்கப்பட்டது.';
              s.speaker.speak(msg);
            },
            icon: const Icon(Icons.replay, size: 28),
            label: Text(
              tomorrow
                  ? 'இன்றைய திட்டத்தையே நாளைக்கும்'
                  : 'நேற்றைய திட்டத்தையே இன்றும்',
            ),
          ),
          if (!tomorrow) ...[
            const SizedBox(height: 32),
            const Divider(),
            _FamilyAdd(),
          ],
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.item});
  final PlanItem item;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final t = Theme.of(context).textTheme;
    return Material(
      color: item.done ? AppColors.primarySoft : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => s.togglePlanItem(item.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.done ? AppColors.primary : const Color(0xFFCCCCCC),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                item.done ? Icons.check_box : Icons.check_box_outline_blank,
                size: 38,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.text, style: t.titleMedium),
                    if (item.addedBy != null)
                      Text(
                        '${item.addedBy} கேட்டது',
                        style: t.bodyMedium?.copyWith(color: AppColors.accent),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'நீக்கு',
                icon: const Icon(Icons.close, size: 28, color: AppColors.muted),
                onPressed: () => s.removePlanItem(item.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Amma (or anyone in the family) adds one item a day on this phone.
class _FamilyAdd extends StatefulWidget {
  @override
  State<_FamilyAdd> createState() => _FamilyAddState();
}

class _FamilyAddState extends State<_FamilyAdd> {
  final name = TextEditingController(text: 'அம்மா');
  final text = TextEditingController();
  String? note;

  @override
  void dispose() {
    name.dispose();
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'குடும்பத்தினர் ஒரு வேலை கேட்க (ஒருவருக்கு நாளுக்கு ஒன்று)',
          style: t.titleMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'யார் கேட்கிறார்கள்'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: text,
          decoration: const InputDecoration(
            labelText: 'என்ன வேலை (உதா: காய்கறி வாங்குவது)',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () async {
            if (text.text.trim().isEmpty) return;
            final ok = await context.read<AppState>().addFamilyPlanItem(
              author: name.text,
              text: text.text,
            );
            setState(() {
              note = ok
                  ? 'சேர்க்கப்பட்டது.'
                  : 'இன்று ${name.text.trim()} ஏற்கனவே ஒன்று கேட்டிருக்கிறார்கள். நாளை கேட்கலாம்.';
              if (ok) text.clear();
            });
          },
          child: const Text('கேள்'),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(note!, style: t.bodyMedium),
          ),
      ],
    );
  }
}

/// Mic button that fills [controller] with what he says (Tamil).
class DictateButton extends StatefulWidget {
  const DictateButton({super.key, required this.controller});
  final TextEditingController controller;
  @override
  State<DictateButton> createState() => _DictateButtonState();
}

class _DictateButtonState extends State<DictateButton> {
  bool listening = false;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return SizedBox(
      width: 64,
      height: 64,
      child: IconButton.filled(
        tooltip: 'பேசிச் சேர்',
        style: IconButton.styleFrom(
          backgroundColor: listening ? AppColors.accent : AppColors.primary,
        ),
        icon: Icon(listening ? Icons.stop : Icons.mic, size: 32),
        onPressed: () async {
          if (listening) {
            await s.dictation.stop();
            setState(() => listening = false);
            return;
          }
          if (!await s.dictation.available()) {
            await s.speaker.speak(
              'இந்த போனில் தமிழ்ப் பேச்சு அறிதல் இல்லை. எழுதிச் சேர்க்கலாம்.',
            );
            return;
          }
          await s.speaker.stop();
          setState(() => listening = true);
          await s.dictation.listen(
            onText: (text, isFinal) {
              widget.controller.text = text;
              if (isFinal && mounted) setState(() => listening = false);
            },
          );
        },
      ),
    );
  }
}
