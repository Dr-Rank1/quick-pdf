import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
        .map((path) => File(path))
        .where((f) => f.existsSync() && isSupportedPath(f.path))
        .toList();
    if (files.isEmpty) return 0;

    // Copy into app documents so library entries survive cache/Downloads cleanup.
    final appDir = await getApplicationDocumentsDirectory();
    final importDir = Directory('${appDir.path}/imports');
    if (!await importDir.exists()) {
      await importDir.create(recursive: true);
    }

    final db = DocumentDatabase();
    final total = files.length;
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
      final dest = File(
        '${importDir.path}/Import_${DateTime.now().millisecondsSinceEpoch}_$i.$ext',
      );
      await file.copy(dest.path);

      final pages = await _ocrService.extractText(dest);
      final textContent =
          pages.isNotEmpty ? pages.map((page) => page.text).join('\n\n') : null;
      final thumbPath = await PDFManager.generateThumbnail(dest.path);
      await db.insertDocument(
        dest.path,
        textContent: textContent,
        thumbnailPath: thumbPath,
      );
      onProgress?.call(i + 1, total);
    }
    return files.length;
  }

  void dispose() => _ocrService.dispose();
}
