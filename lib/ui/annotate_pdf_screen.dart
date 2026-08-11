import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_render_maintained/pdf_render.dart' as render;
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/file_picker_service.dart';

enum _Tool { pen, highlighter, eraser }

class _Stroke {
  /// Points are normalised 0–1 fractions of the canvas.
  final List<Offset> points;
  final Color color;
  /// Stroke width in logical pixels at paint time.
  final double width;
  final bool isEraser;
  /// Non-null => stamp centered at [points.first].
  final String? stampLabel;

  const _Stroke({
    required this.points,
    required this.color,
    required this.width,
    required this.isEraser,
    this.stampLabel,
  });

  bool get isStamp => stampLabel != null;
}

class AnnotatePdfScreen extends StatefulWidget {
  final File? initialFile;
  const AnnotatePdfScreen({super.key, this.initialFile});

  @override
  State<AnnotatePdfScreen> createState() => _AnnotatePdfScreenState();
}

class _AnnotatePdfScreenState extends State<AnnotatePdfScreen> {
  File? _pdfFile;
  int _pageCount = 0;
  int _currentPage = 1;

  final Map<int, List<_Stroke>> _annotations = {};
  List<_Stroke> get _currentAnnotations =>
      _annotations[_currentPage] ??= [];

  List<Offset> _currentPoints = [];
  _Tool _selectedTool = _Tool.pen;
  Color _penColor = Colors.red;
  final double _penWidth = 3.0;

  Uint8List? _pageImage;
  bool _loadingPage = false;
  render.PdfDocument? _doc;

  bool _isProcessing = false;
  int _progress = 0;
  int _total = 0;

  Size _canvasSize = Size.zero;

  static const _stamps = ['APPROVED', 'DRAFT', 'CONFIDENTIAL'];
  static const double _canvasRenderWidth = 1000;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadPdf(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _doc?.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final files = await FilePickerService.pickMultipleFiles(
        allowedExtensions: ['pdf']);
    if (files == null || files.isEmpty) return;
    _loadPdf(files.first);
  }

  Future<void> _loadPdf(File file) async {
    _doc?.dispose();
    _doc = null;
    setState(() {
      _pdfFile = file;
      _pageImage = null;
      _annotations.clear();
      _currentPage = 1;
    });
    try {
      final doc = await render.PdfDocument.openFile(file.path);
      setState(() {
        _doc = doc;
        _pageCount = doc.pageCount;
      });
      _loadPageImage();
    } catch (e) {
      _snack('Failed to open PDF: $e');
    }
  }

