import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'health_screen.dart';
import '../logic/phase5.dart';
import '../widgets/health_chart.dart';
import '../services/band.dart';

const sleepLabels = {
  SleepRating.good: 'நன்றாகத் தூங்கினேன்',
  SleepRating.okay: 'பரவாயில்லை',
  SleepRating.bad: 'சரியாகத் தூங்கவில்லை',
};

const _sleepShort = {
  SleepRating.good: 'நன்று',
  SleepRating.okay: 'பரவாயில்லை',
  SleepRating.bad: 'சரியில்லை',
};

const _sleepColors = {
  SleepRating.good: AppColors.callGreen,
  SleepRating.okay: Color(0xFFB8860B),
  SleepRating.bad: AppColors.accent,
};

/// Morning "how did you sleep?" — one tap. Shown on the home screen in the
/// morning and on the routine screen.
class SleepCheckInCard extends StatelessWidget {
  const SleepCheckInCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final today = s.todaysSleep;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('நேற்று இரவு தூக்கம் எப்படி?', style: t.titleLarge),
              ),
              const SpeakButton(
                text: 'நேற்று இரவு தூக்கம் எப்படி இருந்தது?',
                compact: true,
                label: '',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (today != null) ...[
            Text(
              'இன்று சொன்னது: ${sleepLabels[today.rating]}. நன்றி.',
              style: t.bodyLarge,
            ),
            if (s.askSleepHours)
              const _SleepTimes()
            else if (s.lastNight?.minutes != null)
              _NightLine(night: s.lastNight!),
          ] else
            for (final r in SleepRating.values) ...[
              FilledButton(
                onPressed: () async {
                  await s.rateSleep(r);
                  await s.speaker.speak('நன்றி.');
                },
                style: FilledButton.styleFrom(backgroundColor: _sleepColors[r]),
                child: Text(sleepLabels[r]!),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

/// Last seven mornings in a row of labelled dots.
class SleepWeek extends StatelessWidget {
  const SleepWeek({super.key, required this.ratings, required this.today});
  final List<SleepRating?> ratings;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    const dayShort = ['தி', 'செ', 'பு', 'வி', 'வெ', 'ச', 'ஞா'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < ratings.length; i++)
          Builder(
            builder: (context) {
              final d = DateTime(
                today.year,
                today.month,
                today.day,
              ).subtract(Duration(days: ratings.length - 1 - i));
              final r = ratings[i];
              return Semantics(
                label: r == null ? 'பதில் இல்லை' : _sleepShort[r],
                child: Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: r == null ? Colors.transparent : _sleepColors[r],
                        border: Border.all(
                          color: r == null ? AppColors.muted : _sleepColors[r]!,
                          width: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayShort[d.weekday - 1],
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final r = s.reminderSettings;
    final med = r.medicineName.trim().isEmpty
        ? 'காலை மாத்திரை'
        : r.medicineName.trim();

    final speak =
        'மாத்திரை நேரம் ${r.medicine.label}. இரவு ஓய்வு நேரம் ${r.windDown.label}. '
        'காலை ${r.morningCheckIn.label} மணிக்கு தூக்கம் பற்றி ஒரு கேள்வி.';

    return AppScreen(
      title: 'உடல்நலம்',
      speakText: speak,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SleepCheckInCard(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const HealthLogScreen())),
            icon: const Icon(Icons.monitor_heart, size: 30),
            label: const Text('BP, சர்க்கரை'),
          ),
          const SizedBox(height: 24),
          Text('கடந்த ஏழு நாள் தூக்கம்', style: t.titleLarge),
          const SizedBox(height: 12),
          SleepWeek(ratings: s.lastWeekSleep, today: s.now),
          const SizedBox(height: 8),
          Text(
            'பச்சை: நன்று · மஞ்சள்: பரவாயில்லை · சிவப்பு: சரியில்லை',
            style: t.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          const BodySection(),
          const SizedBox(height: 28),
          Text('தினசரி நினைவூட்டல்', style: t.titleLarge),
          const SizedBox(height: 12),
          _ReminderRow(
            icon: Icons.wb_sunny,
            label: 'தூக்கக் கேள்வி',
            time: r.morningCheckIn.label,
          ),
          _ReminderRow(
            icon: Icons.medication,
            label: med,
            time: r.medicine.label,
          ),
          _ReminderRow(
            icon: Icons.bedtime,
            label: 'இரவு ஓய்வு',
            time: r.windDown.label,
          ),
          const SizedBox(height: 12),
          if (!r.enabled)
            const NoteBox(text: 'நினைவூட்டல் இப்போது நிறுத்தப்பட்டுள்ளது.')
          else
            Text(
              'நேரத்தை மாற்ற குடும்பத்தினரிடம் சொல்லுங்கள், அல்லது அமைப்புகளில் மாற்றலாம்.',
              style: t.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('இரவு நல்ல தூக்கத்துக்கு', style: t.titleMedium),
                const SizedBox(height: 6),
                Text(
                  '• மாலை ஆறு மணிக்குப் பிறகு டீ, காபி வேண்டாம்\n'
                  '• தூங்கும் முன் அரை மணி நேரம் டிவி அணைக்கலாம்\n'
                  '• போனை படுக்கையறைக்கு வெளியே வைக்கலாம்',
                  style: t.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.icon,
    required this.label,
    required this.time,
  });
  final IconData icon;
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 32, color: AppColors.accent),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: t.titleMedium)),
          Text(time, style: t.titleMedium),
        ],
      ),
    );
  }
}

