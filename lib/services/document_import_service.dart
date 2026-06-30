import 'dart:io';

import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/ocr_service.dart';

/// Shared on-device import for file picker and desktop drag-and-drop.
class DocumentImportService {
  DocumentImportService._();
  static final DocumentImportService instance = DocumentImportService._();

  final OcrService _ocrService = OcrService();

  static const _pdfExtensions = {'pdf'};
  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'bmp', 'webp'};

  static bool isSupportedPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _pdfExtensions.contains(ext) || _imageExtensions.contains(ext);
  }

  Future<int> importPaths(
    List<String> paths, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final files = paths
        .map((p) => File(p))
        .where((f) => f.existsSync() && isSupportedPath(f.path))
        .toList();
    if (files.isEmpty) return 0;

    final db = DocumentDatabase();
    final total = files.length;
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final pages = await _ocrService.extractText(file);
      final textContent =
          pages.isNotEmpty ? pages.map((p) => p.text).join('\n\n') : null;
      final thumbPath = await PDFManager.generateThumbnail(file.path);
      await db.insertDocument(
        file.path,
        textContent: textContent,
        thumbnailPath: thumbPath,
      );
      onProgress?.call(i + 1, total);
    }
    return files.length;
  }

  void dispose() => _ocrService.dispose();
}
