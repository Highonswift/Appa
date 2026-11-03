import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../data/story_prompts.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'story_screen.dart';

/// His story archive, by theme, with progress towards 40 stories and an
/// export (audio + written text) to give to the grandchildren.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  static const goal = 40;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final byTheme = s.storiesByTheme;
    final total = s.stories.length;
    final written = s.stories.where((x) => x.transcript != null).length;

    return AppScreen(
      title: 'கதைத் தொகுப்பு',
      speakText: 'இதுவரை $total கதைகள் சொல்லியிருக்கிறீர்கள்.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$total கதைகள்', style: t.headlineMedium),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (total / goal).clamp(0, 1),
              minHeight: 12,
              backgroundColor: const Color(0xFFE4E2DC),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            total >= goal
                ? 'பேரக்குழந்தைகளுக்கு ஒரு முழுப் புத்தகம்.'
                : 'முதல் தொகுப்புக்கு $goal கதைகள்.',
            style: t.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          for (final theme in StoryTheme.values)
            if (byTheme[theme]!.isNotEmpty) ...[
              Text(
                '${storyThemeNames[theme]} (${byTheme[theme]!.length})',
                style: t.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final st in byTheme[theme]!)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    minVerticalPadding: 12,
                    leading: Icon(
                      st.transcript != null
                          ? Icons.description
                          : Icons.graphic_eq,
                      size: 30,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      st.promptText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium,
                    ),
                    subtitle: Text(tamilDate(st.createdAt)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StoryDetailScreen(id: st.id),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          if (total == 0)
            const NoteBox(
              text: 'இன்னும் கதைகள் இல்லை. "இன்றைய கதை"யில் முதல் கதையைச் சொல்லுங்கள்.',
            ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            if (s.companionModel.configured && written < total)
              OutlinedButton.icon(
                onPressed: s.transcribing
                    ? null
                    : () async {
                        final n = await s.transcribeAll();
                        await s.speaker.speak('$n கதைகள் எழுத்தாக்கப்பட்டன.');
                      },
                icon: const Icon(Icons.text_snippet, size: 28),
                label: Text(
                  s.transcribing
                      ? 'எழுத்தாக்குகிறது…'
                      : 'எல்லாக் கதைகளையும் எழுத்தாக்கு ($written/$total)',
                ),
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: s.exportArchive,
              icon: const Icon(Icons.card_giftcard, size: 30),
              label: const Text('பேரக்குழந்தைகளுக்குக் கொடு'),
            ),
            const SizedBox(height: 6),
            Text(
              'எல்லாக் குரல் பதிவுகளும் எழுத்து வடிவமும் ஒரே கோப்பாக. யாருக்கு அனுப்புவது என்று நீங்களே தேர்ந்தெடுக்கலாம்.',
              style: t.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
