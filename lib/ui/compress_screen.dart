import 'package:quick_pdf/services/error_logger.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:quick_pdf/utils/image_quality_prefs.dart';
import 'package:quick_pdf/services/share_service.dart';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/tool_success_service.dart';
import 'package:quick_pdf/router/app_navigation.dart';
import 'package:pdf_render_maintained/pdf_render.dart';

// ─── Preset definition ───────────────────────────────────────────────────────

class _Preset {
  final String label;
  final String sublabel;
  final String description;
  final int quality;
  final double renderScale;
  final Color color;
  final IconData icon;

  const _Preset({
    required this.label,
    required this.sublabel,
    required this.description,
    required this.quality,
    required this.renderScale,
    required this.color,
    required this.icon,
  });
}

const _presets = [
  _Preset(
    label: 'Maximum',
    sublabel: 'Smallest file',
    description: 'Best for email & messaging',
    quality: 42,
    renderScale: 0.75,
    color: Colors.red,
    icon: Icons.compress,
  ),
  _Preset(
    label: 'Balanced',
    sublabel: 'Recommended',
    description: 'Good quality, smaller size',
    quality: 65,
    renderScale: 1.0,
    color: Colors.orange,
    icon: Icons.tune,
  ),
  _Preset(
    label: 'High Quality',
    sublabel: 'Light compression',
    description: 'Near-original quality',
    quality: 82,
    renderScale: 1.25,
    color: Colors.green,
    icon: Icons.high_quality,
  ),
];

// ─── Screen ──────────────────────────────────────────────────────────────────

enum _State { idle, compressing, done, error }

class CompressScreen extends StatefulWidget {
  final File file;
  const CompressScreen({super.key, required this.file});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  // PDF info (loaded async)
  int? _pageCount;
  Uint8List? _thumbnail;

  // Settings
  int _presetIndex = 1; // Balanced by default
  bool _isCustom = false;
  int _customQuality = 65;

  // State machine
  _State _state = _State.idle;
  File? _resultFile;
  int _originalSize = 0;
  int _compressedSize = 0;
  String _errorMessage = '';
  int _progressPage = 0;
  int _progressTotal = 0;

  final TextEditingController _nameController = TextEditingController();

  int get _activeQuality =>
      _isCustom ? _customQuality : _presets[_presetIndex].quality;

  double get _activeScale =>
      _isCustom ? _scaleForQuality(_customQuality) : _presets[_presetIndex].renderScale;

  static double _scaleForQuality(int q) {
    if (q <= 45) return 0.75;
    if (q <= 70) return 1.0;
    return 1.25;
  }

  @override
  void initState() {
    super.initState();
    _originalSize = widget.file.lengthSync();
    final ts = DateTime.now();
    _nameController.text =
        '${fileStem(widget.file.path)}_compressed_${ts.year}${_d(ts.month)}${_d(ts.day)}';
    _loadInfo();
    _loadDefaultQuality();
  }

  Future<void> _loadDefaultQuality() async {
    final quality = await readDefaultImageQuality();
    if (!mounted) return;
    setState(() => _applyDefaultQuality(quality));
  }

  void _applyDefaultQuality(int quality) {
    for (var i = 0; i < _presets.length; i++) {
      if ((quality - _presets[i].quality).abs() <= 3) {
        _presetIndex = i;
        _isCustom = false;
        _customQuality = quality;
        return;
      }
    }
    _isCustom = true;
    _customQuality = quality;
  }