  Future<void> _loadPageImage() async {
    final doc = _doc;
    if (doc == null) return;
    setState(() {
      _loadingPage = true;
      _pageImage = null;
    });
    try {
      final page = await doc.getPage(_currentPage);
      final rendered = await page.render(width: _canvasRenderWidth.round());
      final uiImage = await rendered.createImageIfNotAvailable();
      final bd = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();
      if (mounted && bd != null) {
        setState(() => _pageImage = bd.buffer.asUint8List());
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPage = false);
  }

  Color get _toolColor {
    switch (_selectedTool) {
      case _Tool.pen:
        return _penColor;
      case _Tool.highlighter:
        return _penColor.withValues(alpha: 0.35);
      case _Tool.eraser:
        return Colors.white;
    }
  }

  double get _toolWidth {
    switch (_selectedTool) {
      case _Tool.pen:
        return _penWidth;
      case _Tool.highlighter:
        return 18;
      case _Tool.eraser:
        return 24;
    }
  }

  Offset _normalize(Offset local) {
    final w = _canvasSize.width;
    final h = _canvasSize.height;
    if (w <= 0 || h <= 0) return Offset.zero;
    return Offset(
      (local.dx / w).clamp(0.0, 1.0),
      (local.dy / h).clamp(0.0, 1.0),
    );
  }

  void _addStamp(String label) {
    setState(() {
      _currentAnnotations.add(_Stroke(
        points: const [Offset(0.5, 0.5)],
        color: Colors.red.withValues(alpha: 0.85),
        width: 0,
        isEraser: false,
        stampLabel: label,
      ));
    });
  }

  Future<void> _save() async {
    if (_pdfFile == null) {
      _snack('No PDF loaded.');
      return;
    }
    setState(() {
      _isProcessing = true;
      _progress = 0;
      _total = _pageCount;
    });

    try {
      await AdService().showRewardedOrFallback(onRewarded: () async {
        final Uint8List pdfBytes = await _pdfFile!.readAsBytes();
        final source = await render.PdfDocument.openData(pdfBytes);
        try {
          final target = pw.Document(compress: true);

          for (int i = 1; i <= source.pageCount; i++) {
            if (mounted) setState(() => _progress = i);
            final page = await source.getPage(i);
            final pageImg = await page.render(
              width: (page.width * 2).round(),
              height: (page.height * 2).round(),
            );
            await Future.delayed(Duration.zero);

            final baseImg = img.Image.fromBytes(
              width: pageImg.width,
              height: pageImg.height,
              bytes: pageImg.pixels.buffer,
              format: img.Format.uint8,
              numChannels: 4,
              order: img.ChannelOrder.rgba,
            );

            final strokes = _annotations[i] ?? [];
            if (strokes.isNotEmpty) {
              final widthScale = pageImg.width /
                  (_canvasSize.width > 0
                      ? _canvasSize.width
                      : _canvasRenderWidth);
              _compositeStrokes(baseImg, strokes, widthScale);
            }

            final encoded =
                Uint8List.fromList(img.encodeJpg(baseImg, quality: 90));
            target.addPage(pw.Page(
              pageFormat: PdfPageFormat(page.width, page.height),
              margin: pw.EdgeInsets.zero,
              build: (_) => pw.Image(pw.MemoryImage(encoded)),
            ));
            await Future.delayed(Duration.zero);
          }

          final dir = await getApplicationDocumentsDirectory();
          final out = File(
              '${dir.path}/Annotated_QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf');
          await out.writeAsBytes(await target.save());

          final thumbPath = await PDFManager.generateThumbnail(out.path);
          await DocumentDatabase()
              .insertDocument(out.path, thumbnailPath: thumbPath);
          PDFManager.hapticFeedbackSuccess();
          if (mounted) {
            _snack('Saved: ${fileName(out.path)}');
            Navigator.of(context).pop();
          }
        } finally {
          await source.dispose();
        }
      });
    } catch (e) {
      PDFManager.hapticFeedbackError();
      if (mounted) _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _compositeStrokes(
      img.Image dest, List<_Stroke> strokes, double widthScale) {
    for (final stroke in strokes) {
      if (stroke.isStamp) {
        _compositeStamp(dest, stroke);
        continue;
      }
      if (stroke.points.length < 2) continue;

      final color = stroke.isEraser
          ? img.ColorRgba8(255, 255, 255, 255)
          : img.ColorRgba8(
              (stroke.color.r * 255).round(),
              (stroke.color.g * 255).round(),
              (stroke.color.b * 255).round(),
              (stroke.color.a * 255).round(),
            );
      final thickness = (stroke.width * widthScale).round().clamp(1, 120);

      for (var j = 0; j < stroke.points.length - 1; j++) {
        img.drawLine(
          dest,
          x1: (stroke.points[j].dx * dest.width).round(),
          y1: (stroke.points[j].dy * dest.height).round(),
          x2: (stroke.points[j + 1].dx * dest.width).round(),
          y2: (stroke.points[j + 1].dy * dest.height).round(),
          color: color,
          thickness: thickness,
        );
      }
    }
  }

  void _compositeStamp(img.Image dest, _Stroke stroke) {
    final label = stroke.stampLabel!;
    final cx = (stroke.points.first.dx * dest.width).round();
    final cy = (stroke.points.first.dy * dest.height).round();
    final color = img.ColorRgba8(
      (stroke.color.r * 255).round(),
      (stroke.color.g * 255).round(),
      (stroke.color.b * 255).round(),
      (stroke.color.a * 255).round(),
    );

    final boxW = (dest.width * 0.42).round().clamp(80, dest.width);
    final boxH = (boxW * 0.28).round().clamp(36, dest.height);
    final left = (cx - boxW ~/ 2).clamp(0, dest.width - boxW);
    final top = (cy - boxH ~/ 2).clamp(0, dest.height - boxH);

    img.drawRect(dest,
        x1: left, y1: top, x2: left + boxW, y2: top + boxH, color: color);
    img.drawRect(dest,
        x1: left + 3,
        y1: top + 3,
        x2: left + boxW - 3,
        y2: top + boxH - 3,
        color: color);

    final font = img.arial48;
    var textW = 0;
    for (final code in label.codeUnits) {
      final ch = font.characters[code];
      if (ch != null) textW += ch.xAdvance;
    }
    final textH = font.lineHeight;
    final tx = (left + (boxW - textW) / 2).round();
    final ty = (top + (boxH - textH) / 2).round();
    img.drawString(dest, label, font: font, x: tx, y: ty, color: color);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_pdfFile != null
            ? 'Annotate  p. $_currentPage/$_pageCount'
            : 'Annotate PDF'),
        actions: [
          if (_pdfFile != null) ...[
            if (_currentPage > 1)
              IconButton(
                icon: const Icon(Icons.navigate_before),
                onPressed: () {
                  setState(() {
                    _currentPage--;
                    _currentPoints = [];
                  });
                  _loadPageImage();
                },
              ),
            if (_currentPage < _pageCount)
              IconButton(
                icon: const Icon(Icons.navigate_next),
                onPressed: () {
                  setState(() {
                    _currentPage++;
                    _currentPoints = [];
                  });
                  _loadPageImage();
                },
              ),
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save annotated PDF',
              onPressed: _isProcessing ? null : _save,
            ),
          ],
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                      value: _total > 0 ? _progress / _total : null),
                  const SizedBox(height: 16),
                  Text('Saving page $_progress of $_total…',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : Column(
              children: [
                _buildToolBar(cs),
                Expanded(
                  child: _pdfFile == null
                      ? Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.folder_open_outlined),
                            label: const Text('Pick a PDF to annotate'),
                            onPressed: _pickPdf,
                          ),
                        )
                      : _loadingPage
                          ? const Center(child: CircularProgressIndicator())
                          : _pageImage == null
                              ? const Center(
                                  child: Text('Could not render page'))
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    _canvasSize = Size(
                                      constraints.maxWidth,
                                      constraints.maxHeight,
                                    );
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.memory(
                                          _pageImage!,
                                          fit: BoxFit.fill,
                                          gaplessPlayback: true,
                                        ),
                                        GestureDetector(
                                          onPanStart: (d) => setState(() =>
                                              _currentPoints = [
                                                _normalize(d.localPosition)
                                              ]),
                                          onPanUpdate: (d) => setState(() =>
                                              _currentPoints.add(
                                                  _normalize(d.localPosition))),
                                          onPanEnd: (_) {
                                            if (_currentPoints.isNotEmpty) {
                                              _currentAnnotations.add(_Stroke(
                                                points:
                                                    List.from(_currentPoints),
                                                color: _toolColor,
                                                width: _toolWidth,
                                                isEraser: _selectedTool ==
                                                    _Tool.eraser,
                                              ));
                                              setState(
                                                  () => _currentPoints = []);
                                            }
                                          },
                                          child: CustomPaint(
                                            painter: _AnnotationPainter(
                                              strokes: _currentAnnotations,
                                              currentPoints: _currentPoints,
                                              currentColor: _toolColor,
                                              currentWidth: _toolWidth,
                                              isEraser: _selectedTool ==
                                                  _Tool.eraser,
                                            ),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                ),
              ],
            ),
    );
  }

