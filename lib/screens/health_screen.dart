import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../logic/phase2.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/health_chart.dart';
import '../logic/phase5.dart';

const _kindTitle = {
  HealthKind.bp: 'BP (இரத்த அழுத்தம்)',
  HealthKind.sugarFasting: 'சர்க்கரை (வெறும் வயிற்றில்)',
  HealthKind.sugarAfterFood: 'சர்க்கரை (சாப்பிட்ட பின்)',
};

String _date(DateTime d) => '${d.day}/${d.month}';
String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// BP and sugar log, shown as simple lines over eight weeks. No "high" or
/// "low" verdicts: the numbers go to the doctor.
class HealthLogScreen extends StatelessWidget {
  const HealthLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final now = s.now;
    final from = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 55));
    final bp = s.healthOf(HealthKind.bp);
    final sf = s.healthOf(HealthKind.sugarFasting);
    final sa = s.healthOf(HealthKind.sugarAfterFood);
    final recent = [...s.healthEntries]..sort((a, b) => b.at.compareTo(a.at));

    return AppScreen(
      title: 'BP, சர்க்கரை',
      speakText: bp.isEmpty
          ? 'BP அல்லது சர்க்கரை அளவு பார்த்ததும் இங்கே போடுங்கள்.'
          : 'கடைசி BP ${bp.last.value}, ${bp.last.value2}.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => _entry(context, HealthKind.bp),
            icon: const Icon(Icons.favorite, size: 30),
            label: const Text('BP போடு'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _pickSugar(context),
            icon: const Icon(Icons.bloodtype, size: 30),
            label: const Text('சர்க்கரை போடு'),
          ),
          const SizedBox(height: 28),
          Text('BP · கடந்த 8 வாரம் (mmHg)', style: t.titleLarge),
          const SizedBox(height: 10),
          HealthChart(
            unit: 'mmHg',
            from: from,
            to: now,
            series: [
              ChartSeries('மேல் எண்', [
                for (final e in bp) (e.at, e.value),
              ], seriesBlue),
              ChartSeries('கீழ் எண்', [
                for (final e in bp) (e.at, e.value2 ?? 0),
              ], seriesOrange),
            ],
          ),
          const SizedBox(height: 28),
          Text('சர்க்கரை · கடந்த 8 வாரம் (mg/dL)', style: t.titleLarge),
          const SizedBox(height: 10),
          HealthChart(
            unit: 'mg/dL',
            from: from,
            to: now,
            series: [
              ChartSeries('வெறும் வயிற்றில்', [
                for (final e in sf) (e.at, e.value),
              ], seriesBlue),
              ChartSeries('சாப்பிட்ட பின்', [
                for (final e in sa) (e.at, e.value),
              ], seriesOrange),
            ],
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DoctorSummaryScreen()),
            ),
            icon: const Icon(Icons.medical_services, size: 28),
            label: const Text('மருத்துவரிடம் காட்ட'),
          ),
          const SizedBox(height: 28),
          if (recent.isNotEmpty) ...[
            Text('சமீபத்திய அளவுகள்', style: t.titleLarge),
            const SizedBox(height: 8),
            for (final e in recent.take(20))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    '${e.display}  ${e.kind == HealthKind.bp ? 'mmHg' : 'mg/dL'}',
                    style: t.titleMedium,
                  ),
                  subtitle: Text(
                    '${_kindTitle[e.kind]} · ${_date(e.at)} ${_time(e.at)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'நீக்கு',
                    icon: const Icon(Icons.delete_outline, size: 28),
                    onPressed: () => s.removeHealth(e.id),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickSugar(BuildContext context) async {
    final kind = await showDialog<HealthKind>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('எப்போது பார்த்தது?'),
        children: [
          for (final k in [HealthKind.sugarFasting, HealthKind.sugarAfterFood])
            SimpleDialogOption(
              padding: const EdgeInsets.all(20),
              onPressed: () => Navigator.pop(ctx, k),
              child: Text(_kindTitle[k]!, style: const TextStyle(fontSize: 22)),
            ),
        ],
      ),
    );
    if (kind != null && context.mounted) await _entry(context, kind);
  }

  Future<void> _entry(BuildContext context, HealthKind kind) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => HealthEntryScreen(kind: kind)));
  }
}

class HealthEntryScreen extends StatefulWidget {
  const HealthEntryScreen({super.key, required this.kind});
  final HealthKind kind;
  @override
  State<HealthEntryScreen> createState() => _HealthEntryScreenState();
}

class _HealthEntryScreenState extends State<HealthEntryScreen> {
  final a = TextEditingController();
  final b = TextEditingController();
  String? problem;

