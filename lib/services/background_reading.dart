import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'reading_session.dart';

/// Keeps reading going while the phone is locked or the app is in the
/// background, and adds the notification / lock-screen / headset controls.
///
/// Android only. Windows needs none of this: a minimized desktop app simply
/// keeps running, so reading continues. Everything here is local; nothing
/// touches the network.
class BackgroundReading {
  static bool _active = false;
  static bool _askedForNotifications = false;

  /// True once the Android background service has been set up.
  static bool get isActive => _active;

  /// Call once at startup. Never throws: if the Android setup is missing or
  /// broken, the app still works normally, it just won't keep reading with
  /// the screen locked.
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      await AudioService.init(
        builder: () => _ReadingAudioHandler(ReadingSession.instance),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'ideal_reader.reading',
          androidNotificationChannelName: 'Reading aloud',
          androidNotificationOngoing: true,
        ),
      );
      _active = true;
    } catch (e) {
      debugPrint('Background reading is not available: $e');
    }
  }

  /// Asks Android (13+) to show the reading notification. Asked once per run.
  static Future<void> askForNotificationsOnce() async {
    if (!_active || _askedForNotifications) return;
    _askedForNotifications = true;
    try {
      await Permission.notification.request();
    } catch (_) {}
  }

  /// Asks to show the notification and to exempt the app from battery
  /// "optimization", which some phones use to stop reading after a while.
  static Future<void> askToRunInBackground() async {
    if (!_active) return;
    try {
      await Permission.notification.request();
      await Permission.ignoreBatteryOptimizations.request();
    } catch (_) {}
  }
}

/// Bridges the reading session to Android's media notification, lock-screen
/// controls and headset buttons.
class _ReadingAudioHandler extends BaseAudioHandler {
  _ReadingAudioHandler(this._session) {
    _session.addListener(_sync);
    _sync();
  }

  final ReadingSession _session;

  void _sync() {
    final book = _session.book;
    if (book == null || _session.chunks.isEmpty) {
      playbackState.add(PlaybackState(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
      return;
    }

    mediaItem.add(MediaItem(
      id: book.id,
      title: book.title,
      artist: 'Section ${_session.index + 1} of ${_session.chunks.length}',
    ));
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _session.isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: _session.isPlaying,
    ));
  }

  @override
  Future<void> play() => _session.play();

  @override
  Future<void> pause() => _session.pause();

  @override
  Future<void> skipToNext() => _session.next();

  @override
  Future<void> skipToPrevious() => _session.previous();

  @override
  Future<void> stop() async {
    await _session.pause();
    // Removes the notification until the user presses play again.
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }
}
