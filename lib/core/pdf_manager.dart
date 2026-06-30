import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:pdf_render_maintained/pdf_render.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:quick_pdf/utils/path_utils.dart';
import 'pdf_processor.dart';

class PDFManager {
  /// Converts images to PDF — pure Dart, safe to run in the processor isolate.
  static Future<File> convertImagesToPDF(
    List<File> images, {
    String pageSize = 'A4',
    bool landscape = false,
    int quality = 85,
    double margin = 20.0,
    String? outputName,
  }) async {
    final List<List<int>> imageBytesList = [];
    for (final imageFile in images) {
      imageBytesList.add(await imageFile.readAsBytes());
    }

    final isolate = await PdfProcessorIsolate.spawn();
    final pdfBytes = await isolate.convertImagesToPDF(
      imageBytesList,
      pageSize: pageSize,
      landscape: landscape,
      quality: quality,
      margin: margin,
    );
    await isolate.kill();

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String filename = (outputName?.isNotEmpty == true)
        ? '$outputName.pdf'
        : 'QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final File pdfFile = File('${appDocDir.path}/$filename');
    await pdfFile.writeAsBytes(pdfBytes);
    return pdfFile;
  }

  /// Merges PDFs via Syncfusion templates so vector text and graphics stay
  /// selectable. Accepts per-document page selections and reports progress
  /// via [onProgress]. The [quality] parameter is retained for API
  /// compatibility but is not used (merge is lossless).
  static Future<File> mergePDFFiles(
    List<File> pdfs, {
    List<List<int>?>? pageSelections,
    int quality = 85,
    String? outputName,
    void Function(int current, int total)? onProgress,
  }) async {
    int totalPages = 0;
    for (int d = 0; d < pdfs.length; d++) {
      final sel = pageSelections?[d];
      if (sel != null) {
        totalPages += sel.length;
      } else {
        final bytes = await pdfs[d].readAsBytes();
        final tmp = sf.PdfDocument(inputBytes: bytes.toList());
        totalPages += tmp.pages.count;
        tmp.dispose();
      }
    }

    final sf.PdfDocument merged = sf.PdfDocument();
    int donePages = 0;

    try {
      for (int docIdx = 0; docIdx < pdfs.length; docIdx++) {
        final bytes = await pdfs[docIdx].readAsBytes();
        final source = sf.PdfDocument(inputBytes: bytes.toList());
        final int total = source.pages.count;
        final List<int>? sel = pageSelections?[docIdx];

        final List<int> pages = sel != null
            ? (sel.where((p) => p >= 1 && p <= total).toList()..sort())
            : List.generate(total, (i) => i + 1);

        for (final pageNum in pages) {
          donePages++;
          onProgress?.call(donePages, totalPages);

          final srcPage = source.pages[pageNum - 1];
          final template = srcPage.createTemplate();
          final destPage = merged.pages.add();
          destPage.graphics.drawPdfTemplate(template, ui.Offset.zero);

          await Future.delayed(Duration.zero);
        }
        source.dispose();
      }

      final List<int> mergedBytes = merged.saveSync();
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String filename = (outputName?.isNotEmpty == true)
          ? '$outputName.pdf'
          : 'Merged_QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final File mergedFile = File('${appDocDir.path}/$filename');
      await mergedFile.writeAsBytes(mergedBytes);
      return mergedFile;
    } finally {
      merged.dispose();
    }
  }

