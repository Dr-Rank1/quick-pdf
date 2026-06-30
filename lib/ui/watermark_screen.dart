import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf_render_maintained/pdf_render.dart' as render;
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/file_picker_service.dart';

class WatermarkScreen extends StatefulWidget {
  final File? initialFile;
  const WatermarkScreen({super.key, this.initialFile});

  @override
  State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  File? _file;
  bool _isProcessing = false;
  int _progress = 0;
  int _total = 0;

  final _textCtrl = TextEditingController(text: 'CONFIDENTIAL');
  double _opacity = 0.3;
  double _fontSize = 48;
  double _rotation = -30;

  // Preview thumbnail of page 1
  Uint8List? _previewBytes;
  bool _loadingPreview = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _file = widget.initialFile;
      _loadPreview();
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final files = await FilePickerService.pickMultipleFiles(
        allowedExtensions: ['pdf']);
    if (files == null || files.isEmpty) return;
    setState(() { _file = files.first; _previewBytes = null; });
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    if (_file == null) return;
    setState(() => _loadingPreview = true);
    try {
      final doc = await render.PdfDocument.openFile(_file!.path);
      final page = await doc.getPage(1);
      final rendered = await page.render(width: 300);
      final uiImage = await rendered.createImageIfNotAvailable();
      final bd = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();
      await doc.dispose();
      if (mounted && bd != null) {
        setState(() => _previewBytes = bd.buffer.asUint8List());
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPreview = false);
  }

  Future<void> _applyWatermark() async {
    final file = _file;
    final text = _textCtrl.text.trim();
    if (file == null || text.isEmpty) {
      _snack('Select a PDF and enter watermark text.');
      return;
    }

    setState(() { _isProcessing = true; _progress = 0; _total = 0; });

    try {
      final out = await PDFManager.addWatermark(
        file,
        text: text,
        opacity: _opacity,
        fontSize: _fontSize,
        rotationDegrees: _rotation,
        onProgress: (c, t) {
          if (mounted) setState(() { _progress = c; _total = t; });
        },
      );
      final thumbPath = await PDFManager.generateThumbnail(out.path);
      await DocumentDatabase().insertDocument(out.path, thumbnailPath: thumbPath);
      PDFManager.hapticFeedbackSuccess();
      await AdService().recordToolCompletion();
      if (mounted) {
        _snack('Watermark applied: ${fileName(out.path)}');
        setState(() { _file = null; _previewBytes = null; });
      }
    } catch (e) {
      PDFManager.hapticFeedbackError();
      if (mounted) _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Watermark')),
      body: _isProcessing
          ? _buildProgress()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // File selector
                Card(
                  child: ListTile(
                    onTap: _pickFile,
                    leading: Icon(Icons.picture_as_pdf, color: cs.error),
                    title: Text(
                      _file != null
                          ? fileName(_file!.path)
                          : 'Tap to pick a PDF',
                      style: TextStyle(
                        fontWeight: _file != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color:
                            _file != null ? null : cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.folder_open_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Watermark text
                TextField(
                  controller: _textCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Watermark text',
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Opacity
                _SliderRow(
                  label: 'Opacity',
                  value: _opacity,
                  min: 0.1,
                  max: 0.9,
                  displayText: '${(_opacity * 100).round()}%',
                  onChanged: (v) => setState(() => _opacity = v),
                ),
                _SliderRow(
                  label: 'Font size',
                  value: _fontSize,
                  min: 16,
                  max: 96,
                  displayText: _fontSize.round().toString(),
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
                _SliderRow(
                  label: 'Rotation',
                  value: _rotation,
                  min: -90,
                  max: 90,
                  displayText: '${_rotation.round()}°',
                  onChanged: (v) => setState(() => _rotation = v),
                ),

                // Preview
                if (_file != null) ...[
                  const SizedBox(height: 16),
                  Text('Preview (page 1)',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 200,
                      child: _loadingPreview
                          ? const Center(child: CircularProgressIndicator())
                          : _previewBytes != null
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image.memory(_previewBytes!,
                                        fit: BoxFit.contain),
                                    Transform.rotate(
                                      angle: _rotation * 3.14159 / 180,
                                      child: Opacity(
                                        opacity: _opacity,
                                        child: Text(
                                          _textCtrl.text,
                                          style: TextStyle(
                                            fontSize: _fontSize * 0.35,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Center(child: Text('Preview unavailable')),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: (_file != null && _textCtrl.text.isNotEmpty)
                        ? _applyWatermark
                        : null,
                    icon: const Icon(Icons.water_drop_outlined),
                    label: const Text('Apply Watermark',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProgress() {
    final pct = _total > 0 ? _progress / _total : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: pct),
            const SizedBox(height: 20),
            if (_total > 0)
              Text('Processing page $_progress of $_total…',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayText;
  final ValueChanged<double> onChanged;

  const _SliderRow({
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
          width: 72,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
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