  Widget _buildToolBar(ColorScheme cs) {
    return Container(
      height: 52,
      color: cs.surfaceContainerHighest,
      child: Row(
        children: [
          _ToolBtn(
            icon: Icons.edit,
            label: 'Pen',
            selected: _selectedTool == _Tool.pen,
            onTap: () => setState(() => _selectedTool = _Tool.pen),
          ),
          _ToolBtn(
            icon: Icons.highlight,
            label: 'Highlight',
            selected: _selectedTool == _Tool.highlighter,
            onTap: () => setState(() => _selectedTool = _Tool.highlighter),
          ),
          _ToolBtn(
            icon: Icons.auto_fix_high,
            label: 'Erase',
            selected: _selectedTool == _Tool.eraser,
            onTap: () => setState(() => _selectedTool = _Tool.eraser),
          ),
          const VerticalDivider(width: 12),
          ...[Colors.red, Colors.blue, Colors.black, Colors.green].map(
            (c) => GestureDetector(
              onTap: () => setState(() => _penColor = c),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: _penColor == c
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
              ),
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Insert stamp',
            icon: const Icon(Icons.approval_outlined, size: 20),
            onSelected: _addStamp,
            itemBuilder: (_) => _stamps
                .map((s) => PopupMenuItem(value: s, child: Text(s)))
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.undo, size: 20),
            tooltip: 'Undo last stroke',
            onPressed: _currentAnnotations.isNotEmpty
                ? () => setState(() => _currentAnnotations.removeLast())
                : null,
          ),
        ],
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: selected
            ? BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: cs.primary, width: 2)))
            : null,
        child: Icon(icon,
            size: 20, color: selected ? cs.primary : cs.onSurfaceVariant),
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;
  final bool isEraser;

  const _AnnotationPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
    required this.isEraser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    void paintStroke(_Stroke stroke) {
      if (stroke.isStamp) {
        _paintStamp(canvas, size, stroke);
        return;
      }
      if (stroke.points.length < 2) return;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..blendMode =
            stroke.isEraser ? BlendMode.clear : BlendMode.srcOver;
      final path = Path()
        ..moveTo(
          stroke.points.first.dx * size.width,
          stroke.points.first.dy * size.height,
        );
      for (final p in stroke.points.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }

    // Eraser needs a layer so BlendMode.clear works against page content.
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final s in strokes) {
      paintStroke(s);
    }
    if (currentPoints.length >= 2) {
      paintStroke(_Stroke(
        points: currentPoints,
        color: currentColor,
        width: currentWidth,
        isEraser: isEraser,
      ));
    }
    canvas.restore();
  }

  void _paintStamp(Canvas canvas, Size size, _Stroke stroke) {
    final label = stroke.stampLabel!;
    final center = Offset(
      stroke.points.first.dx * size.width,
      stroke.points.first.dy * size.height,
    );
    final boxW = size.width * 0.42;
    final boxH = boxW * 0.28;
    final rect = Rect.fromCenter(center: center, width: boxW, height: boxH);
    final border = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      border,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          rect.deflate(4), const Radius.circular(2)),
      border,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: stroke.color,
          fontSize: boxH * 0.38,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: boxW);
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) => true;
}