  String _d(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
        });
      }
    } catch (_) {}
  }

  // ─── Compress ──────────────────────────────────────────────────────────

  Future<void> _compress() async {
    setState(() {
      _state = _State.compressing;
      _progressPage = 0;
      _progressTotal = _pageCount ?? 0;
    });
    try {
      final File out = await PDFManager.compressPDF(
        widget.file,
        imageQuality: _activeQuality,
        renderScale: _activeScale,
        outputName: _nameController.text.trim(),
        onProgress: (cur, tot) {
          if (mounted) setState(() { _progressPage = cur; _progressTotal = tot; });
        },
      );

      final thumbPath = await PDFManager.generateThumbnail(out.path);
      await DocumentDatabase().insertDocument(out.path, thumbnailPath: thumbPath);
      PDFManager.hapticFeedbackSuccess();
      await ToolSuccessService.onMajorOperationComplete();

      if (mounted) {
        setState(() {
          _state = _State.done;
          _resultFile = out;
          _compressedSize = out.lengthSync();
        });
      }
    } catch (e, stack) {
      await ErrorLogger.log('compress', e, stack);
      PDFManager.hapticFeedbackError();
      if (mounted) {
        setState(() {
          _state = _State.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _compressAgain() =>
      setState(() { _state = _State.idle; _resultFile = null; });

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compress PDF')),
      body: switch (_state) {
        _State.idle      => _buildIdle(),
        _State.compressing => _buildCompressing(),
        _State.done      => _buildDone(),
        _State.error     => _buildError(),
      },
    );
  }

  // ─── Idle ──────────────────────────────────────────────────────────────

  Widget _buildIdle() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildInfoCard(),
              const SizedBox(height: 12),
              _buildPresetsSection(),
              const SizedBox(height: 12),
              if (_isCustom) ...[
                _buildCustomSlider(),
                const SizedBox(height: 12),
              ],
              _buildNameField(),
            ],
          ),
        ),
        _buildCompressBar(),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail
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
                      _infoChip(Icons.storage, _formatSize(_originalSize)),
                      const SizedBox(width: 10),
                      _infoChip(
                        Icons.layers,
                        _pageCount != null ? '$_pageCount pages' : '…',
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

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[600]),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildPresetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Compression preset',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey[700])),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _presets.length; i++) _buildPresetCard(i),
              _buildCustomCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetCard(int i) {
    final p = _presets[i];
    final selected = !_isCustom && _presetIndex == i;
    final est = _estimatedSize(_originalSize, p.quality);

    return GestureDetector(
      onTap: () => setState(() {
        _presetIndex = i;
        _isCustom = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 130,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? p.color : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 2.5 : 1,
          ),
          color: selected
              ? p.color.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(p.icon, color: selected ? p.color : Colors.grey, size: 22),
            const SizedBox(height: 6),
            Text(p.label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? p.color : null)),
            Text(p.sublabel,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(
              '≈ ${_formatSize(est)}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? p.color : Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomCard() {
    final selected = _isCustom;
    final est = _estimatedSize(_originalSize, _customQuality);
    return GestureDetector(
      onTap: () => setState(() => _isCustom = true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 130,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 2.5 : 1,
          ),
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.settings,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text('Custom',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : null)),
            Text('Your settings',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(
              '≈ ${_formatSize(est)}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSlider() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('JPEG quality',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '$_customQuality%  ·  ${_qualityLabel(_customQuality)}',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
            Slider(
              value: _customQuality.toDouble(),
              min: 20,
              max: 92,
              divisions: 72,
              label: '$_customQuality%',
              onChanged: (v) =>
                  setState(() => _customQuality = v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Smallest', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text('Sharpest', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Output name',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.picture_as_pdf),
        suffixText: '.pdf',
        isDense: true,
      ),
    );
  }

  Widget _buildCompressBar() {
    final est = _estimatedSize(_originalSize, _activeQuality);
    final reduction = ((1 - est / _originalSize) * 100).round();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_originalSize > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${_formatSize(_originalSize)} → ≈ ${_formatSize(est)} (≈$reduction% smaller)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _compress,
                icon: const Icon(Icons.compress),
                label: const Text('Compress PDF',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Compressing ───────────────────────────────────────────────────────

  Widget _buildCompressing() {
    final hasProgress = _progressTotal > 0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            value: hasProgress ? _progressPage / _progressTotal : null,
          ),
          const SizedBox(height: 20),
          Text(
            hasProgress
                ? 'Page $_progressPage of $_progressTotal…'
                : 'Compressing…',
            style: const TextStyle(fontSize: 16),
          ),
          if (hasProgress) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: _progressPage / _progressTotal,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Done ──────────────────────────────────────────────────────────────

  Widget _buildDone() {
    final saved = _originalSize - _compressedSize;
    final pct = _originalSize > 0
        ? ((saved / _originalSize) * 100).round()
        : 0;
    final enlarged = _compressedSize >= _originalSize;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            enlarged ? Icons.warning_amber_rounded : Icons.check_circle,
            size: 72,
            color: enlarged ? Colors.orange : Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            enlarged ? 'Could not reduce file size' : 'Compressed successfully',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Before / After card
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _sizeColumn('Original', _originalSize,
                        Colors.grey[600]!),
                  ),
                  Icon(Icons.arrow_forward,
                      color: Colors.grey[400], size: 22),
                  Expanded(
                    child: _sizeColumn(
                      'Compressed',
                      _compressedSize,
                      enlarged ? Colors.orange : Colors.green,
                    ),
                  ),
                  if (!enlarged)
                    Expanded(
                      child: _sizeColumn(
                        'Saved',
                        saved,
                        Colors.green,
                        prefix: '-',
                        badge: '$pct%',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Action buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  context.replaceWithPdfViewer(_resultFile!.path),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open PDF'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ShareService.files(
                    [XFile(_resultFile!.path)],
                    subject: fileName(_resultFile!.path),
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _compressAgain,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sizeColumn(String label, int bytes, Color valueColor,
      {String prefix = '', String? badge}) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(
          '$prefix${_formatSize(bytes)}',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor),
        ),
        if (badge != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(badge,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  // ─── Error ─────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Compression failed',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _compressAgain,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  /// Conservative estimate: assumes 75% of the file is image data that
  /// compresses at quality/100, plus 25% overhead (metadata, structure).
  static int _estimatedSize(int original, int quality) {
    if (original == 0) return 0;
    final ratio = (quality / 100) * 0.75 + 0.25;
    return (original * ratio).round();
  }

  static String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  static String _qualityLabel(int q) {
    if (q <= 40) return 'Aggressive';
    if (q <= 60) return 'High';
    if (q <= 75) return 'Balanced';
    if (q <= 85) return 'Light';
    return 'Minimal';
  }
}
