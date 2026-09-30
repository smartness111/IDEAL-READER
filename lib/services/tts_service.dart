import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around flutter_tts so the rest of the app doesn't depend on
/// the plugin's API directly. Speech comes from the voices already installed
/// on the device (Windows speech voices / Android's text-to-speech engine);
/// this app never sends any text anywhere.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// Returns the voices installed on the device. Voices that Android marks
  /// as needing an internet connection are left out, so everything offered
  /// here works offline.
  Future<List<Map<String, String>>> getVoices() async {
    try {
      final voices = await _tts.getVoices as List;
      final result = <Map<String, String>>[];
      for (final v in voices) {
        if (v is! Map) continue;
        if (v['network_required']?.toString() == '1') continue;
        final name = v['name']?.toString() ?? '';
        if (name.isEmpty) continue;
        result.add({'name': name, 'locale': v['locale']?.toString() ?? ''});
      }
      result.sort((a, b) {
        final byLocale = a['locale']!.compareTo(b['locale']!);
        return byLocale != 0 ? byLocale : a['name']!.compareTo(b['name']!);
      });
      return result;
    } catch (_) {
      // Some engines don't expose a voice list; the system default voice is
      // used instead.
      return [];
    }
  }

  Future<void> setVoice(String name, String locale) =>
      _tts.setVoice({'name': name, 'locale': locale});

  Future<void> setRate(double rate) => _tts.setSpeechRate(rate);

  Future<void> setPitch(double pitch) => _tts.setPitch(pitch);

  Future<void> speak(String text) => _tts.speak(text);

  Future<void> stop() => _tts.stop();

  void setCompletionHandler(void Function() onComplete) {
    _tts.setCompletionHandler(onComplete);
  }

  void setErrorHandler(void Function(dynamic message) onError) {
    _tts.setErrorHandler(onError);
  }

  void dispose() {
    _tts.stop();
  }
}