  /// Compresses a PDF on the main isolate so pdf_render's platform channels work.
  /// Reports progress via [onProgress].
  static Future<File> compressPDF(
    File pdfFile, {
    int imageQuality = 65,
    double renderScale = 1.0,
    String? outputName,
    void Function(int current, int total)? onProgress,
  }) async {
    final Uint8List pdfBytes = await pdfFile.readAsBytes();
    final source = await PdfDocument.openData(pdfBytes);
    final pw.Document target = pw.Document(compress: true);
    final int pageCount = source.pageCount;

    for (int i = 1; i <= pageCount; i++) {
      onProgress?.call(i, pageCount);

      final page = await source.getPage(i);
      final int rw = (page.width * renderScale).round();
      final int rh = (page.height * renderScale).round();
      final pageImage = await page.render(width: rw, height: rh);

      // Yield so Flutter can process redraws between pages.
      await Future.delayed(Duration.zero);

      final image = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pageImage.pixels.buffer,
        format: img.Format.uint8,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final encoded =
          Uint8List.fromList(img.encodeJpg(image, quality: imageQuality));

      // Page size in PDF points (page.width/height), NOT pixel dimensions.
      target.addPage(pw.Page(
        pageFormat: PdfPageFormat(page.width, page.height),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(encoded)),
      ));

      await Future.delayed(Duration.zero);
    }
    await source.dispose();

