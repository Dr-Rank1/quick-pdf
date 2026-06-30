import 'dart:io';

/// Extra payload for [AppRoutes.pdfExport].
class PdfExportExtra {
  final File file;
  final String format;

  const PdfExportExtra({required this.file, required this.format});
}
