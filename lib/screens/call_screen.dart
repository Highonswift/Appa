import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../logic/phase3.dart';
import '../logic/phase5.dart';
import '../widgets/common.dart';

/// Call someone today: one person a day, one tap to call, "not today"
/// accepted without guilt.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool showAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<AppState>();
      final c = s.todaysContact;
      if (c != null) s.speaker.speak('இன்று ${c.name}-உடன் பேசலாமா?');
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final contact = s.todaysContact;
    final done = s.todaysCall;

    Widget main;
    String speak;
    if (s.contacts.isEmpty) {
      speak = 'பெயர்கள் இன்னும் சேர்க்கவில்லை. குடும்பத்தினர் அமைப்புகளில் சேர்ப்பார்கள்.';
      main = NoteBox(text: speak);
    } else if (done != null) {
      final who = s.contactById(done.contactId)?.name ?? '';
      speak = done.outcome == CallOutcome.called
          ? 'இன்று $who-உடன் பேசினீர்கள். நல்லது.'
          : 'சரி. நாளை பார்க்கலாம்.';
      main = NoteBox(
        icon: done.outcome == CallOutcome.called
            ? Icons.check_circle
            : Icons.wb_sunny_outlined,
        color: AppColors.callGreen,
        text: speak,
      );
    } else {
      final c = contact!;
      speak = 'இன்று ${c.name}-உடன் பேசலாமா?';
      main = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE2F2E5),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.callGreen,
                  child: Text(
                    c.name.characters.first,
                    style: const TextStyle(
                      fontSize: 48,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  c.name,
                  style: t.displaySmall,
                  textAlign: TextAlign.center,
                ),
                if (c.relation.isNotEmpty)
                  Text(
                    c.relation,
                    style: t.titleMedium?.copyWith(color: AppColors.muted),
                  ),
                if (c.lastCalled != null)
                  Text(
                    'கடைசியாகப் பேசியது: ${tamilDate(c.lastCalled!)}',
                    style: t.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => s.callContact(c),
            icon: const Icon(Icons.call, size: 38),
            label: Text('${c.name}-ஐ அழை'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.callGreen,
              minimumSize: const Size.fromHeight(88),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () async {
              await s.notToday(c);
              await s.speaker.speak('சரி. நாளை பார்க்கலாம்.');
            },
            child: const Text('இன்று வேண்டாம்'),
          ),
          if (c.nearby && s.bandSettings.doctorCleared) ...[
            const SizedBox(height: 16),
            NoteBox(
              icon: Icons.directions_walk,
              color: AppColors.callGreen,
              text: walkTogetherLine(c.name),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await s.planWalkWith(c);
                await s.speaker.speak('நாளைய திட்டத்தில் சேர்த்தேன்.');
              },
              icon: const Icon(Icons.add, size: 26),
              label: Text('நாளை காலை ${c.name}-உடன் நடை'),
            ),
          ],
        ],
      );
    }

    return AppScreen(
      title: 'இன்று யாரிடம் பேசலாம்',
      speakText: speak,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CallRatingCard(),
          for (final o in s.occasions) ...[
            OccasionCard(occasion: o),
            const SizedBox(height: 16),
          ],
          main,
          if (s.contacts.isNotEmpty) ...[
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: () => setState(() => showAll = !showAll),
              icon: Icon(
                showAll ? Icons.expand_less : Icons.expand_more,
                size: 30,
              ),
              label: Text(showAll ? 'மூடு' : 'வேறு யாரிடமாவது பேச'),
            ),
            if (showAll)
              for (final c in s.contacts) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => s.callContact(c),
                  icon: const Icon(
                    Icons.call,
                    size: 28,
                    color: AppColors.callGreen,
                  ),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      c.relation.isEmpty
                          ? c.name
                          : '${c.name}  ·  ${c.relation}',
                    ),
                  ),
                ),
              ],
          ],
        ],
      ),
    );
  }
}

/// After a call: "Good call?" — one tap, or skip. Tunes who comes next.
class CallRatingCard extends StatefulWidget {
  const CallRatingCard({super.key});
  @override
  State<CallRatingCard> createState() => _CallRatingCardState();
}

class _CallRatingCardState extends State<CallRatingCard> {
  bool skipped = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final call = s.unratedCall;
    if (call == null || skipped) return const SizedBox.shrink();
    final who = s.contactById(call.contactId)?.name ?? '';

    Widget choice(String label, CallRating r, Color color) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          onPressed: () => s.rateCall(r),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.callGreen, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$who-உடன் பேசியது நன்றாக இருந்ததா?', style: t.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              choice('நன்றாக', CallRating.good, AppColors.callGreen),
              choice('பரவாயில்லை', CallRating.okay, const Color(0xFFB8860B)),
              choice('சரியில்லை', CallRating.notGood, AppColors.accent),
            ],
          ),
          TextButton(
            onPressed: () => setState(() => skipped = true),
            child: const Text('சொல்ல வேண்டாம்'),
          ),
        ],
      ),
    );
  }
}

/// A birthday or festival today or tomorrow, with people to call.
class OccasionCard extends StatelessWidget {
  const OccasionCard({super.key, required this.occasion});
  final Occasion occasion;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final t = Theme.of(context).textTheme;
    final people = occasion.kind == OccasionKind.birthday
        ? [occasion.contact!]
        : occasion.suggested;
    final greeting = occasion.kind == OccasionKind.birthday
        ? 'பிறந்தநாள் வாழ்த்துகள்'
        : occasion.festival?.greeting ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                occasion.kind == OccasionKind.birthday
                    ? Icons.cake
                    : Icons.celebration,
                size: 34,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(occasion.line, style: t.titleLarge)),
            ],
          ),
          if (people.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              occasion.daysAway == 0
                  ? 'இன்று அழைத்து "$greeting" சொல்லலாம்.'
                  : 'நாளை அழைத்து "$greeting" சொல்ல மறக்க வேண்டாம்.',
              style: t.bodyLarge,
            ),
            if (occasion.daysAway == 0)
              for (final c in people) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => s.callContact(c),
                  icon: const Icon(
                    Icons.call,
                    color: AppColors.callGreen,
                    size: 28,
                  ),
                  label: Text('${c.name}-ஐ அழை'),
                ),
              ],
          ],
        ],
      ),
    );
  }
}
