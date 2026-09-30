import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/book.dart';
import 'library_service.dart';
import 'text_extractor.dart';
import 'tts_service.dart';

/// The one place where reading aloud actually happens.
///
/// It lives outside any screen, so speech keeps going when the app is
/// minimized or the phone is locked. The reader screen just shows its state
/// and sends it commands; on Android the notification / lock-screen /
/// headset buttons (see background_reading.dart) send the same commands.
class ReadingSession extends ChangeNotifier {
  ReadingSession._();
  static final ReadingSession instance = ReadingSession._();

  final TtsService _tts = TtsService();
  final LibraryService _library = LibraryService();
  bool _ttsReady = false;

  Book? _book;
  List<String> _chunks = const [];
  int _index = 0;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _speechError;

  double _rate = 0.5;
  double _pitch = 1.0;
  List<Map<String, String>> _voices = const [];
  Map<String, String>? _selectedVoice;

  // Commands (play / pause / skip) run one at a time, in order, so quick
  // repeated taps can't trip over each other.
  Future<void> _chain = Future<void>.value();

  // ------------------------------------------------------------------ state

  Book? get book => _book;
  List<String> get chunks => _chunks;
  int get index => _index;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get rate => _rate;
  double get pitch => _pitch;
  List<Map<String, String>> get voices => _voices;
  Map<String, String>? get selectedVoice => _selectedVoice;

  /// A problem reported by the speech engine, waiting to be shown once.
  String? get speechError => _speechError;
  void clearSpeechError() => _speechError = null;

  // -------------------------------------------------------- opening/closing

  /// Loads a book for reading. Does nothing if that book is already loaded.
  Future<void> open(Book b) async {
    if (_book?.id == b.id && !_isLoading && _errorMessage == null) return;

    _isPlaying = false;
    await _tts.stop();

    _book = b;
    _chunks = const [];
    _index = 0;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _ensureTts();
      final chunks = await TextExtractor.extractChunks(b.filePath, b.format);
      if (_book?.id != b.id) return; // the user left while it was loading
      _chunks = chunks;
      _index = chunks.isEmpty ? 0 : b.lastChunkIndex.clamp(0, chunks.length - 1);
    } catch (e) {
      if (_book?.id != b.id) return;
      _errorMessage =
          e.toString().replaceFirst(RegExp(r'^\w*(Error|Exception): '), '');
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Stops reading and unloads the book (called when leaving the reader).
  Future<void> close() async {
    if (_book == null) return;
    _isPlaying = false;
    _book = null;
    _chunks = const [];
    _index = 0;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
    await _tts.stop();
  }

  // -------------------------------------------------------------- commands

  Future<void> play() => _run(() async {
        if (_book == null || _chunks.isEmpty || _isPlaying) return;
        _isPlaying = true;
        notifyListeners();
        await _speakCurrent();
      });

  Future<void> pause() => _run(() async {
        // Stopping and later resuming from the same section is more reliable
        // than the engines' own pause, which behaves differently on Windows
        // and Android. Resuming re-reads the current section from its start.
        _isPlaying = false;
        notifyListeners();
        await _tts.stop();
      });

  Future<void> next() => _jump((i) => i + 1);
  Future<void> previous() => _jump((i) => i - 1);
  Future<void> jumpTo(int index) => _jump((_) => index);

  Future<void> _jump(int Function(int current) target) => _run(() async {
        if (_book == null) return;
        final index = target(_index);
        if (index < 0 || index >= _chunks.length) return;

        final wasPlaying = _isPlaying;
        // Cleared first so a "finished" event caused by stop() can't advance.
        _isPlaying = false;
        await _tts.stop();
        if (_book == null) return; // closed while stopping

        _index = index;
        _isPlaying = wasPlaying;
        _saveProgress();
        notifyListeners();
        if (wasPlaying) await _speakCurrent();
      });

  // -------------------------------------------------------------- settings

  Future<void> setRate(double value) async {
    _rate = value;
    await _tts.setRate(value);
  }

  Future<void> setPitch(double value) async {
    _pitch = value;
    await _tts.setPitch(value);
  }

  Future<void> selectVoice(Map<String, String> voice) async {
    _selectedVoice = voice;
    await _tts.setVoice(voice['name']!, voice['locale']!);
  }

  // -------------------------------------------------------------- internals

  Future<void> _run(Future<void> Function() action) {
    final next = _chain.then((_) => action()).catchError((Object e) {
      debugPrint('Reading command failed: $e');
    });
    _chain = next;
    return next;
  }

  Future<void> _ensureTts() async {
    if (_ttsReady) return;
    await _tts.init();
    await _tts.setRate(_rate);
    await _tts.setPitch(_pitch);
    _tts.setCompletionHandler(_onChunkFinished);
    _tts.setErrorHandler(_onSpeechError);
    _voices = await _tts.getVoices();
    _ttsReady = true;
  }

  /// Called by the speech engine when one section has been read out.
  void _onChunkFinished() {
    if (!_isPlaying || _book == null) return;
    if (_index < _chunks.length - 1) {
      _index++;
      _saveProgress();
      notifyListeners();
      _speakCurrent();
    } else {
      _isPlaying = false; // reached the end of the book
      notifyListeners();
    }
  }

  void _onSpeechError(dynamic message) {
    _isPlaying = false;
    _speechError = 'The speech engine reported a problem: $message';
    notifyListeners();
  }

  Future<void> _speakCurrent() async {
    if (_index >= _chunks.length) return;
    try {
      await _tts.speak(_chunks[_index]);
    } catch (e) {
      _onSpeechError(e);
    }
  }

  void _saveProgress() {
    final b = _book;
    if (b != null) unawaited(_library.updateProgress(b.id, _index));
  }
}
