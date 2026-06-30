import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render_maintained/pdf_render.dart';
import 'package:quick_pdf/services/share_service.dart';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:quick_pdf/router/app_navigation.dart';
import 'package:quick_pdf/services/file_picker_service.dart';

// ─── Entry hub ───────────────────────────────────────────────────────────────

class FormatConverterScreen extends StatelessWidget {
  const FormatConverterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Format Converter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(context, 'Convert to PDF'),
          const SizedBox(height: 8),
          _ConvCard(
            icon: Icons.image,
            iconColor: Colors.green.shade600,
            title: 'Images → PDF',
            subtitle: 'Combine JPG, PNG, WEBP photos into one PDF',
            onTap: () async {
              final result = await FilePickerService.pickMultipleFiles(
                allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
              );
              if (result == null || result.isEmpty || !context.mounted) return;
              context.pushConvert(result);
            },
          ),
          const SizedBox(height: 20),
          _sectionHeader(context, 'Export from PDF'),
          const SizedBox(height: 8),
          _ConvCard(
            icon: Icons.photo_outlined,
            iconColor: Colors.orange.shade700,
            title: 'PDF → JPEG Images',
            subtitle: 'Export each page as a JPEG photo (smaller files)',
            onTap: () => _pickAndExport(context, 'jpeg'),
          ),
          const SizedBox(height: 10),
          _ConvCard(
            icon: Icons.image_outlined,
            iconColor: Colors.blue.shade600,
            title: 'PDF → PNG Images',
            subtitle: 'Export each page as a lossless PNG',
            onTap: () => _pickAndExport(context, 'png'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Text(text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant));
  }

  Future<void> _pickAndExport(BuildContext context, String format) async {
    final result = await FilePickerService.pickMultipleFiles(
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.isEmpty || !context.mounted) return;

    await context.pushPdfExport(result.first, format);
  }
}

// ─── Option card ─────────────────────────────────────────────────────────────

class _ConvCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ConvCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing:
            Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}

// ─── PDF → Image export screen ───────────────────────────────────────────────

enum _ExportState { idle, exporting, done, error }

class PdfExportScreen extends StatefulWidget {
  final File file;
  final String format; // 'jpeg' or 'png'

  const PdfExportScreen({super.key, required this.file, required this.format});

  @override
  State<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends State<PdfExportScreen> {
  int? _pageCount;
  int _quality = 85;
  _ExportState _state = _ExportState.idle;
  int _progressPage = 0;
  int _progressTotal = 0;
  List<File> _exported = [];
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      final count = doc.pageCount;
      await doc.dispose();
      if (mounted) setState(() => _pageCount = count);
    } catch (_) {}
  }

  Future<void> _export() async {
    setState(() {
      _state = _ExportState.exporting;
      _progressPage = 0;
      _progressTotal = _pageCount ?? 0;
      _exported = [];
    });

    final doc = await PdfDocument.openFile(widget.file.path);
    try {
      final total = doc.pageCount;
      final dir = await getApplicationDocumentsDirectory();
      final base =
          fileStem(widget.file.path);
      final List<File> out = [];

      for (int i = 1; i <= total; i++) {
        if (mounted) setState(() { _progressPage = i; _progressTotal = total; });

        final page = await doc.getPage(i);
        final rw = (page.width * 2).round();
        final rh = (page.height * 2).round();
        final rendered = await page.render(width: rw, height: rh);

        await Future.delayed(Duration.zero);

        final rawImg = img.Image.fromBytes(
          width: rendered.width,
          height: rendered.height,
          bytes: rendered.pixels.buffer,
          format: img.Format.uint8,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );

        final Uint8List encoded = widget.format == 'png'
            ? Uint8List.fromList(img.encodePng(rawImg))
            : Uint8List.fromList(img.encodeJpg(rawImg, quality: _quality));

        final pageStr = i.toString().padLeft(total.toString().length, '0');
        final outPath = '${dir.path}/${base}_p$pageStr.${widget.format}';
        await File(outPath).writeAsBytes(encoded);
        out.add(File(outPath));

        await Future.delayed(Duration.zero);
      }

      if (mounted) {
        setState(() {
          _state = _ExportState.done;
          _exported = out;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ExportState.error;
          _errorMsg = e.toString();
        });
      }
    } finally {
      await doc.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.format.toUpperCase();
    return Scaffold(
      appBar: AppBar(title: Text('Export as $label')),
      body: switch (_state) {
        _ExportState.idle      => _buildIdle(label),
        _ExportState.exporting => _buildExporting(),
        _ExportState.done      => _buildDone(label),
        _ExportState.error     => _buildError(),
      },
    );
  }

  Widget _buildIdle(String label) {
    final isPng = widget.format == 'png';
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(fileName(widget.file.path),
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(_pageCount != null
                      ? '$_pageCount pages'
                      : 'Loading…'),
                ),
              ),
              const SizedBox(height: 16),
              if (!isPng) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('JPEG quality',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            Text('$_quality%',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary)),
                          ],
                        ),
                        Slider(
                          value: _quality.toDouble(),
                          min: 30,
                          max: 95,
                          divisions: 65,
                          label: '$_quality%',
                          onChanged: (v) =>
                              setState(() => _quality = v.round()),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Smaller',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500])),
                            Text('Sharper',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PNG is lossless — full quality, larger files.',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _pageCount != null ? _export : null,
                icon: const Icon(Icons.download),
                label: Text(
                  _pageCount != null
                      ? 'Export $_pageCount page${_pageCount == 1 ? '' : 's'} as $label'
                      : 'Loading…',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExporting() {
    final pct = _progressTotal > 0
        ? _progressPage / _progressTotal
        : null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: pct),
          const SizedBox(height: 20),
          Text(
            _progressTotal > 0
                ? 'Exporting page $_progressPage of $_progressTotal…'
                : 'Exporting…',
            style: const TextStyle(fontSize: 15),
          ),
          if (_progressTotal > 0) ...[
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

  Widget _buildDone(String label) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 72),
          const SizedBox(height: 16),
          Text('${_exported.length} $label file${_exported.length == 1 ? '' : 's'} exported',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _exported.isNotEmpty
                ? _exported.first.parent.path
                : '',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => ShareService.files(
                _exported.map((f) => XFile(f.path)).toList(),
                subject: 'Exported from QuickPDF',
              ),
              icon: const Icon(Icons.share),
              label: Text('Share all ${_exported.length} file${_exported.length == 1 ? '' : 's'}'),
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

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('Export failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMsg,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() => _state = _ExportState.idle),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
