import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/recorder.dart';
import 'plan_screen.dart' show DictateButton;

String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// "நான் சரிசெய்தவை": a record of usefulness he can scroll back through
/// (roadmap Phase 4 "Repair and maintenance diary").
class RepairDiaryScreen extends StatelessWidget {
  const RepairDiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final forOthers = s.repairs.where((r) => r.forWhom != null).length;

    return AppScreen(
      title: 'நான் சரிசெய்தவை',
      speakText: s.repairs.isEmpty
          ? 'நீங்கள் சரிசெய்ததை இங்கே எழுதி வைக்கலாம்.'
          : 'இதுவரை ${s.repairs.length} வேலைகள் செய்திருக்கிறீர்கள். அதில் $forOthers மற்றவர்களுக்காக.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddRepairScreen())),
            icon: const Icon(Icons.build, size: 30),
            label: const Text('இன்று சரிசெய்ததைச் சேர்'),
          ),
          const SizedBox(height: 16),
          if (s.repairs.isNotEmpty)
            Text(
              '${s.repairs.length} வேலைகள் · மற்றவர்களுக்காக $forOthers',
              style: t.titleMedium?.copyWith(color: AppColors.muted),
            ),
          if (s.repairs.isEmpty)
            const NoteBox(
              text: 'பைக், மோட்டார், மின்விசிறி, பக்கத்து வீட்டு ஸ்கூட்டர்: நீங்கள் சரிசெய்த ஒவ்வொன்றையும் படத்துடன் இங்கே வைக்கலாம்.',
            ),
          const SizedBox(height: 8),
          for (final r in s.repairs)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (r.photoPath != null &&
                      !kIsWeb &&
                      File(r.photoPath!).existsSync())
                    Image.file(
                      File(r.photoPath!),
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.item, style: t.titleLarge),
                              Text(
                                '${_date(r.at)}${r.forWhom == null ? '' : ' · ${r.forWhom}-க்காக'}',
                                style: t.bodyMedium?.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                              if (r.note.isNotEmpty)
                                Text(r.note, style: t.bodyLarge),
                            ],
                          ),
                        ),
                        if (r.audioPath != null)
                          IconButton(
                            tooltip: 'கேள்',
                            iconSize: 34,
                            onPressed: () => s.audio.play(r.audioPath!),
                            icon: const Icon(
                              Icons.play_circle,
                              color: AppColors.primary,
                            ),
                          ),
                        IconButton(
                          tooltip: 'நீக்கு',
                          onPressed: () => s.removeRepair(r.id),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class AddRepairScreen extends StatefulWidget {
  const AddRepairScreen({super.key});
  @override
  State<AddRepairScreen> createState() => _AddRepairScreenState();
}

class _AddRepairScreenState extends State<AddRepairScreen> {
  final item = TextEditingController();
  final note = TextEditingController();
  final forWhom = TextEditingController();
  String? photo;
  String? voice;
  bool forOther = false;

  @override
  void dispose() {
    item.dispose();
    note.dispose();
    forWhom.dispose();
    super.dispose();
  }

  Future<void> _photo(ImageSource src) async {
    final audio = context.read<AppState>().audio;
    try {
      final x = await ImagePicker().pickImage(
        source: src,
        maxWidth: 1280,
        imageQuality: 70,
      );
      if (x == null) return;
      final dest = await audio.filePath(
        'repair-${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(x.path).copy(dest);
      if (mounted) setState(() => photo = dest);
    } catch (e) {
      debugPrint('photo failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppScreen(
      title: 'சரிசெய்ததைச் சேர்',
      speakText: 'எதைச் சரிசெய்தீர்கள்? படம் எடுக்கலாம், பேசியும் சொல்லலாம்.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item,
                  style: t.titleMedium,
                  decoration: const InputDecoration(
                    labelText: 'எதை (உதா: தண்ணீர் மோட்டார்)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DictateButton(controller: item),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'என்ன செய்தீர்கள் (விருப்பம்)',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: forOther,
            onChanged: (v) => setState(() => forOther = v),
            title: const Text(
              'மற்றவருக்காகச் செய்தது',
              style: TextStyle(fontSize: 20),
            ),
          ),
          if (forOther)
            TextField(
              controller: forWhom,
              decoration: const InputDecoration(
                labelText: 'யாருக்கு (உதா: பக்கத்து வீட்டு குமார்)',
              ),
            ),
          const SizedBox(height: 16),
          if (photo != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(photo!), height: 180, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _photo(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera, size: 28),
                  label: const Text('படம் எடு'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _photo(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 28),
                  label: const Text('கேலரி'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (voice == null) ...[
            Text('பேசியும் சொல்லலாம் (விருப்பம்)', style: t.titleMedium),
            const SizedBox(height: 10),
            VoiceRecorder(
              fileName: 'repair-${DateTime.now().millisecondsSinceEpoch}.m4a',
              startLabel: 'எப்படிச் செய்தீர்கள் என்று சொல்ல அழுத்துங்கள்',
              saveLabel: 'இதை வைத்துக்கொள்',
              onSaved: (p) async => setState(() => voice = p),
            ),
          ] else
            const NoteBox(
              icon: Icons.check_circle,
              color: AppColors.callGreen,
              text: 'குரல் குறிப்பு சேர்க்கப்பட்டது.',
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              if (item.text.trim().isEmpty) return;
              final s = context.read<AppState>();
              await s.addRepair(
                item: item.text,
                note: note.text,
                photoPath: photo,
                audioPath: voice,
                forWhom: forOther ? forWhom.text : null,
              );
              await s.speaker.speak('சேர்க்கப்பட்டது.');
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('சேமி'),
          ),
        ],
      ),
    );
  }
}

/// The household ledger: a monthly list he keeps, by voice or by typing.
/// Off until he turns it on himself.
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});
  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final input = TextEditingController();
  late DateTime month = DateTime(
    context.read<AppState>().now.year,
    context.read<AppState>().now.month,
  );
  String? problem;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  static const _months = [
    'ஜனவரி',
    'பிப்ரவரி',
    'மார்ச்',
    'ஏப்ரல்',
    'மே',
    'ஜூன்',
    'ஜூலை',
    'ஆகஸ்ட்',
    'செப்டம்பர்',
    'அக்டோபர்',
    'நவம்பர்',
    'டிசம்பர்',
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;

    if (!s.ledgerEnabled) {
      return AppScreen(
        title: 'வீட்டுக் கணக்கு',
        speakText: 'வீட்டுச் செலவுகளை மாதா மாதம் எழுதி வைக்கலாம். வேண்டுமென்றால் மட்டும் தொடங்குங்கள்.',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'வீட்டுச் செலவுகளை மாதா மாதம் நீங்கள் எழுதி வைக்கலாம்: காய்கறி, பால், கரண்ட் பில். பேசியே சேர்க்கலாம். வேண்டுமென்றால் மட்டும்.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => s.setLedgerEnabled(true),
              child: const Text('கணக்கு வைக்கத் தொடங்கு'),
            ),
          ],
        ),
      );
    }

    final m = s.ledgerMonth(month.year, month.month);
    final prev = s.ledgerMonth(
      DateTime(month.year, month.month - 1).year,
      DateTime(month.year, month.month - 1).month,
    );
    final title = '${_months[month.month - 1]} ${month.year}';

    Future<void> add(String text) async {
      final err = await s.addLedgerSpoken(text);
      setState(() => problem = err);
      if (err != null) {
        await s.speaker.speak(err);
      } else {
        input.clear();
      }
    }

    return AppScreen(
      title: 'வீட்டுக் கணக்கு',
      speakText: '$title மொத்தம் ${m.total} ரூபாய்.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'முந்தைய மாதம்',
                iconSize: 34,
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: t.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'அடுத்த மாதம்',
                iconSize: 34,
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Text(
            '₹ ${m.total}',
            textAlign: TextAlign.center,
            style: t.displaySmall,
          ),
          if (prev.total > 0)
            Text(
              'கடந்த மாதம் ₹ ${prev.total}',
              textAlign: TextAlign.center,
              style: t.bodyLarge?.copyWith(color: AppColors.muted),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  style: t.titleMedium,
                  decoration: const InputDecoration(
                    labelText: 'உதா: காய்கறி 200',
                  ),
                  onSubmitted: add,
                ),
              ),
              const SizedBox(width: 8),
              DictateButton(controller: input),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => add(input.text),
            child: const Text('சேர்'),
          ),
          if (problem != null) ...[
            const SizedBox(height: 8),
            NoteBox(text: problem!, color: AppColors.accent, icon: Icons.edit),
          ],
          if (m.byItem.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('எதற்கு எவ்வளவு', style: t.titleLarge),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {1: IntrinsicColumnWidth()},
              children: [
                for (final e in m.byItem)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(e.key, style: t.bodyLarge),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('₹ ${e.value}', style: t.titleMedium),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('எல்லாப் பதிவுகளும்', style: t.titleLarge),
            for (final e in m.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${e.item}  ·  ₹ ${e.amount}',
                  style: t.titleMedium,
                ),
                subtitle: Text('${e.at.day}/${e.at.month}'),
                trailing: IconButton(
                  tooltip: 'நீக்கு',
                  onPressed: () => s.removeLedger(e.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
          ],
          const SizedBox(height: 28),
          TextButton(
            onPressed: () => s.setLedgerEnabled(false),
            child: const Text('கணக்கை நிறுத்து (பதிவுகள் இருக்கும்)'),
          ),
        ],
      ),
    );
  }
}
