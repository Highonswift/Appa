import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Tamil speech-to-text for short entries (daily plan items).
///
/// Uses the phone's own Google speech recogniser through `speech_to_text`:
/// free, no API key. Prefers on-device recognition when the Tamil offline
/// pack is installed; otherwise Google's free online recogniser.
abstract class Dictation {
  Future<bool> available();

  /// Listens once and returns what he said, or null.
  Future<void> listen({
    required void Function(String text, bool isFinal) onText,
  });
  Future<void> stop();
}

class DeviceDictation implements Dictation {
  final SpeechToText _stt = SpeechToText();
  bool? _ok;
  String? _locale;

  @override
  Future<bool> available() async {
    if (_ok != null) return _ok!;
    try {
      _ok = await _stt.initialize(
        onError: (e) => debugPrint('STT error: ${e.errorMsg}'),
      );
      if (_ok!) {
        final locales = await _stt.locales();
        final ta = locales.where(
          (l) => l.localeId.toLowerCase().startsWith('ta'),
        );
        _locale = ta.isEmpty ? null : ta.first.localeId;
        _ok = _locale != null;
      }
    } catch (e) {
      debugPrint('STT init failed: $e');
      _ok = false;
    }
    return _ok!;
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onText,
  }) async {
    if (!await available()) return;
    await _stt.listen(
      onResult: (r) => onText(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: _locale,
        listenMode: ListenMode.dictation,
        partialResults: true,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  @override
  Future<void> stop() => _stt.stop();
}

class FakeDictation implements Dictation {
  FakeDictation([this.result = 'காலை நடை']);
  final String result;
  @override
  Future<bool> available() async => true;
  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onText,
  }) async => onText(result, true);
  @override
  Future<void> stop() async {}
}

/// Opens the phone's share sheet (WhatsApp, SMS, ...). He chooses who.
abstract class Sharer {
  Future<bool> shareText(String text);

  /// Shares files (the story archive zip) with a short message.
  Future<bool> shareFiles(List<String> paths, String text);
}

class DeviceSharer implements Sharer {
  @override
  Future<bool> shareText(String text) async {
    try {
      final r = await SharePlus.instance.share(ShareParams(text: text));
      return r.status != ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('Share failed: $e');
      return false;
    }
  }

  @override
  Future<bool> shareFiles(List<String> paths, String text) async {
    try {
      final r = await SharePlus.instance.share(
        ShareParams(text: text, files: [for (final p in paths) XFile(p)]),
      );
      return r.status != ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('Share failed: $e');
      return false;
    }
  }
}

class FakeSharer implements Sharer {
  final List<String> shared = [];
  final List<List<String>> files = [];

  @override
  Future<bool> shareFiles(List<String> paths, String text) async {
    files.add(paths);
    shared.add(text);
    return true;
  }

  @override
  Future<bool> shareText(String text) async {
    shared.add(text);
    return true;
  }
}
