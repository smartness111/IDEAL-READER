import 'dart:convert';
import 'dart:io';

import 'package:epubx/epubx.dart' as epub;
import 'package:flutter/foundation.dart';

import 'docx_extractor.dart';
import 'image_ocr_service.dart';
import 'pdf_extractor.dart';

/// Turns a supported file into a list of read-aloud-sized text chunks, in
/// reading order, so the speech engine is never handed a whole novel at once.
///
/// [format] is the file extension, lower-cased (see Book.format): txt, epub,
/// docx, pdf, jpg, jpeg, or png. Everything here runs on-device.
///
/// The heavy parsing runs in a background isolate so the screen doesn't
/// freeze while a big book loads. (Image OCR uses a platform plugin, so it
/// has to stay on the main isolate.)
class TextExtractor {
  static Future<List<String>> extractChunks(
    String filePath,
    String format,
  ) async {
    final String text;
    switch (format) {
      case 'txt':
        text = await compute(_readTxt, filePath);
        break;
      case 'epub':
        text = await compute(_readEpub, filePath);
        break;
      case 'docx':
        text = await compute(DocxExtractor.extractText, filePath);
        break;
      case 'pdf':
        text = await compute(PdfExtractor.extractText, filePath);
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        text = await ImageOcrService.extractText(filePath);
        break;
      default:
        return [];
    }
    return compute(splitIntoChunks, text);
  }
}

Future<String> _readTxt(String path) async {
  final bytes = await File(path).readAsBytes();
  // allowMalformed: older text files saved in a non-UTF-8 encoding still
  // open instead of failing outright.
  return utf8.decode(bytes, allowMalformed: true);
}

Future<String> _readEpub(String path) async {
  final bytes = await File(path).readAsBytes();
  final book = await epub.EpubReader.readBook(bytes);
  final buffer = StringBuffer();

  void addChapter(epub.EpubChapter chapter) {
    final text = _htmlToText(chapter.HtmlContent ?? '');
    if (text.trim().isNotEmpty) {
      buffer
        ..writeln(text)
        ..writeln();
    }
    for (final sub in chapter.SubChapters ?? <epub.EpubChapter>[]) {
      addChapter(sub);
    }
  }

  for (final chapter in book.Chapters ?? <epub.EpubChapter>[]) {
    addChapter(chapter);
  }

  // Some e-books have no table of contents, so no "chapters". Fall back to
  // reading every HTML page in the file in stored order.
  if (buffer.isEmpty) {
    final htmlFiles = book.Content?.Html;
    if (htmlFiles != null) {
      for (final page in htmlFiles.values) {
        final text = _htmlToText(page.Content ?? '');
        if (text.trim().isNotEmpty) {
          buffer
            ..writeln(text)
            ..writeln();
        }
      }
    }
  }
  return buffer.toString();
}

String _htmlToText(String html) {
  var t = html
      .replaceAll(
        RegExp(r'<(script|style)[^>]*>.*?</\1>',
            caseSensitive: false, dotAll: true),
        ' ',
      )
      // Block-level endings become paragraph breaks so pauses land in the
      // right places.
      .replaceAll(
        RegExp(r'</(p|div|h[1-6]|li|tr|blockquote)>|<br\s*/?>',
            caseSensitive: false),
        '\n\n',
      )
      .replaceAll(RegExp(r'<[^>]*>'), ' ');

  t = t.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m[1]!, radix: 16);
    return (code != null && code > 0 && code <= 0x10FFFF)
        ? String.fromCharCode(code)
        : ' ';
  });
  t = t.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m[1]!);
    return (code != null && code > 0 && code <= 0x10FFFF)
        ? String.fromCharCode(code)
        : ' ';
  });

  return t
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&'); // last, so "&amp;lt;" isn't decoded twice
}

/// Longest piece of text handed to the speech engine in one go. Android's
/// engine refuses anything over about 4,000 characters, and shorter pieces
/// also make pause/skip respond faster.
const int _maxChunkLength = 600;

/// Splits text into paragraphs, then splits long paragraphs on sentence
/// boundaries, then (as a last resort) on words, so no chunk is oversized.
/// Public and top-level so it can run in a background isolate.
List<String> splitIntoChunks(String rawText) {
  final text = rawText
      .replaceAll('\uFEFF', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');

  final paragraphs = text
      .split(RegExp(r'\n\s*\n'))
      // Line breaks inside a paragraph (hard-wrapped text files, PDF lines)
      // become plain spaces so the voice doesn't stop at every line end.
      .map((p) => p
          .replaceAll(RegExp(r'\s*\n\s*'), ' ')
          .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
          .trim())
      .where((p) => p.isNotEmpty);

  final chunks = <String>[];
  for (final para in paragraphs) {
    if (para.length <= _maxChunkLength) {
      chunks.add(para);
      continue;
    }

    var current = StringBuffer();
    void flush() {
      final s = current.toString().trim();
      if (s.isNotEmpty) chunks.add(s);
      current = StringBuffer();
    }

    for (final sentence in para.split(RegExp(r'(?<=[.!?…])\s+'))) {
      if (sentence.length > _maxChunkLength) {
        // A single enormous "sentence" (no punctuation): split by words.
        flush();
        chunks.addAll(_splitByWords(sentence));
        continue;
      }
      if (current.length + sentence.length + 1 > _maxChunkLength) flush();
      current.write('$sentence ');
    }
    flush();
  }
  return chunks;
}

List<String> _splitByWords(String s) {
  final out = <String>[];
  var current = StringBuffer();
  void flush() {
    final t = current.toString().trim();
    if (t.isNotEmpty) out.add(t);
    current = StringBuffer();
  }

  for (final word in s.split(' ')) {
    if (word.length > _maxChunkLength) {
      // Not even a real word (e.g. a long run of symbols): slice it.
      flush();
      for (var i = 0; i < word.length; i += _maxChunkLength) {
        final end = (i + _maxChunkLength).clamp(0, word.length);
        out.add(word.substring(i, end));
      }
      continue;
    }
    if (current.length + word.length + 1 > _maxChunkLength) flush();
    current.write('$word ');
  }
  flush();
  return out;
}
