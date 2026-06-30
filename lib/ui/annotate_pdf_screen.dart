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
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;
  const _Stroke(
      {required this.points,
      required this.color,
      required this.width,
      required this.isEraser});
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

  // Per-page annotations
  final Map<int, List<_Stroke>> _annotations = {};
  List<_Stroke> get _currentAnnotations =>
      _annotations[_currentPage] ??= [];

  List<Offset> _currentPoints = [];
  _Tool _selectedTool = _Tool.pen;
  Color _penColor = Colors.red;
  final double _penWidth = 3.0;

  Uint8List? _pageImage; // rendered current page
  bool _loadingPage = false;
  render.PdfDocument? _doc;

  bool _isProcessing = false;
  int _progress = 0;
  int _total = 0;

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
    setState(() { _loadingPage = true; _pageImage = null; });
    try {
      final page = await doc.getPage(_currentPage);
      final rendered = await page.render(width: _canvasRenderWidth.round());
      final uiImage = await rendered.createImageIfNotAvailable();
      final bd =
          await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();
      if (mounted && bd != null) {
        setState(() => _pageImage = bd.buffer.asUint8List());
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPage = false);
  }

  // ── Tool helpers ─────────────────────────────────────────────────────────

  Color get _toolColor {
    switch (_selectedTool) {
      case _Tool.pen: return _penColor;
      case _Tool.highlighter: return _penColor.withValues(alpha: 0.35);
      case _Tool.eraser: return Colors.white;
    }
  }

  double get _toolWidth {
    switch (_selectedTool) {
      case _Tool.pen: return _penWidth;
      case _Tool.highlighter: return 18;
      case _Tool.eraser: return 24;
    }
  }

  void _addStamp(String label) {
    // Place stamp at the centre of the page area as a fake stroke
    setState(() {
      _currentAnnotations.add(_Stroke(
        points: const [Offset(0.5, 0.5)], // normalised fraction
        color: Colors.red.withValues(alpha: 0.5),
        width: 0, // width=0 signals a stamp
        isEraser: false,
      ));
    });
  }

  // ── Flatten & save ────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_pdfFile == null) {
      _snack('No PDF loaded.');
      return;
    }
    setState(() { _isProcessing = true; _progress = 0; _total = _pageCount; });

    await AdService().showRewardedOrFallback(onRewarded: () async {
      try {
        final Uint8List pdfBytes = await _pdfFile!.readAsBytes();
        final source = await render.PdfDocument.openData(pdfBytes);
        final target = pw.Document(compress: true);

        for (int i = 1; i <= source.pageCount; i++) {
          if (mounted) setState(() => _progress = i);
          final page = await source.getPage(i);
          final pageImg = await page.render(
            width: (page.width * 2).round(),
            height: (page.height * 2).round(),
          );
          await Future.delayed(Duration.zero);

          // Start with the base page image
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
            final scale = pageImg.width / _canvasRenderWidth;
            _compositeStrokes(baseImg, strokes, scale);
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
        await source.dispose();

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
      } catch (e) {
        PDFManager.hapticFeedbackError();
        if (mounted) _snack('Save failed: $e');
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    });
  }

  void _compositeStrokes(img.Image dest, List<_Stroke> strokes, double scale) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;

      final color = stroke.isEraser
          ? img.ColorRgba8(255, 255, 255, 255)
          : img.ColorRgba8(
              (stroke.color.r * 255).round(),
              (stroke.color.g * 255).round(),
              (stroke.color.b * 255).round(),
              (stroke.color.a * 255).round(),
            );
      final thickness = (stroke.width * scale).round().clamp(1, 120);

      for (var j = 0; j < stroke.points.length - 1; j++) {
        img.drawLine(
          dest,
          x1: (stroke.points[j].dx * scale).round(),
          y1: (stroke.points[j].dy * scale).round(),
          x2: (stroke.points[j + 1].dx * scale).round(),
          y2: (stroke.points[j + 1].dy * scale).round(),
          color: color,
          thickness: thickness,
        );
      }
    }
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
                  setState(() { _currentPage--; _currentPoints = []; });
                  _loadPageImage();
                },
              ),
            if (_currentPage < _pageCount)
              IconButton(
                icon: const Icon(Icons.navigate_next),
                onPressed: () {
                  setState(() { _currentPage++; _currentPoints = []; });
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
                // ── Tool bar ──
                _buildToolBar(cs),

                // ── Canvas ──
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
                              ? const Center(child: Text('Could not render page'))
                              : GestureDetector(
                                  onPanStart: (d) => setState(
                                      () => _currentPoints = [d.localPosition]),
                                  onPanUpdate: (d) => setState(
                                      () => _currentPoints.add(d.localPosition)),
                                  onPanEnd: (_) {
                                    if (_currentPoints.isNotEmpty) {
                                      _currentAnnotations.add(_Stroke(
                                        points: List.from(_currentPoints),
                                        color: _toolColor,
                                        width: _toolWidth,
                                        isEraser:
                                            _selectedTool == _Tool.eraser,
                                      ));
                                      setState(() => _currentPoints = []);
                                    }
                                  },
                                  child: CustomPaint(
                                    painter: _AnnotationPainter(
                                      pageImage: _pageImage!,
                                      strokes: _currentAnnotations,
                                      currentPoints: _currentPoints,
                                      currentColor: _toolColor,
                                      currentWidth: _toolWidth,
                                      isEraser:
                                          _selectedTool == _Tool.eraser,
                                    ),
                                    child: Container(),
                                  ),
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
          // Tools
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
            onTap: () =>
                setState(() => _selectedTool = _Tool.highlighter),
          ),
          _ToolBtn(
            icon: Icons.auto_fix_high,
            label: 'Erase',
            selected: _selectedTool == _Tool.eraser,
            onTap: () => setState(() => _selectedTool = _Tool.eraser),
          ),
          const VerticalDivider(width: 12),
          // Color picker
          ...[Colors.red, Colors.blue, Colors.black, Colors.green]
              .map((c) => GestureDetector(
                    onTap: () => setState(() => _penColor = c),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: _penColor == c
                            ? Border.all(
                                color: Colors.white, width: 2)
                            : null,
                      ),
                    ),
                  )),
          const Spacer(),
          // Stamps
          PopupMenuButton<String>(
            tooltip: 'Insert stamp',
            icon: const Icon(Icons.approval_outlined, size: 20),
            onSelected: _addStamp,
            itemBuilder: (_) => _stamps
                .map((s) => PopupMenuItem(value: s, child: Text(s)))
                .toList(),
          ),
          // Undo
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
  const _ToolBtn(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: selected
            ? BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: cs.primary, width: 2)))
            : null,
        child: Icon(icon, size: 20,
            color: selected ? cs.primary : cs.onSurfaceVariant),
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final Uint8List pageImage;
  final List<_Stroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;
  final bool isEraser;

  const _AnnotationPainter({
    required this.pageImage,
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
    required this.isEraser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Page image is rendered by the widget; annotations drawn on top.

    void paintStroke(_Stroke stroke) {
      if (stroke.points.length < 2) return;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..blendMode =
            stroke.isEraser ? BlendMode.clear : BlendMode.srcOver;
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final p in stroke.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

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
  }

  @override
  bool shouldRepaint(_AnnotationPainter old) => true;
}
