import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Extracts plain text from a modern Word document (.docx).
///
/// A .docx file is just a zip archive of XML files, so this unzips it and
/// reads the paragraph text straight out of word/document.xml. No native
/// plugin is needed, which is why it behaves identically on Windows and
/// Android and works fully offline.
///
/// This does NOT support the old binary .doc format (Word 2003 and
/// earlier). Re-save such a file as .docx (Word's "Save As", or the free
/// LibreOffice) and import that instead.
///
/// Static and self-contained so it can run in a background isolate.
class DocxExtractor {
  static Future<String> extractText(String filePath) async {
    final bytes = await File(filePath).readAsBytes();

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException(
        'This file could not be opened as a .docx document. If it is an old '
        '.doc file, re-save it as .docx in Word or LibreOffice first.',
      );
    }

    ArchiveFile? documentFile;
    for (final f in archive.files) {
      if (f.name == 'word/document.xml') {
        documentFile = f;
        break;
      }
    }
    if (documentFile == null) {
      throw const FormatException(
        'This does not look like a valid .docx file. If it is an old .doc '
        'file, re-save it as .docx in Word or LibreOffice first.',
      );
    }

    // Word stores text as UTF-8; decoding it byte-by-byte would garble any
    // accented or non-English characters.
    final xmlString =
        utf8.decode(documentFile.content as List<int>, allowMalformed: true);
    final document = XmlDocument.parse(xmlString);

    final buffer = StringBuffer();
    // <w:p> is a paragraph. Inside it, <w:t> is visible text, <w:tab> a tab
    // and <w:br> a line break.
    for (final paragraph in document.findAllElements('w:p')) {
      final line = StringBuffer();
      for (final node in paragraph.descendantElements) {
        final name = node.name.qualified;
        if (name == 'w:t') {
          line.write(node.innerText);
        } else if (name == 'w:tab' || name == 'w:br') {
          line.write(' ');
        }
      }
      final text = line.toString().trim();
      if (text.isNotEmpty) {
        buffer
          ..writeln(text)
          ..writeln();
      }
    }
    return buffer.toString();
  }
}
