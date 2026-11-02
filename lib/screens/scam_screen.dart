import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/scam_stories.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// This week's scam pattern, told as a short story. Framed as keeping sharp;
/// forwarding it makes him the one who protects his friends.
class ScamScreen extends StatelessWidget {
  const ScamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final story = s.thisWeeksScam;
    final older = s.scamHistory.skip(1).toList();

    return AppScreen(
      title: 'இந்த வாரம் கவனிக்க',
      speakText: story.spoken,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScamCard(story: story, shared: s.scamShared.contains(story.id)),
          if (older.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text('முந்தைய வாரங்கள்', style: t.titleLarge),
            const SizedBox(height: 10),
            for (final o in older)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  minVerticalPadding: 14,
                  leading: const Icon(
                    Icons.shield_outlined,
                    size: 32,
                    color: AppColors.practice,
                  ),
                  title: Text(o.title, style: t.titleMedium),
                  trailing: const Icon(Icons.chevron_right, size: 30),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppScreen(
                        title: 'கவனிக்க',
                        speakText: o.spoken,
                        body: ScamCard(
                          story: o,
                          shared: s.scamShared.contains(o.id),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class ScamCard extends StatelessWidget {
  const ScamCard({super.key, required this.story, required this.shared});
  final ScamStory story;
  final bool shared;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final t = Theme.of(context).textTheme;

    Widget part(String label, String body, Color color) => Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.titleMedium?.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(body, style: t.bodyLarge),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(story.title, style: t.headlineSmall),
        const SizedBox(height: 12),
        Text(story.story, style: t.bodyLarge),
        part('அடையாளம்', story.sign, AppColors.accent),
        part('செய்ய வேண்டியது', story.action, AppColors.callGreen),
        const SizedBox(height: 20),
        SpeakButton(text: story.spoken, label: 'கேளுங்கள்'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => s.shareScam(story),
          icon: const Icon(Icons.share, size: 30),
          label: const Text('நண்பர்களுக்கு அனுப்பு'),
        ),
        if (shared)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'நண்பர்களுக்கு அனுப்பினீர்கள்.',
              style: t.bodyMedium?.copyWith(color: AppColors.callGreen),
            ),
          ),
      ],
    );
  }
}