/// Two quick taps: when did you sleep, when did you wake (Phase 5).
class _SleepTimes extends StatefulWidget {
  const _SleepTimes();
  @override
  State<_SleepTimes> createState() => _SleepTimesState();
}

class _SleepTimesState extends State<_SleepTimes> {
  int? bed;

  static const _beds = [
    (21, 'இரவு 9'),
    (22, 'இரவு 10'),
    (23, 'இரவு 11'),
    (0, 'நள்ளிரவு 12'),
    (1, 'இரவு 1'),
  ];
  static const _wakes = [
    (4, 'காலை 4'),
    (5, 'காலை 5'),
    (6, 'காலை 6'),
    (7, 'காலை 7'),
    (8, 'காலை 8'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final t = Theme.of(context).textTheme;
    final options = bed == null ? _beds : _wakes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Text(
          bed == null ? 'எப்போது தூங்கினீர்கள்?' : 'எப்போது எழுந்தீர்கள்?',
          style: t.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (h, label) in options)
              ActionChip(
                label: Text(label, style: const TextStyle(fontSize: 20)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                onPressed: () async {
                  if (bed == null) {
                    setState(() => bed = h);
                  } else {
                    await s.setSelfSleepTimes(bedHour: bed!, wakeHour: h);
                  }
                },
              ),
          ],
        ),
        TextButton(
          onPressed: s.skipSleepHours,
          child: const Text('இன்று வேண்டாம்'),
        ),
      ],
    );
  }
}

/// "6 மணி 40 நிமி தூங்கினீர்கள்", with a way to correct the band.
class _NightLine extends StatelessWidget {
  const _NightLine({required this.night});
  final NightSleep night;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${hoursLabel(night.minutes!)} தூங்கினீர்கள்${night.fromBand ? ' (கைப்பட்டை சொன்னது)' : ''}',
              style: t.bodyLarge,
            ),
          ),
          if (night.fromBand)
            TextButton(
              onPressed: () async {
                final h = await showDialog<int>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: const Text('உண்மையில் எத்தனை மணி நேரம்?'),
                    children: [
                      for (var hrs = 3; hrs <= 9; hrs++)
                        SimpleDialogOption(
                          padding: const EdgeInsets.all(16),
                          onPressed: () => Navigator.pop(ctx, hrs),
                          child: Text(
                            '$hrs மணி',
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                    ],
                  ),
                );
                if (h != null) await s.correctNight(night.day, h * 60);
              },
              child: const Text('மாற்று'),
            ),
        ],
      ),
    );
  }
}

/// Hours slept over 8 weeks, and the days he walked this week.
class BodySection extends StatelessWidget {
  const BodySection({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final series = s.sleepHours;
    final now = s.now;
    final from = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 55));
    final connected =
        s.bandStatus == BandStatus.connected ||
        s.bandSettings.connectedSince != null;
    const dayShort = ['தி', 'செ', 'பு', 'வி', 'வெ', 'ச', 'ஞா'];
    final week = s.walkWeek;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('தூக்க நேரம் · கடந்த 8 வாரம் (மணி)', style: t.titleLarge),
        const SizedBox(height: 8),
        HealthChart(
          unit: 'மணி',
          from: from,
          to: now,
          series: [
            ChartSeries('தூக்கம்', [
              for (final p in series) (p.$1, (p.$2 * 10).round() / 10),
            ], seriesBlue),
          ],
        ),
        if (connected) ...[
          const SizedBox(height: 24),
          Text('இந்த வாரம் நடந்த நாட்கள்', style: t.titleLarge),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < week.length; i++)
                Builder(
                  builder: (context) {
                    final d = DateTime(
                      now.year,
                      now.month,
                      now.day,
                    ).subtract(Duration(days: week.length - 1 - i));
                    return Semantics(
                      label: week[i] ? 'நடந்தீர்கள்' : 'இல்லை',
                      child: Column(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: week[i]
                                  ? AppColors.callGreen
                                  : Colors.transparent,
                              border: Border.all(
                                color: week[i]
                                    ? AppColors.callGreen
                                    : AppColors.muted,
                                width: 2,
                              ),
                            ),
                            child: week[i]
                                ? const Icon(
                                    Icons.directions_walk,
                                    color: Colors.white,
                                    size: 22,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dayShort[d.weekday - 1],
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
        if (s.bandSettings.doctorWords.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          NoteBox(
            icon: Icons.medical_services,
            text: 'மருத்துவர் சொன்னது: ${s.bandSettings.doctorWords.trim()}',
          ),
        ],
      ],
    );
  }
}