    final Uint8List compressedBytes = await target.save();
    // Never write a larger file — fall back to the original bytes if compression
    // produced no benefit (e.g. text-only / already-optimised PDFs).
    final Uint8List outputBytes =
        compressedBytes.length < pdfBytes.length ? compressedBytes : pdfBytes;
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String filename = (outputName?.isNotEmpty == true)
        ? '$outputName.pdf'
        : 'Compressed_QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final File compressedFile = File('${appDocDir.path}/$filename');
    await compressedFile.writeAsBytes(outputBytes);
    return compressedFile;
  }

  /// Splits a PDF into individual pages (or a page range) via Syncfusion
  /// templates so each output page preserves vector content.
  static Future<List<File>> splitPDF(
    File pdfFile, {
    List<int>? pages, // 1-indexed; null = every page
    String? outputNamePrefix,
    void Function(int current)? onProgress,
  }) async {
    final bytes = await pdfFile.readAsBytes();
    final source = sf.PdfDocument(inputBytes: bytes.toList());
    final int total = source.pages.count;
    final List<int> targetPages =
        pages ?? List.generate(total, (i) => i + 1);
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final stem = outputNamePrefix ?? fileStem(pdfFile.path);
    final List<File> results = [];
    final String padLen = total.toString();

    try {
      for (int i = 0; i < targetPages.length; i++) {
        final int pageNum = targetPages[i];
        onProgress?.call(i + 1);

        if (pageNum < 1 || pageNum > total) continue;

        final srcPage = source.pages[pageNum - 1];
        final template = srcPage.createTemplate();
        final single = sf.PdfDocument();
        try {
          single.pages.add().graphics.drawPdfTemplate(template, ui.Offset.zero);

          final padded = pageNum.toString().padLeft(padLen.length, '0');
          final File outFile =
              File('${appDocDir.path}/${stem}_p$padded.pdf');
          await outFile.writeAsBytes(single.saveSync());
          results.add(outFile);
        } finally {
          single.dispose();
        }

        await Future.delayed(Duration.zero);
      }
    } finally {
      source.dispose();
    }
    return results;
  }

  /// Updates PDF metadata by rasterising pages into a new document.
  static Future<File> updatePDFMetadata(
    File pdfFile, {
    String? author,
    String? title,
    String? subject,
    String? keywords,
  }) async {
    final Uint8List pdfBytes = await pdfFile.readAsBytes();
    final sourceDoc = await PdfDocument.openData(pdfBytes);

    final pw.Document updatedPdf = pw.Document(
      compress: true,
      author: author,
      title: title,
      subject: subject,
      keywords: keywords,
      creator: 'QuickPDF',
    );

    for (int i = 1; i <= sourceDoc.pageCount; i++) {
      final page = await sourceDoc.getPage(i);
      final pageImage = await page.render(
        width: page.width.toInt(),
        height: page.height.toInt(),
      );
      await Future.delayed(Duration.zero);

      final image = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pageImage.pixels.buffer,
        format: img.Format.uint8,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final pngBytes = img.encodePng(image);
      updatedPdf.addPage(pw.Page(
        pageFormat: PdfPageFormat(page.width, page.height),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(pngBytes)),
      ));
      await Future.delayed(Duration.zero);
    }
    await sourceDoc.dispose();

    final Uint8List updatedBytes = await updatedPdf.save();
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final File updatedFile = File(
        '${appDocDir.path}/UpdatedMetadata_QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await updatedFile.writeAsBytes(updatedBytes);
    return updatedFile;
  }

  /// Encrypts a PDF with AES-256 password protection without rasterising pages,
  /// so the original text and quality are fully preserved.
  static Future<File> encryptPDF(
    File pdfFile, {
    required String userPassword,
    String? ownerPassword,
    void Function(int current, int total)? onProgress,
  }) async {
    final Uint8List pdfBytes = await pdfFile.readAsBytes();
    onProgress?.call(0, 1);

    final sf.PdfDocument doc =
        sf.PdfDocument(inputBytes: pdfBytes.toList());
    doc.security
      ..userPassword = userPassword
      ..ownerPassword = ownerPassword ?? userPassword
      ..algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;

    final List<int> outBytes = doc.saveSync();
    doc.dispose();
    onProgress?.call(1, 1);

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final File out = File(
        '${appDocDir.path}/Protected_QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await out.writeAsBytes(outBytes);
    return out;
  }

  /// Removes the password from a PDF. Throws if the password is incorrect.
  static Future<File> decryptPDF(
    File pdfFile, {
    required String password,
    void Function(int current, int total)? onProgress,
  }) async {
    final Uint8List pdfBytes = await pdfFile.readAsBytes();
    onProgress?.call(0, 1);

    final sf.PdfDocument doc =
        sf.PdfDocument(inputBytes: pdfBytes.toList(), password: password);
    doc.security
      ..userPassword = ''
      ..ownerPassword = '';

    final List<int> outBytes = doc.saveSync();
    doc.dispose();
    onProgress?.call(1, 1);

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final File out = File(
        '${appDocDir.path}/Unlocked_QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await out.writeAsBytes(outBytes);
    return out;
  }

  /// Applies a text watermark to every page of a PDF.
  static Future<File> addWatermark(
    File pdfFile, {
    required String text,
    double opacity = 0.3,
    double fontSize = 48,
    double rotationDegrees = -30,
    void Function(int current, int total)? onProgress,
  }) async {
    final Uint8List pdfBytes = await pdfFile.readAsBytes();
    final source = await PdfDocument.openData(pdfBytes);
    final target = pw.Document(compress: true);
    final int pageCount = source.pageCount;

    for (int i = 1; i <= pageCount; i++) {
      onProgress?.call(i, pageCount);
      final page = await source.getPage(i);
      final pageImage = await page.render(
        width: (page.width * 2).round(),
        height: (page.height * 2).round(),
      );
      await Future.delayed(Duration.zero);

      final image = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pageImage.pixels.buffer,
        format: img.Format.uint8,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final encoded = Uint8List.fromList(img.encodeJpg(image, quality: 90));

      target.addPage(pw.Page(
        pageFormat: PdfPageFormat(page.width, page.height),
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Stack(
          children: [
            pw.Image(pw.MemoryImage(encoded)),
            pw.Center(
              child: pw.Transform.rotate(
                angle: rotationDegrees * 3.14159 / 180,
                child: pw.Opacity(
                  opacity: opacity,
                  child: pw.Text(
                    text,
                    style: pw.TextStyle(
                      fontSize: fontSize,
                      color: PdfColors.grey,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ));
      await Future.delayed(Duration.zero);
    }
    await source.dispose();

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final File out = File(
        '${appDocDir.path}/Watermarked_QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await out.writeAsBytes(await target.save());
    return out;
  }

  /// Reorders / selects pages from a PDF. [pageOrder] is a 1-indexed list
  /// of page numbers in the desired output order (may include duplicates or
  /// omit pages to delete them). [rotations] provides clockwise rotation in
  /// degrees (0, 90, 180, 270) for each output page.
  static Future<File> reorderPages(
    File pdfFile, {
    required List<int> pageOrder,
    List<int>? rotations,
    void Function(int current, int total)? onProgress,
  }) async {
    final Uint8List pdfBytes = await pdfFile.readAsBytes();
    final source = await PdfDocument.openData(pdfBytes);
    final target = pw.Document(compress: true);
    final int total = pageOrder.length;

    for (int i = 0; i < total; i++) {
      onProgress?.call(i + 1, total);
      final pageNum = pageOrder[i];
      if (pageNum < 1 || pageNum > source.pageCount) continue;

      final page = await source.getPage(pageNum);
      final pageImage = await page.render(
        width: (page.width * 2).round(),
        height: (page.height * 2).round(),
      );
      await Future.delayed(Duration.zero);

      final image = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pageImage.pixels.buffer,
        format: img.Format.uint8,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

      final rotation = (rotations != null && i < rotations.length)
          ? rotations[i] % 360
          : 0;
      final img.Image outputImage = rotation == 0
          ? image
          : img.copyRotate(image, angle: rotation.toDouble());

      final encoded =
          Uint8List.fromList(img.encodeJpg(outputImage, quality: 90));
      final pageWidth =
          rotation % 180 == 0 ? page.width : page.height;
      final pageHeight =
          rotation % 180 == 0 ? page.height : page.width;

      target.addPage(pw.Page(
        pageFormat: PdfPageFormat(pageWidth, pageHeight),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(encoded)),
      ));
      await Future.delayed(Duration.zero);
    }
    await source.dispose();

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final File out = File(
        '${appDocDir.path}/Reordered_QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await out.writeAsBytes(await target.save());
    return out;
  }

  static Future<int> getPageCount(String path) async {
    try {
      final doc = await PdfDocument.openFile(path);
      final count = doc.pageCount;
      await doc.dispose();
      return count;
    } catch (_) {
      return 0;
    }
  }

  static void hapticFeedbackSuccess() => HapticFeedback.lightImpact();
  static void hapticFeedbackError() => HapticFeedback.heavyImpact();

  static Future<String?> generateThumbnail(String path,
      {String? existingThumbPath}) async {
    try {
      final sourceFile = File(path);
      if (!await sourceFile.exists()) return null;

      final cacheDir = await getApplicationCacheDirectory();
      final thumbDir = Directory('${cacheDir.path}/thumbnails');
      if (!await thumbDir.exists()) await thumbDir.create(recursive: true);

      // Stable cache key so the same source always maps to the same thumb file.
      final key = path.hashCode.abs().toString();
      final thumbPath = '${thumbDir.path}/thumb_$key.png';
      final thumbFile = File(thumbPath);

      // Skip regeneration if the cached thumb is newer than the source.
      if (await thumbFile.exists()) {
        final sourceModified = (await sourceFile.stat()).modified;
        final thumbModified = (await thumbFile.stat()).modified;
        if (thumbModified.isAfter(sourceModified)) return thumbPath;
      }

      final ext = path.split('.').last.toLowerCase();

      if (ext == 'pdf') {
        final doc = await PdfDocument.openFile(path);
        final page = await doc.getPage(1);
        final rendered = await page.render(width: 200);
        final uiImage = await rendered.createImageIfNotAvailable();
        final bd = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        uiImage.dispose();
        await doc.dispose();
        if (bd != null) {
          await thumbFile.writeAsBytes(bd.buffer.asUint8List());
          return thumbPath;
        }
      } else if (['jpg', 'jpeg', 'png', 'bmp', 'webp'].contains(ext)) {
        final bytes = await sourceFile.readAsBytes();
        final original = img.decodeImage(Uint8List.fromList(bytes));
        if (original != null) {
          final thumb = img.copyResize(original, width: 200);
          await thumbFile.writeAsBytes(img.encodePng(thumb));
          return thumbPath;
        }
      }
    } catch (_) {}
    return null;
  }
}
