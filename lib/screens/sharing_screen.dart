import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Roadmap: "Everything the family sees is listed on one screen he can read,
/// and he can revoke any item." Written to him, in his words.
class SharingScreen extends StatelessWidget {
  const SharingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final sh = s.sharing;

    Widget item({
      required IconData icon,
      required String title,
      required String detail,
      required bool value,
      ValueChanged<bool>? onChanged,
    }) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 34, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleMedium),
                  const SizedBox(height: 4),
                  Text(detail, style: t.bodyMedium),
                  const SizedBox(height: 6),
                  Text(
                    value
                        ? 'இப்போது: குடும்பத்தினர் பார்க்கலாம்'
                        : 'இப்போது: உங்களுக்கு மட்டும்',
                    style: t.bodyMedium?.copyWith(
                      color: value ? AppColors.callGreen : AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (onChanged != null)
              Transform.scale(
                scale: 1.3,
                child: Switch(value: value, onChanged: onChanged),
              ),
          ],
        ),
      ),
    );

    final speak =
        'குடும்பத்தினர் என்ன பார்க்கிறார்கள்: உங்கள் கதைகளும் நீங்கள் சொன்ன பதில்களும். '
        '${sh.health ? 'BP சர்க்கரை அளவுகள். ' : ''}${sh.sleep ? 'தூக்கம். ' : ''}${sh.plan ? 'தினசரித் திட்டம். ' : ''}'
        'எதை வேண்டுமானாலும் நீங்கள் நிறுத்தலாம்.';

    return AppScreen(
      title: 'குடும்பம் என்ன பார்க்கிறது',
      speakText: speak,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'இது உங்கள் தகவல். நீங்கள் சரி என்று சொன்னதை மட்டுமே குடும்பத்தினர் பார்ப்பார்கள். எப்போது வேண்டுமானாலும் நிறுத்தலாம்; நிறுத்தினால் அவர்களிடம் உள்ள நகலும் அழிந்துவிடும்.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (!s.sync.connected)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: NoteBox(
                text: 'இப்போது பகிர்தல் இயக்கத்தில் இல்லை. எல்லாமே இந்த போனில் மட்டும் உள்ளது.',
              ),
            ),
          item(
            icon: Icons.auto_stories,
            title: 'உங்கள் கதைகளும் பதில்களும்',
            detail: 'நீங்கள் பதிவு செய்த கதைகள், குடும்பக் கேள்விகளுக்கு நீங்கள் சொன்ன பதில்கள். இவற்றைக் கேட்கத்தான் இந்த ஆப்.',
            value: s.sync.connected,
          ),
          item(
            icon: Icons.favorite,
            title: 'BP, சர்க்கரை அளவுகள்',
            detail: 'நீங்கள் போட்ட அளவுகள் மட்டும். வேறு மருத்துவ விவரம் எதுவும் இல்லை.',
            value: sh.health,
            onChanged: (v) => s.updateSharing(sh.copyWith(health: v)),
          ),
          item(
            icon: Icons.bedtime,
            title: 'தூக்கம்',
            detail: 'காலையில் நீங்கள் சொல்லும் "நன்றாக / பரவாயில்லை / சரியில்லை" மட்டும்.',
            value: sh.sleep,
            onChanged: (v) => s.updateSharing(sh.copyWith(sleep: v)),
          ),
          item(
            icon: Icons.checklist,
            title: 'தினசரித் திட்டம்',
            detail: 'நீங்கள் எழுதிய திட்டமும் எது முடிந்தது என்பதும்.',
            value: sh.plan,
            onChanged: (v) => s.updateSharing(sh.copyWith(plan: v)),
          ),
          item(
            icon: Icons.lock,
            title: 'எப்போதும் உங்களுக்கு மட்டும்',
            detail: 'யாரை அழைத்தீர்கள், பயிற்சிகள், மாத்திரை நேரம். இவை ஒருபோதும் பகிரப்படாது.',
            value: false,
          ),
        ],
      ),
    );
  }
}

/// Numbers for the weekly review with Appa (roadmap: "reviewed every week at
/// the review with him in the room"). For Ragul, but nothing here is hidden
/// from Appa either.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final r = s.review;

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.bodyLarge)),
          Text(value, style: t.titleLarge),
        ],
      ),
    );

    return AppScreen(
      title: 'வாராந்திர ஆய்வு',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'கடந்த 7 நாள். ஞாயிறு ஆய்வில் அப்பாவுடன் சேர்ந்து பாருங்கள்.',
            style: t.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          row(
            'கதைகள் (இந்த வாரம் / மொத்தம்)',
            '${r.storiesThisWeek} / ${r.storiesTotal}',
          ),
          row('அழைப்பு நினைவூட்டலில் இருந்து பேசியவை', '${r.callsThisWeek}'),
          row('திட்டம் எழுதிய நாட்கள்', '${r.planDaysThisWeek} / 7'),
          row('பயிற்சிகள் முடித்தவை', '${r.walkthroughsDone}'),
          row('உண்மையான ஆப்பில் தானே செய்தவை', '${r.realWorldDone}'),
          row(
            'குடும்பக் கேள்விகள் (பதில் / காத்திருப்பவை)',
            '${r.questionsAnswered} / ${r.questionsWaiting}',
          ),
          const SizedBox(height: 16),
          Text('தூக்கம், கடந்த 4 வாரம்', style: t.titleLarge),
          const SizedBox(height: 8),
          Table(
            border: TableBorder.symmetric(
              inside: const BorderSide(color: Color(0xFFE4E2DC)),
            ),
            children: [
              TableRow(
                children: [
                  for (final h in ['வாரம்', 'நன்று', 'பரவாயில்லை', 'சரியில்லை'])
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        h,
                        style: t.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              for (var i = 0; i < r.sleepByWeek.length; i++)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        i == r.sleepByWeek.length - 1
                            ? 'இந்த வாரம்'
                            : '${r.sleepByWeek.length - 1 - i} வாரம் முன்',
                        style: t.bodyMedium,
                      ),
                    ),
                    for (final k in SleepRating.values)
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          '${r.sleepByWeek[i][k]}',
                          style: t.titleMedium,
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          const NoteBox(
            text: 'கட்ட 2 முடிவு அளவுகோல்: குறைந்தது 4 பயிற்சி, அதில் ஒன்றையாவது உண்மையில் தானே செய்வது; 6 குடும்பக் கேள்விக்குப் பதில்; தூக்கத்தில் ஏதாவது ஒரு போக்கு; தினசரித் திட்டம் சண்டையைக் குறைக்கிறதா என்று அம்மாவிடம் கேளுங்கள்.',
          ),
          const SizedBox(height: 12),
          Text(
            'அவரிடம் நேரடியாகக் கேளுங்கள்: "இது உங்களுக்கு உதவுகிறதா? எதைச் சரி செய்ய வேண்டும்?"',
            style: t.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