  @override
  void dispose() {
    a.dispose();
    b.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController c, String label) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(3),
    ],
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800),
    decoration: InputDecoration(labelText: label),
  );

  @override
  Widget build(BuildContext context) {
    final bp = widget.kind == HealthKind.bp;
    final t = Theme.of(context).textTheme;
    return AppScreen(
      title: _kindTitle[widget.kind]!,
      speakText: bp
          ? 'மேல் எண்ணும் கீழ் எண்ணும் போடுங்கள்.'
          : 'சர்க்கரை அளவைப் போடுங்கள்.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bp) ...[
            Text(
              'மெஷினில் இரண்டு எண் வரும்: மேலே பெரியது, கீழே சிறியது.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: 16),
            _field(a, 'மேல் எண் (உதா: 130)'),
            const SizedBox(height: 16),
            _field(b, 'கீழ் எண் (உதா: 85)'),
          ] else
            _field(a, 'அளவு mg/dL (உதா: 110)'),
          const SizedBox(height: 20),
          if (problem != null) ...[
            NoteBox(text: problem!, color: AppColors.accent, icon: Icons.edit),
            const SizedBox(height: 16),
          ],
          FilledButton(
            onPressed: () async {
              final s = context.read<AppState>();
              final err = await s.addHealth(
                widget.kind,
                int.tryParse(a.text),
                bp ? int.tryParse(b.text) : null,
              );
              if (err != null) {
                setState(() => problem = err);
                await s.speaker.speak(err);
                return;
              }
              await s.speaker.speak('சேமிக்கப்பட்டது.');
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('சேமி'),
          ),
        ],
      ),
    );
  }
}

/// A plain page to show the doctor: last 30 days, averages and every reading.
class DoctorSummaryScreen extends StatelessWidget {
  const DoctorSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;

    Widget block(HealthKind kind) {
      final series = s.healthOf(kind, days: 30);
      final sum = summarise(series);
      final unit = kind == HealthKind.bp ? 'mmHg' : 'mg/dL';
      return Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_kindTitle[kind]!, style: t.titleLarge),
              const SizedBox(height: 6),
              if (sum.count == 0)
                Text(
                  'அளவுகள் இல்லை',
                  style: t.bodyLarge?.copyWith(color: AppColors.muted),
                )
              else ...[
                Text(
                  kind == HealthKind.bp
                      ? 'சராசரி ${sum.avg}/${sum.avg2} $unit · ${sum.count} அளவுகள்'
                      : 'சராசரி ${sum.avg} $unit · குறைந்தது ${sum.min} · அதிகம் ${sum.max} · ${sum.count} அளவுகள்',
                  style: t.titleMedium,
                ),
                const SizedBox(height: 8),
                Table(
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth(),
                  },
                  children: [
                    for (final e in series.reversed)
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${_date(e.at)} ${_time(e.at)}   ',
                              style: t.bodyLarge,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              e.display,
                              style: t.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    String asText() {
      final b = StringBuffer('${s.displayName} — கடந்த 30 நாள் அளவுகள்\n');
      for (final k in HealthKind.values) {
        final series = s.healthOf(k, days: 30);
        if (series.isEmpty) continue;
        b.writeln('\n${_kindTitle[k]}');
        for (final e in series) {
          b.writeln('${_date(e.at)} ${_time(e.at)}  ${e.display}');
        }
      }
      final body = s.body30;
      if (body.nightsWithHours > 0 || body.avgSteps != null) {
        b.writeln('\nதூக்கமும் நடையும் (30 நாள்)');
        if (body.avgSleepHours != null) {
          b.writeln(
            'சராசரி தூக்கம்: ${body.avgSleepHours!.toStringAsFixed(1)} மணி (${body.nightsWithHours} இரவுகள்)',
          );
        }
        b.writeln('நடந்த நாட்கள்: ${body.walkDays}');
        if (body.avgSteps != null) {
          b.writeln('சராசரி அடிகள்/நாள்: ${body.avgSteps}');
        }
        if (body.avgRestingHr != null) {
          b.writeln('ஓய்வு இதயத் துடிப்பு: ${body.avgRestingHr}/நிமி');
        }
      }
      return b.toString();
    }

    return AppScreen(
      title: 'மருத்துவரிடம் காட்ட',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'கடந்த 30 நாள். போனை மருத்துவரிடம் கொடுத்தால் போதும்.',
            style: t.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          for (final k in HealthKind.values) block(k),
          _BodyBlock(sum: s.body30),
          OutlinedButton.icon(
            onPressed: () => s.sharer.shareText(asText()),
            icon: const Icon(Icons.share, size: 28),
            label: const Text('அனுப்பு (WhatsApp / SMS)'),
          ),
        ],
      ),
    );
  }
}

/// Sleep, walking and resting heart rate for the doctor (Phase 5). Step
/// counts appear only here, never on his own screens.
class _BodyBlock extends StatelessWidget {
  const _BodyBlock({required this.sum});
  final BodySummary sum;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (sum.nightsWithHours == 0 && sum.avgSteps == null) {
      return const SizedBox.shrink();
    }
    Widget row(String a, String b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(a, style: t.bodyLarge)),
          Text(b, style: t.titleMedium),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('தூக்கமும் நடையும்', style: t.titleLarge),
            const SizedBox(height: 6),
            if (sum.avgSleepHours != null)
              row(
                'சராசரி தூக்கம் (${sum.nightsWithHours} இரவுகள்)',
                '${sum.avgSleepHours!.toStringAsFixed(1)} மணி',
              ),
            row('நடந்த நாட்கள் (30 நாளில்)', '${sum.walkDays}'),
            if (sum.avgSteps != null)
              row('சராசரி அடிகள் / நாள்', '${sum.avgSteps}'),
            if (sum.avgRestingHr != null)
              row('ஓய்வு இதயத் துடிப்பு', '${sum.avgRestingHr} / நிமி'),
          ],
        ),
      ),
    );
  }
}
