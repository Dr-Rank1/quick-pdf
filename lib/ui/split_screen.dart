import 'package:quick_pdf/services/error_logger.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf_render_maintained/pdf_render.dart';
import 'package:quick_pdf/services/share_service.dart';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/tool_success_service.dart';
import 'package:quick_pdf/router/app_navigation.dart';

enum _SplitMode { allPages, range }

enum _SplitState { idle, splitting, done, error }

class SplitScreen extends StatefulWidget {
  final File file;
  const SplitScreen({super.key, required this.file});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  int? _pageCount;
  Uint8List? _thumbnail;
  _SplitMode _mode = _SplitMode.allPages;
  _SplitState _state = _SplitState.idle;

  int _fromPage = 1;
  int _toPage = 1;

  List<File> _results = [];
  int _progress = 0;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      final page = await doc.getPage(1);
      final rendered = await page.render(width: 140, height: 180);
      final uiImage = await rendered.createImageIfNotAvailable();
      final bd = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final count = doc.pageCount;
      await doc.dispose();
      if (mounted) {
        setState(() {
          _pageCount = count;
          _thumbnail = bd?.buffer.asUint8List();
          _toPage = count;
        });
      }
    } catch (_) {}
  }

  Future<void> _split() async {
    final count = _pageCount;
    if (count == null) return;

    final List<int> pages;
    if (_mode == _SplitMode.allPages) {
      pages = List.generate(count, (i) => i + 1);
    } else {
      final from = _fromPage.clamp(1, count);
      final to = _toPage.clamp(from, count);
      pages = List.generate(to - from + 1, (i) => from + i);
    }

    setState(() {
      _state = _SplitState.splitting;
      _progress = 0;
      _results = [];
    });

    try {
      final List<File> out = await PDFManager.splitPDF(
        widget.file,
        pages: pages,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      for (final f in out) {
        final thumbPath = await PDFManager.generateThumbnail(f.path);
        await DocumentDatabase().insertDocument(f.path, thumbnailPath: thumbPath);
      }

      PDFManager.hapticFeedbackSuccess();
      await ToolSuccessService.onMajorOperationComplete();
      if (mounted) {
        setState(() {
          _state = _SplitState.done;
          _results = out;
        });
      }
    } catch (e, stack) {
      await ErrorLogger.log('split', e, stack);
      PDFManager.hapticFeedbackError();
      if (mounted) {
        setState(() {
          _state = _SplitState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Split PDF')),
      body: switch (_state) {
        _SplitState.idle => _buildIdle(),
        _SplitState.splitting => _buildSplitting(),
        _SplitState.done => _buildDone(),
        _SplitState.error => _buildError(),
      },
    );
  }

  // ─── Idle ──────────────────────────────────────────────────────────────────

  Widget _buildIdle() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildInfoCard(),
              const SizedBox(height: 12),
              _buildModeSection(),
              if (_mode == _SplitMode.range && (_pageCount ?? 0) > 1) ...[
                const SizedBox(height: 12),
                _buildRangeCard(),
              ],
            ],
          ),
        ),
        _buildSplitBar(),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 56,
                height: 72,
                child: _thumbnail != null
                    ? Image.memory(_thumbnail!, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[100],
                        child: const Icon(Icons.picture_as_pdf,
                            color: Colors.red, size: 32),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName(widget.file.path),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.layers, size: 13, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _pageCount != null ? '$_pageCount pages' : 'Loading…',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.storage, size: 13, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _fmtSize(widget.file.lengthSync()),
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Split mode',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey[700])),
        ),
        Card(
          child: RadioGroup<_SplitMode>(
            groupValue: _mode,
            onChanged: (v) {
              if (v == _SplitMode.range &&
                  (_pageCount == null || _pageCount! <= 1)) {
                return;
              }
              setState(() => _mode = v!);
            },
            child: Column(
              children: [
                RadioListTile<_SplitMode>(
                  value: _SplitMode.allPages,
                  title: const Text('Split into individual pages'),
                  subtitle: Text(
                    _pageCount != null
                        ? 'Creates $_pageCount separate PDF files'
                        : 'Creates one file per page',
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const RadioListTile<_SplitMode>(
                  value: _SplitMode.range,
                  title: Text('Extract page range'),
                  subtitle: Text(
                      'Extract a consecutive range as individual pages'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRangeCard() {
    final max = _pageCount!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('From page',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text('Page $_fromPage',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
            Slider(
              value: _fromPage.toDouble(),
              min: 1,
              max: max.toDouble(),
              divisions: max > 1 ? max - 1 : 1,
              label: '$_fromPage',
              onChanged: (v) {
                final val = v.round();
                setState(() {
                  _fromPage = val;
                  if (_toPage < val) _toPage = val;
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('To page',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text('Page $_toPage',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
            Slider(
              value: _toPage.toDouble(),
              min: 1,
              max: max.toDouble(),
              divisions: max > 1 ? max - 1 : 1,
              label: '$_toPage',
              onChanged: (v) {
                final val = v.round();
                setState(() {
                  _toPage = val;
                  if (_fromPage > val) _fromPage = val;
                });
              },
            ),
            Text(
              '${_toPage - _fromPage + 1} page${_toPage - _fromPage + 1 == 1 ? '' : 's'} will be extracted as ${_toPage - _fromPage + 1} separate PDF${_toPage - _fromPage + 1 == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitBar() {
    final count = _pageCount;
    final splitCount = _mode == _SplitMode.allPages
        ? count
        : (count != null ? (_toPage - _fromPage + 1) : null);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: count != null ? _split : null,
            icon: const Icon(Icons.call_split),
            label: Text(
              splitCount != null
                  ? 'Split into $splitCount PDF file${splitCount == 1 ? '' : 's'}'
                  : 'Loading…',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Splitting ─────────────────────────────────────────────────────────────

  Widget _buildSplitting() {
    final total = _mode == _SplitMode.allPages
        ? (_pageCount ?? 0)
        : (_toPage - _fromPage + 1);
    final pct = total > 0 ? _progress / total : null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: pct),
          const SizedBox(height: 20),
          Text(
            total > 0
                ? 'Creating file $_progress of $total…'
                : 'Splitting…',
            style: const TextStyle(fontSize: 16),
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: pct,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Done ──────────────────────────────────────────────────────────────────

  Widget _buildDone() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 72, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            '${_results.length} PDF file${_results.length == 1 ? '' : 's'} created',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _results.isNotEmpty ? _results.first.parent.path : '',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Open first file (single page split)
          if (_results.length == 1)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    context.replaceWithPdfViewer(_results.first.path),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open PDF'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
              ),
            ),

          // Share all
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => ShareService.files(
                _results.map((f) => XFile(f.path)).toList(),
                subject: 'Split PDF from QuickPDF',
              ),
              icon: const Icon(Icons.share),
              label: Text(
                  'Share all ${_results.length} file${_results.length == 1 ? '' : 's'}'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ─── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Split failed',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  setState(() { _state = _SplitState.idle; _results = []; }),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}
