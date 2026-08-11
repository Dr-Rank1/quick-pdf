import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_render_maintained/pdf_render.dart' as render;
import 'package:image/image.dart' as img;
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/file_picker_service.dart';

class SignPdfScreen extends StatefulWidget {
  const SignPdfScreen({super.key});

  @override
  State<SignPdfScreen> createState() => _SignPdfScreenState();
}

class _SignPdfScreenState extends State<SignPdfScreen> {
  // Steps: 0 = draw signature, 1 = place on page
  int _step = 0;

  File? _pdfFile;
  int _pdfPageCount = 0;
  int _targetPage = 1;

  // Signature drawing
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  Uint8List? _signatureBytes; // PNG of drawn signature

  // Placement
  Offset _sigPosition = const Offset(0.3, 0.7); // fraction of page
  double _sigScale = 0.3;
  Uint8List? _pagePreviewBytes;
  bool _loadingPreview = false;

  bool _isProcessing = false;
  bool _isSaving = false;

  // Saved signature path
  static const String _savedSigFilename = 'quickpdf_saved_signature.png';
  Uint8List? _savedSig;

  @override
  void initState() {
    super.initState();
    _loadSavedSig();
  }

  Future<void> _loadSavedSig() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_savedSigFilename');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => _savedSig = bytes);
      }
    } catch (_) {}
  }

  Future<void> _saveSig(Uint8List bytes) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/$_savedSigFilename').writeAsBytes(bytes);
      if (mounted) setState(() => _savedSig = bytes);
    } catch (_) {}
  }

  Future<void> _pickPdf() async {
    final files = await FilePickerService.pickMultipleFiles(
        allowedExtensions: ['pdf']);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() {
      _pdfFile = files.first;
      _pagePreviewBytes = null;
    });
    final count = await PDFManager.getPageCount(_pdfFile!.path);
    if (!mounted) return;
    setState(() {
      _pdfPageCount = count;
      _targetPage = 1;
    });
    _loadPagePreview();
  }

  Future<void> _loadPagePreview() async {
    if (_pdfFile == null) return;
    setState(() => _loadingPreview = true);
    try {
      final doc = await render.PdfDocument.openFile(_pdfFile!.path);
      try {
        final page = await doc.getPage(_targetPage);
        final rendered = await page.render(width: 400);
        try {
          final uiImage = await rendered.createImageIfNotAvailable();
          final bd =
              await uiImage.toByteData(format: ui.ImageByteFormat.png);
          uiImage.dispose();
          if (mounted && bd != null) {
            setState(() => _pagePreviewBytes = bd.buffer.asUint8List());
          }
        } finally {
          rendered.dispose();
        }
      } finally {
        await doc.dispose();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPreview = false);
  }

  // ── Signature canvas ─────────────────────────────────────────────────────

  Future<Uint8List?> _renderSignature(Size canvasSize) async {
    if (_strokes.isEmpty) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder,
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        Paint()..color = Colors.transparent);
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
        canvasSize.width.round(), canvasSize.height.round());
    final bd =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bd?.buffer.asUint8List();
  }

  // ── Save signed PDF ───────────────────────────────────────────────────────

  Future<void> _applySig() async {
    final file = _pdfFile;
    final sigBytes = _signatureBytes ?? _savedSig;
    if (file == null || sigBytes == null) {
      _snack('Pick a PDF and draw or load a signature first.');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await AdService().showRewardedOrFallback(
        onRewarded: () async {
          await _doApplySig(file, sigBytes);
        },
      );
    } catch (e) {
      if (mounted) _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _doApplySig(File pdfFile, Uint8List sigBytes) async {
    if (mounted) setState(() => _isSaving = true);
    try {
      final Uint8List pdfBytes = await pdfFile.readAsBytes();
      final source = await render.PdfDocument.openData(pdfBytes);
      final target = pw.Document(compress: true);

      try {
        for (int i = 1; i <= source.pageCount; i++) {
          final page = await source.getPage(i);
          final pageImage = await page.render(
            width: (page.width * 1.5).round().clamp(72, 1600),
            height: (page.height * 1.5).round().clamp(72, 1600),
          );
          late final Uint8List encoded;
          try {
            final pixels = Uint8List.fromList(pageImage.pixels);
            final image = img.Image.fromBytes(
              width: pageImage.width,
              height: pageImage.height,
              bytes: pixels.buffer,
              format: img.Format.uint8,
              numChannels: 4,
              order: img.ChannelOrder.rgba,
            );
            encoded = Uint8List.fromList(img.encodeJpg(image, quality: 85));
          } finally {
            pageImage.dispose();
          }
          await Future.delayed(Duration.zero);

          target.addPage(pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height),
            margin: pw.EdgeInsets.zero,
            build: (_) {
              // Match placement preview: position is the center of the signature
              // in top-left Flutter / pdf package coordinates (no Y flip).
              final sigW = page.width * _sigScale;
              final sigH = sigW * 0.5;
              final sigX = page.width * _sigPosition.dx - sigW / 2;
              final sigY = page.height * _sigPosition.dy - sigH / 2;
              return pw.Stack(
                children: [
                  pw.Image(pw.MemoryImage(encoded)),
                  if (i == _targetPage)
                    pw.Positioned(
                      left: sigX,
                      top: sigY,
                      child: pw.SizedBox(
                        width: sigW,
                        height: sigH,
                        child: pw.Image(pw.MemoryImage(sigBytes)),
                      ),
                    ),
                ],
              );
            },
          ));
          await Future.delayed(Duration.zero);
        }
      } finally {
        await source.dispose();
      }

      final dir = await getApplicationDocumentsDirectory();
      final out = File(
          '${dir.path}/Signed_QuickPDF_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await out.writeAsBytes(await target.save());

      final thumbPath = await PDFManager.generateThumbnail(out.path);
      await DocumentDatabase()
          .insertDocument(out.path, thumbnailPath: thumbPath);
      PDFManager.hapticFeedbackSuccess();
      if (mounted) {
        _snack('Signed: ${fileName(out.path)}');
        Navigator.of(context).pop();
      }
    } catch (e) {
      PDFManager.hapticFeedbackError();
      if (mounted) _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 0 ? 'Draw Signature' : 'Place Signature'),
        actions: [
          if (_step == 0 && _strokes.isNotEmpty)
            TextButton(
              onPressed: () async {
                final bytes =
                    await _renderSignature(const Size(400, 150));
                if (bytes != null) {
                  await _saveSig(bytes);
                  setState(() {
                    _signatureBytes = bytes;
                    _step = 1;
                  });
                  if (_pdfFile == null) _pickPdf();
                }
              },
              child: const Text('Use'),
            ),
          if (_step == 1)
            TextButton(
              onPressed: (_isProcessing || _isSaving) ? null : _applySig,
              child: const Text('Save'),
            ),
        ],
      ),
      body: _isProcessing || _isSaving
          ? const Center(child: CircularProgressIndicator())
          : _step == 0
              ? _buildDrawStep()
              : _buildPlaceStep(),
    );
  }

  Widget _buildDrawStep() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Saved sig
        if (_savedSig != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text('Saved signature:',
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 12)),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: Image.memory(_savedSig!, fit: BoxFit.contain),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _signatureBytes = _savedSig;
                      _step = 1;
                    });
                    if (_pdfFile == null) _pickPdf();
                  },
                  child: const Text('Use saved'),
                ),
              ],
            ),
          ),

        // Drawing canvas
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: GestureDetector(
                      onPanStart: (d) => setState(
                          () => _currentStroke = [d.localPosition]),
                      onPanUpdate: (d) => setState(
                          () => _currentStroke.add(d.localPosition)),
                      onPanEnd: (_) {
                        if (_currentStroke.isNotEmpty) {
                          setState(() {
                            _strokes.add(List.from(_currentStroke));
                            _currentStroke = [];
                          });
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CustomPaint(
                          painter: _SignaturePainter(
                              _strokes, _currentStroke),
                          child: Container(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      onPressed: () =>
                          setState(() { _strokes.clear(); _currentStroke = []; }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceStep() {
    final cs = Theme.of(context).colorScheme;
    final sigBytes = _signatureBytes ?? _savedSig;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // PDF selector
        Card(
          child: ListTile(
            onTap: _pickPdf,
            leading: Icon(Icons.picture_as_pdf, color: cs.error),
            title: Text(
              _pdfFile != null
                  ? fileName(_pdfFile!.path)
                  : 'Tap to pick a PDF',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color:
                      _pdfFile != null ? null : cs.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.folder_open_outlined),
          ),
        ),
        const SizedBox(height: 12),

        // Page selection
        if (_pdfPageCount > 1)
          Row(
            children: [
              const Text('Sign page: ', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _targetPage,
                items: List.generate(_pdfPageCount,
                    (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1}'),
                        )),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _targetPage = v);
                  _loadPagePreview();
                },
              ),
            ],
          ),

        // Preview with draggable signature
        if (_pdfFile != null && sigBytes != null) ...[
          const SizedBox(height: 12),
          Text('Drag to position',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 0.7,
            child: Stack(
              children: [
                _loadingPreview
                    ? const Center(child: CircularProgressIndicator())
                    : _pagePreviewBytes != null
                        ? Image.memory(_pagePreviewBytes!,
                            fit: BoxFit.contain)
                        : Container(color: cs.surfaceContainerHighest),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final x = _sigPosition.dx * constraints.maxWidth;
                      final y = _sigPosition.dy * constraints.maxHeight;
                      final sigW = _sigScale * constraints.maxWidth;
                      return GestureDetector(
                        onPanUpdate: (d) {
                          setState(() {
                            _sigPosition = Offset(
                              (_sigPosition.dx +
                                      d.delta.dx /
                                          constraints.maxWidth)
                                  .clamp(0.0, 1.0),
                              (_sigPosition.dy +
                                      d.delta.dy /
                                          constraints.maxHeight)
                                  .clamp(0.0, 1.0),
                            );
                          });
                        },
                        child: Stack(
                          children: [
                            Positioned(
                              left: x - sigW / 2,
                              top: y - sigW * 0.25,
                              child: SizedBox(
                                width: sigW,
                                child: Image.memory(sigBytes,
                                    fit: BoxFit.contain),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _SliderRow2(
            label: 'Size',
            value: _sigScale,
            min: 0.1,
            max: 0.6,
            displayText:
                '${(_sigScale * 100).round()}%',
            onChanged: (v) => setState(() => _sigScale = v),
          ),
        ],
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> current;
  _SignaturePainter(this.strokes, this.current);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in [...strokes, current]) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}

class _SliderRow2 extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayText;
  final ValueChanged<double> onChanged;

  const _SliderRow2({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        Expanded(
          child: Slider(
              value: value, min: min, max: max, onChanged: onChanged),
        ),
        SizedBox(
          width: 40,
          child: Text(displayText,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
