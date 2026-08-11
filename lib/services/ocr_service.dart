import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render_maintained/pdf_render.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_pdf/constants/preference_keys.dart';

class OcrPageResult {
  final int page;
  final String text;

  const OcrPageResult({required this.page, required this.text});

  int get wordCount =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  int get charCount => text.length;

  bool get isEmpty => text.trim().isEmpty;
}

class OcrService {
  TextRecognizer? _textRecognizer;
  String? _activeLanguage;

  /// Maps Settings language codes to ML Kit script models.
  /// en/fr/es/de/sw use Latin; ar has no dedicated model in this package version.
  static TextRecognitionScript scriptForLanguageCode(String code) {
    switch (code) {
      case 'zh':
        return TextRecognitionScript.chinese;
      case 'ja':
        return TextRecognitionScript.japanese;
      case 'ko':
        return TextRecognitionScript.korean;
      case 'hi':
        return TextRecognitionScript.devanagiri;
      case 'en':
      case 'fr':
      case 'es':
      case 'de':
      case 'ar':
      case 'sw':
      default:
        return TextRecognitionScript.latin;
    }
  }

  Future<TextRecognizer> _recognizer() async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString(kPrefOcrLanguage) ?? 'en';
    if (_textRecognizer == null || _activeLanguage != language) {
      await _textRecognizer?.close();
      _textRecognizer = TextRecognizer(
        script: scriptForLanguageCode(language),
      );
      _activeLanguage = language;
    }
    return _textRecognizer!;
  }

  /// Extracts text from a single image file.
  Future<OcrPageResult> extractTextFromImage(File imageFile) async {
    try {
      final recognizer = await _recognizer();
      final InputImage input = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognized = await recognizer.processImage(input);
      final String text = _structuredText(recognized);
      return OcrPageResult(page: 1, text: text);
    } catch (_) {
      return const OcrPageResult(page: 1, text: '');
    }
  }

  /// Extracts text from every page of a PDF, rendering at high resolution
  /// for better accuracy. Reports progress via [onProgress].
  Future<List<OcrPageResult>> extractTextFromPdf(
    File pdfFile, {
    void Function(int current, int total)? onProgress,
  }) async {
    final recognizer = await _recognizer();
    final pdfDoc = await PdfDocument.openFile(pdfFile.path);
    final int total = pdfDoc.pageCount;
    final List<OcrPageResult> results = [];
    final Directory tmp = await getTemporaryDirectory();

    try {
      for (int i = 1; i <= total; i++) {
        onProgress?.call(i, total);

        final page = await pdfDoc.getPage(i);
        // Cap render size to keep OCR from OOM-killing the process.
        final int renderWidth =
            (page.width * 1.25).round().clamp(800, 1400);
        final pageImage = await page.render(width: renderWidth);
        late final Uint8List pngBytes;
        try {
          final pixels = Uint8List.fromList(pageImage.pixels);
          final rawImg = img.Image.fromBytes(
            width: pageImage.width,
            height: pageImage.height,
            bytes: pixels.buffer,
            format: img.Format.uint8,
            numChannels: 4,
            order: img.ChannelOrder.rgba,
          );
          pngBytes = Uint8List.fromList(img.encodeJpg(rawImg, quality: 90));
        } finally {
          pageImage.dispose();
        }

        final tmpFile = File('${tmp.path}/ocr_p$i.jpg');
        await tmpFile.writeAsBytes(pngBytes);

        final InputImage input = InputImage.fromFilePath(tmpFile.path);
        final RecognizedText recognized =
            await recognizer.processImage(input);
        results.add(OcrPageResult(
          page: i,
          text: _structuredText(recognized),
        ));

        try {
          await tmpFile.delete();
        } catch (_) {}
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      await pdfDoc.dispose();
    }

    return results;
  }

  /// Dispatches to the right method and always returns a list of per-page results.
  Future<List<OcrPageResult>> extractText(
    File file, {
    void Function(int current, int total)? onProgress,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'bmp', 'webp'].contains(ext)) {
      onProgress?.call(1, 1);
      return [await extractTextFromImage(file)];
    } else if (ext == 'pdf') {
      return extractTextFromPdf(file, onProgress: onProgress);
    }
    return [];
  }

  String _structuredText(RecognizedText recognized) {
    if (recognized.blocks.isEmpty) return '';
    return recognized.blocks
        .map((b) => b.lines.map((l) => l.text).join('\n'))
        .join('\n\n');
  }

  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
    _activeLanguage = null;
  }
}
