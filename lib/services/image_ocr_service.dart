import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads the text out of a photo or scanned page (JPEG/PNG), fully offline.
///
/// - Android: Google's ML Kit on-device text recognition. The plugin ships
///   the Latin-script model inside the app package, so no download and no
///   internet are ever needed.
/// - Windows: the text recognition built into Windows 10/11 itself
///   (Windows.Media.Ocr), called through the PowerShell that comes with
///   Windows. Nothing extra to install and nothing leaves the PC. This
///   route needs an OCR-capable language installed in Windows (English and
///   most major languages are by default). If it fails for any reason, the
///   app explains the manual "Photos > Text actions" alternative instead.
class ImageOcrService {
  static Future<String> extractText(String filePath) async {
    if (Platform.isAndroid) return _androidOcr(filePath);
    if (Platform.isWindows) return _windowsOcr(filePath);
    throw UnsupportedError(
      'Reading text from images is only available on Android and Windows.',
    );
  }

  // ---------------------------------------------------------------- Android

  static Future<String> _androidOcr(String filePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final result = await recognizer.processImage(inputImage);
      return result.text;
    } finally {
      recognizer.close();
    }
  }

  // ---------------------------------------------------------------- Windows

  static const _manualFallback =
      'You can still do it by hand, for free: open the image in the Photos '
      'app (or Snipping Tool), use "Text actions" to copy the text, paste it '
      'into a .txt file, and import that file instead.';

  // Windows PowerShell 5.1 (built into Windows) can call the Windows
  // Runtime OCR engine directly. The path arrives through an environment
  // variable so odd characters in file names can't break the script.
  static const _windowsOcrScript = r'''
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.SoftwareBitmap,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine,Windows.Media.Ocr,ContentType=WindowsRuntime]
$null = [Windows.Media.Ocr.OcrResult,Windows.Media.Ocr,ContentType=WindowsRuntime]

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
  $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

function Await($operation, $resultType) {
  $task = $asTaskGeneric.MakeGenericMethod($resultType).Invoke($null, @($operation))
  $task.Wait(-1) | Out-Null
  $task.Result
}

$path = $env:IDEAL_READER_OCR_IMAGE
$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($path)) ([Windows.Storage.StorageFile])
$stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
$decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
$bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
if ($null -eq $engine) { exit 3 }
$result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
$result.Lines | ForEach-Object { $_.Text }
''';

  static Future<String> _windowsOcr(String filePath) async {
    // PowerShell's -EncodedCommand wants the script as base64 UTF-16LE.
    final bytes = <int>[];
    for (final unit in _windowsOcrScript.codeUnits) {
      bytes
        ..add(unit & 0xFF)
        ..add(unit >> 8);
    }

    final ProcessResult result;
    try {
      result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-WindowStyle',
          'Hidden',
          '-ExecutionPolicy',
          'Bypass',
          '-EncodedCommand',
          base64Encode(bytes),
        ],
        environment: {'IDEAL_READER_OCR_IMAGE': filePath},
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    } catch (_) {
      throw UnsupportedError(
        'Windows text recognition could not be started on this PC. '
        '$_manualFallback',
      );
    }

    if (result.exitCode == 3) {
      throw UnsupportedError(
        'Windows has no text-recognition language installed for your '
        'profile. Add one in Settings > Time & language > Language & '
        'region (this needs a one-time download by Windows, not by this '
        'app). $_manualFallback',
      );
    }
    if (result.exitCode != 0) {
      throw UnsupportedError(
        'Windows could not read the text in this image. $_manualFallback',
      );
    }

    final text = (result.stdout as String).trim();
    if (text.isEmpty) {
      throw UnsupportedError(
        'No readable text was found in this image. Try a sharper, '
        'straight-on picture.',
      );
    }
    return text;
  }
}
