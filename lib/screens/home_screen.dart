import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'call_screen.dart';
import 'plan_screen.dart';
import 'questions_screen.dart';
import 'routine_screen.dart';
import 'scam_screen.dart';
import 'settings_screen.dart';
import 'sharing_screen.dart';
import 'story_screen.dart';
import 'walkthrough_screen.dart';

/// Appa's home. Big tiles, one column, nothing hidden: no menus, no swipes.
/// Ordered by what the day asks of him: the people first, then his own plan,
/// then learning and health.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final now = s.now;
    final contact = s.todaysContact;
    final call = s.todaysCall;
    final morning = now.hour >= 4 && now.hour < 12;
    final needsSleep = morning && s.todaysSleep == null;

    String callSubtitle;
    if (call != null) {
      final who = s.contactById(call.contactId)?.name ?? '';
      callSubtitle = call.outcome == CallOutcome.called
          ? 'இன்று $who-உடன் பேசினீர்கள்'
          : 'நாளை பார்க்கலாம்';
    } else if (contact != null) {
      callSubtitle = contact.name;
    } else {
      callSubtitle = 'பெயர்களைக் குடும்பத்தினர் சேர்ப்பார்கள்';
    }

    final plan = s.planForDay(s.todayKey);
    final planDone = plan.where((p) => p.done).length;
    final planSubtitle = plan.isEmpty
        ? 'இன்று என்ன செய்யலாம் என்று எழுதுங்கள்'
        : '${plan.length}-இல் $planDone முடிந்தது';

    final q = s.unansweredQuestions;
    final scamNew = !s.scamShared.contains(s.thisWeeksScam.id);

    final greeting = '${tamilGreeting(now)}, ${s.displayName}';
    final speak =
        '$greeting. இன்று ${tamilDate(now)}. '
        '${q > 0 ? 'குடும்பத்தினர் $q கேள்வி கேட்டிருக்கிறார்கள். ' : ''}'
        'எதைத் தேர்ந்தெடுக்க வேண்டுமோ அதை அழுத்துங்கள்.';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(greeting, style: t.headlineMedium),
                        Text(
                          tamilDate(now),
                          style: t.titleMedium?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SpeakButton(text: speak, compact: true),
                ],
              ),
              const SizedBox(height: 20),
              if (needsSleep) ...[
                const SleepCheckInCard(),
                const SizedBox(height: 16),
              ],
              HomeTile(
                icon: Icons.auto_stories,
                title: 'இன்றைய கதை',
                subtitle: s.answeredToday
                    ? 'இன்றைய கதை சொல்லிவிட்டீர்கள்'
                    : 'இன்று ஒரு கேள்வி காத்திருக்கிறது',
                badge: s.unheardReplies > 0
                    ? '${s.unheardReplies} பதில்'
                    : null,
                onTap: () => _open(context, const StoryScreen()),
              ),
              const SizedBox(height: 16),
              HomeTile(
                icon: Icons.question_answer,
                title: 'குடும்பத்தின் கேள்விகள்',
                subtitle: q > 0 ? 'உங்கள் ஆலோசனை தேவை' : 'புதிய கேள்வி இல்லை',
                badge: q > 0 ? '$q' : null,
                color: AppColors.accent,
                soft: AppColors.accentSoft,
                onTap: () => _open(context, const QuestionsScreen()),
              ),
              const SizedBox(height: 16),
              HomeTile(
                icon: Icons.call,
                title: 'இன்று யாரிடம் பேசலாம்',
                subtitle: callSubtitle,
                color: AppColors.callGreen,
                soft: const Color(0xFFE2F2E5),
                onTap: () => _open(context, const CallScreen()),
              ),
              const SizedBox(height: 16),
              HomeTile(
                icon: Icons.checklist,
                title: 'இன்றைய திட்டம்',
                subtitle: planSubtitle,
                onTap: () => _open(context, const PlanScreen()),
              ),
              const SizedBox(height: 16),
              HomeTile(
                icon: Icons.school,
                title: 'கற்றுக்கொள்வோம்',
                subtitle: 'WhatsApp, பணம், பஸ், உணவு, வழி. பயிற்சி மட்டும்.',
                color: AppColors.practice,
                soft: const Color(0xFFF1E4F6),
                onTap: () => _open(context, const WalkthroughListScreen()),
              ),
              const SizedBox(height: 16),
              HomeTile(
                icon: Icons.shield,
                title: 'இந்த வாரம் கவனிக்க',
                subtitle: s.thisWeeksScam.title,
                badge: scamNew ? 'புதிது' : null,
                color: const Color(0xFF37474F),
                soft: const Color(0xFFE6EBED),
                onTap: () => _open(context, const ScamScreen()),
              ),
              const SizedBox(height: 16),
              HomeTile(
                icon: Icons.favorite,
                title: 'உடல்நலம்',
                subtitle: 'தூக்கம், மாத்திரை, BP, சர்க்கரை',
                color: AppColors.accent,
                soft: AppColors.accentSoft,
                onTap: () => _open(context, const RoutineScreen()),
              ),
              const SizedBox(height: 28),
              TextButton.icon(
                onPressed: () => _open(context, const SharingScreen()),
                icon: const Icon(
                  Icons.visibility,
                  size: 24,
                  color: AppColors.muted,
                ),
                label: Text(
                  'குடும்பம் என்ன பார்க்கிறது',
                  style: t.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ),
              TextButton.icon(
                onPressed: () => _open(context, const SettingsScreen()),
                icon: const Icon(
                  Icons.settings,
                  size: 24,
                  color: AppColors.muted,
                ),
                label: Text(
                  'குடும்பத்தினருக்கு: அமைப்புகள்',
                  style: t.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    context.read<AppState>().speaker.stop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
