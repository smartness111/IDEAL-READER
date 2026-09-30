import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/background_reading.dart';
import '../services/reading_session.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;
  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  // Reading itself happens in the session, not in this screen, so it keeps
  // going when the app is minimized or the phone is locked.
  final _session = ReadingSession.instance;

  double _fontSize = 18;
  double? _dragValue; // position while the user drags the progress slider

  @override
  void initState() {
    super.initState();
    _session.addListener(_showSpeechErrorIfAny);
    _session.open(widget.book);
  }

  @override
  void dispose() {
    _session.removeListener(_showSpeechErrorIfAny);
    // Leaving the reader (Back) stops reading. Minimizing the app or locking
    // the screen does not come through here, so reading continues then.
    _session.close();
    super.dispose();
  }

  void _showSpeechErrorIfAny() {
    final message = _session.speechError;
    if (message == null || !mounted) return;
    _session.clearSpeechError();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _play() {
    // Android 13+ asks once whether the reading notification may be shown.
    unawaited(BackgroundReading.askForNotificationsOnce());
    _session.play();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.book.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Voice and text settings',
                onPressed: _session.isLoading ? null : _showSettings,
              ),
            ],
          ),
          body: SafeArea(child: _buildBody()),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_session.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing your book...'),
          ],
        ),
      );
    }

    final error = _session.errorMessage;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final chunks = _session.chunks;
    if (chunks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No readable text was found in this file.\n\n'
            'If it is a scanned PDF (pages that are just pictures), try '
            'importing the pages as images instead.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final index = _session.index.clamp(0, chunks.length - 1);
    final shownIndex = (_dragValue ?? index.toDouble()).round();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Text(
              chunks[index],
              style: TextStyle(fontSize: _fontSize, height: 1.5),
            ),
          ),
        ),
        if (chunks.length > 1)
          Slider(
            value: _dragValue ?? index.toDouble(),
            min: 0,
            max: (chunks.length - 1).toDouble(),
            onChanged: (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) {
              setState(() => _dragValue = null);
              _session.jumpTo(v.round());
            },
          ),
        Text(
          'Section ${shownIndex + 1} of ${chunks.length}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                iconSize: 32,
                tooltip: 'Previous section',
                icon: const Icon(Icons.skip_previous),
                onPressed: _session.previous,
              ),
              IconButton(
                iconSize: 56,
                tooltip: _session.isPlaying ? 'Pause' : 'Read aloud',
                icon: Icon(_session.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled),
                onPressed: _session.isPlaying ? _session.pause : _play,
              ),
              IconButton(
                iconSize: 32,
                tooltip: 'Next section',
                icon: const Icon(Icons.skip_next),
                onPressed: _session.next,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final textTheme = Theme.of(context).textTheme;
            final voices = _session.voices;
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Speed', style: textTheme.titleMedium),
                    Slider(
                      value: _session.rate,
                      min: 0.1,
                      max: 1.0,
                      onChanged: (v) {
                        _session.setRate(v);
                        setModalState(() {});
                      },
                    ),
                    Text('Pitch', style: textTheme.titleMedium),
                    Slider(
                      value: _session.pitch,
                      min: 0.5,
                      max: 2.0,
                      onChanged: (v) {
                        _session.setPitch(v);
                        setModalState(() {});
                      },
                    ),
                    Text('Text size', style: textTheme.titleMedium),
                    Slider(
                      value: _fontSize,
                      min: 14,
                      max: 32,
                      onChanged: (v) {
                        setModalState(() => _fontSize = v);
                        setState(() {});
                      },
                    ),
                    if (voices.isNotEmpty) ...[
                      Text('Voice (installed on this device)',
                          style: textTheme.titleMedium),
                      DropdownButton<Map<String, String>>(
                        isExpanded: true,
                        value: _session.selectedVoice,
                        hint: const Text('Default'),
                        items: voices
                            .map((v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(
                                    '${v['name']} (${v['locale']})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          _session.selectVoice(v);
                          setModalState(() {});
                        },
                      ),
                    ],
                    if (Platform.isAndroid && BackgroundReading.isActive) ...[
                      const SizedBox(height: 12),
                      Text('Reading with the screen locked',
                          style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'If reading stops when the screen locks, allow the '
                        'app to run in the background.',
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.battery_saver),
                        label: const Text('Allow background reading'),
                        onPressed: BackgroundReading.askToRunInBackground,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
