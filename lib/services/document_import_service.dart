import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/document_database.dart';

/// Shared on-device import for file picker and desktop drag-and-drop.
class DocumentImportService {
  DocumentImportService._();
  static final DocumentImportService instance = DocumentImportService._();

  static const _pdfExtensions = {'pdf'};
  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'bmp', 'webp'};

  static bool isSupportedPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _pdfExtensions.contains(ext) || _imageExtensions.contains(ext);
  }

  /// Copies files into app documents and indexes them.
  /// OCR is intentionally deferred (run from the OCR tool) so import cannot
  /// ANR/OOM the app on large multi-page PDFs.
  Future<int> importPaths(
    List<String> paths, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final files = paths
        .map((path) => File(path))
        .where((f) => f.existsSync() && isSupportedPath(f.path))
        .toList();
    if (files.isEmpty) return 0;

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

      final thumbPath = await PDFManager.generateThumbnail(dest.path);
      await db.insertDocument(
        dest.path,
        thumbnailPath: thumbPath,
      );
      onProgress?.call(i + 1, total);
      // Yield so the UI can paint between files.
      await Future<void>.delayed(Duration.zero);
    }
    return files.length;
  }

  void dispose() {}
}
