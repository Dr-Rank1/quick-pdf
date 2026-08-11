import 'dart:io';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:flutter/material.dart';
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/file_picker_service.dart';

enum _BatchOp { compress, watermark }

enum _ItemStatus { pending, processing, done, error }

class _BatchItem {
  final File file;
  _ItemStatus status = _ItemStatus.pending;
  String? error;
  _BatchItem(this.file);
  String get name => fileName(file.path);
}

class BatchScreen extends StatefulWidget {
  const BatchScreen({super.key});

  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  final List<_BatchItem> _items = [];
  _BatchOp _op = _BatchOp.compress;
  bool _running = false;

  // Compress opts
  int _quality = 65;
  // Watermark opts
  final _watermarkCtrl = TextEditingController(text: 'DRAFT');

  @override
  void dispose() {
    _watermarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final files = await FilePickerService.pickMultipleFiles(
        allowedExtensions: ['pdf']);
    if (files == null || files.isEmpty) return;
    setState(() {
      for (final f in files) {
        if (!_items.any((i) => i.file.path == f.path)) {
          _items.add(_BatchItem(f));
        }
      }
    });
  }

  Future<void> _run() async {
    if (_items.isEmpty) {
      _snack('Add files first.');
      return;
    }
    if (_running) return;

    setState(() => _running = true);
    try {
      await AdService().showRewardedOrFallback(onRewarded: () async {
        final db = DocumentDatabase();
        for (int i = 0; i < _items.length; i++) {
          if (!mounted) break;
          setState(() => _items[i].status = _ItemStatus.processing);
          try {
            File out;
            switch (_op) {
              case _BatchOp.compress:
                out = await PDFManager.compressPDF(
                    _items[i].file, imageQuality: _quality);
                break;
              case _BatchOp.watermark:
                out = await PDFManager.addWatermark(
                  _items[i].file,
                  text: _watermarkCtrl.text.trim().isEmpty
                      ? 'DRAFT'
                      : _watermarkCtrl.text.trim(),
                  opacity: 0.25,
                );
                break;
            }
            final thumbPath = await PDFManager.generateThumbnail(out.path);
            await db.insertDocument(out.path, thumbnailPath: thumbPath);
            if (mounted) setState(() => _items[i].status = _ItemStatus.done);
          } catch (e) {
            if (mounted) {
              setState(() {
                _items[i].status = _ItemStatus.error;
                _items[i].error = e.toString();
              });
            }
          }
        }
        if (mounted) {
          await AdService().recordToolCompletion();
          _snack('Batch complete');
        }
      });
    } finally {
      if (mounted) setState(() => _running = false);
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
        title: const Text('Batch Processing'),
        actions: [
          if (!_running && _items.isNotEmpty)
            TextButton(
              onPressed: _run,
              child: const Text('Run'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Operation selector ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Operation',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                SegmentedButton<_BatchOp>(
                  segments: const [
                    ButtonSegment(
                        value: _BatchOp.compress,
                        icon: Icon(Icons.compress),
                        label: Text('Compress')),
                    ButtonSegment(
                        value: _BatchOp.watermark,
                        icon: Icon(Icons.water_drop_outlined),
                        label: Text('Watermark')),
                  ],
                  selected: {_op},
                  onSelectionChanged: (s) =>
                      setState(() => _op = s.first),
                ),
              ],
            ),
          ),

          // ── Op options ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _op == _BatchOp.compress
                ? Row(
                    children: [
                      const Text('Quality:', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: _quality.toDouble(),
                          min: 30,
                          max: 95,
                          divisions: 13,
                          label: '$_quality%',
                          onChanged: (v) =>
                              setState(() => _quality = v.round()),
                        ),
                      ),
                      Text('$_quality%',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  )
                : TextField(
                    controller: _watermarkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Watermark text',
                      isDense: true,
                    ),
                  ),
          ),

          const Divider(height: 16),

          // ── File list ──
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.playlist_add,
                            size: 56, color: cs.outlineVariant),
                        const SizedBox(height: 12),
                        Text('No files added',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      return ListTile(
                        leading: _statusIcon(item.status, cs),
                        title: Text(item.name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                        subtitle: item.error != null
                            ? Text(item.error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 11))
                            : Text(
                                _statusLabel(item.status),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant),
                              ),
                        trailing: _running
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(
                                    () => _items.removeAt(i)),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _running ? null : _pickFiles,
        tooltip: 'Add PDFs',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _statusIcon(_ItemStatus s, ColorScheme cs) {
    switch (s) {
      case _ItemStatus.pending:
        return Icon(Icons.schedule, color: cs.onSurfaceVariant, size: 20);
      case _ItemStatus.processing:
        return const SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
      case _ItemStatus.done:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case _ItemStatus.error:
        return const Icon(Icons.error_outline, color: Colors.red, size: 20);
    }
  }

  String _statusLabel(_ItemStatus s) {
    switch (s) {
      case _ItemStatus.pending: return 'Pending';
      case _ItemStatus.processing: return 'Processing…';
      case _ItemStatus.done: return 'Done';
      case _ItemStatus.error: return 'Error';
    }
  }
}
