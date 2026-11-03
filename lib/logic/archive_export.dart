import 'package:archive/archive.dart';

import '../data/story_prompts.dart';
import '../models/models.dart';

/// Builds the story archive as a zip: one folder per theme with each
/// recording, plus கதைகள்.txt holding every question and transcript in
/// order. Pure apart from [readAudio], so it is unit-tested.
List<int> buildArchiveZip({
  required String appaName,
  required List<({StoryTheme theme, Story story})> items,
  required List<int> Function(String path) readAudio,
}) {
  final archive = Archive();
  final text = StringBuffer('$appaName அவர்களின் கதைகள்\n${'=' * 24}\n');
  StoryTheme? current;
  var n = 0;
  for (final it in items) {
    n++;
    final st = it.story;
    if (it.theme != current) {
      current = it.theme;
      text.writeln('\n## ${storyThemeNames[current]}\n');
    }
    final d = st.createdAt;
    final date =
        '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
    final file =
        '${it.theme.index + 1}-${it.theme.name}/${n.toString().padLeft(3, '0')}_$date.m4a';
    text.writeln('$n. ($date) ${st.promptText}');
    text.writeln(
      st.transcript ??
          '(எழுத்து வடிவம் இன்னும் இல்லை — ஒலிப்பதிவைக் கேளுங்கள்: $file)',
    );
    text.writeln();
    final path = st.localAudioPath;
    if (path != null) {
      try {
        archive.add(ArchiveFile.bytes(file, readAudio(path)));
      } catch (_) {
        // A missing recording should not stop the rest of the archive.
      }
    }
  }
  archive.add(ArchiveFile.string('கதைகள்.txt', text.toString()));
  return ZipEncoder().encodeBytes(archive);
}
