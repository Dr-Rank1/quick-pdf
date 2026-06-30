import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_pdf/router/app_routes.dart';
import 'package:quick_pdf/router/route_extra.dart';

/// Typed navigation helpers for [go_router] routes.
extension AppNavigation on BuildContext {
  void goHome() => go(AppRoutes.home);

  Future<Object?> pushScan() => push(AppRoutes.scan);

  Future<Object?> pushConvert(List<File> images) =>
      push(AppRoutes.convert, extra: images);

  Future<Object?> pushMerge(List<File> files) =>
      push(AppRoutes.merge, extra: files);

  Future<Object?> pushSplit(File file) =>
      push(AppRoutes.split, extra: file);

  Future<Object?> pushCompress(File file) =>
      push(AppRoutes.compress, extra: file);

  Future<Object?> pushOcr(File file) => push(AppRoutes.ocr, extra: file);

  Future<Object?> pushFormatConverter() => push(AppRoutes.formatConverter);

  Future<Object?> pushPdfExport(File file, String format) => push(
        AppRoutes.pdfExport,
        extra: PdfExportExtra(file: file, format: format),
      );

  Future<Object?> pushExportText() => push(AppRoutes.exportText);

  Future<Object?> pushAnnotate() => push(AppRoutes.annotate);

  Future<Object?> pushSign() => push(AppRoutes.sign);

  Future<Object?> pushBatch() => push(AppRoutes.batch);

  Future<Object?> pushPageManager(File file) =>
      push(AppRoutes.pageManager, extra: file);

  Future<Object?> pushWatermark() => push(AppRoutes.watermark);

  Future<Object?> pushPasswordProtect() => push(AppRoutes.passwordProtect);

  Future<Object?> pushEditMetadata(File file) =>
      push(AppRoutes.editMetadata, extra: file);

  Future<Object?> openPdfViewer(String path, {String? heroTag}) => push(
        AppRoutes.pdfViewerLocation(path, heroTag: heroTag),
      );

  void replaceWithPdfViewer(String path) {
    pushReplacement(AppRoutes.pdfViewerLocation(path));
  }

  Future<Object?> openImageViewer(String path) =>
      push(AppRoutes.imageViewerLocation(path));
}
