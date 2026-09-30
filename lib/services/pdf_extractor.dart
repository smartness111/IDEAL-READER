import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Extracts plain text from a PDF's embedded text layer, entirely on-device.
///
/// This reads text that was typed into the PDF (documents exported from
/// Word, Google Docs, etc.). A PDF that is only photographed or scanned
/// pages has no text layer and will come back empty; there is no OCR
/// fallback for that case yet. Password-protected PDFs are not supported.
///
/// Static and self-contained so it can run in a background isolate.
class PdfExtractor {
  static Future<String> extractText(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final PdfDocument document;
    try {
      document = PdfDocument(inputBytes: bytes);
    } catch (_) {
      throw const FormatException(
        'This PDF could not be opened. It may be damaged or '
        'password-protected.',
      );
    }
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }
}
