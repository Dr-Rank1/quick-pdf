import 'package:quick_pdf/services/error_logger.dart';
import 'package:quick_pdf/utils/image_quality_prefs.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/file_picker_service.dart';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:quick_pdf/router/app_navigation.dart';

class ConvertScreen extends StatefulWidget {
  final List<File> initialImages;
  const ConvertScreen({super.key, required this.initialImages});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  late List<File> _images;

  // Options
  String _pageSize = 'A4'; // 'A4' | 'Letter' | 'A3' | 'fit'
  bool _landscape = false;
  int _quality = 85;       // 90 high / 72 medium / 50 low
  double _margin = 20.0;   // PDF points: 0 / 20 / 40

  bool _isConverting = false;

  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.initialImages);
    final ts = DateTime.now();
    _nameController.text =
        'Document_${ts.year}${_d(ts.month)}${_d(ts.day)}_${_d(ts.hour)}${_d(ts.minute)}';
    _loadDefaultQuality();
  }

  Future<void> _loadDefaultQuality() async {
    final quality = await readDefaultImageQuality();
    if (mounted) setState(() => _quality = quality);
  }

  String _d(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ─── Image management ────────────────────────────────────────────────────

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
  }

  Future<void> _addMore() async {
    final picked = await FilePickerService.pickMultipleFiles(
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() => _images.addAll(picked));
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  // ─── Conversion ──────────────────────────────────────────────────────────

  Future<void> _convert() async {
    if (_images.isEmpty) return;
    setState(() => _isConverting = true);

    try {
      final File pdf = await PDFManager.convertImagesToPDF(
        _images,
        pageSize: _pageSize,
        landscape: _landscape && _pageSize != 'fit',
        quality: _quality,
        margin: _margin,
        outputName: _nameController.text.trim(),
      );

      final thumbPath = await PDFManager.generateThumbnail(pdf.path);
      await DocumentDatabase().insertDocument(pdf.path, thumbnailPath: thumbPath);
      PDFManager.hapticFeedbackSuccess();

      if (mounted) {
        context.replaceWithPdfViewer(pdf.path);
      }
    } catch (e, stack) {
      await ErrorLogger.log('convert', e, stack);
      PDFManager.hapticFeedbackError();
      if (mounted) {
        setState(() => _isConverting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversion failed: $e')),
        );
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Convert to PDF'),
        actions: [
          if (!_isConverting)
            TextButton(
              onPressed: _images.isNotEmpty ? _convert : null,
              child: Text(
                'Convert',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _images.isNotEmpty
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
            ),
        ],
      ),
      body: _isConverting ? _buildProgress() : _buildContent(),
    );
  }

  Widget _buildProgress() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Creating PDF from ${_images.length} image${_images.length == 1 ? '' : 's'}…',
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildNameField()),
              SliverToBoxAdapter(child: _buildOptionsCard()),
              SliverToBoxAdapter(child: _buildImageListHeader()),
              SliverReorderableList(
                itemCount: _images.length,
                onReorderItem: _onReorder,
                itemBuilder: (_, i) => _buildImageTile(i),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ],
          ),
        ),
        _buildConvertBar(),
      ],
    );
  }

  // ─── Options ─────────────────────────────────────────────────────────────

  Widget _buildNameField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'PDF name',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.picture_as_pdf),
          suffixText: '.pdf',
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page size + orientation ──────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _optionLabel('Page size'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip('A4', _pageSize == 'A4',
                              () => setState(() => _pageSize = 'A4')),
                          _chip('Letter', _pageSize == 'Letter',
                              () => setState(() => _pageSize = 'Letter')),
                          _chip('A3', _pageSize == 'A3',
                              () => setState(() => _pageSize = 'A3')),
                          _chip('Fit', _pageSize == 'fit',
                              () => setState(() => _pageSize = 'fit')),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_pageSize != 'fit') ...[
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _optionLabel('Orientation'),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _iconChip(Icons.stay_current_portrait, !_landscape,
                              () => setState(() => _landscape = false)),
                          const SizedBox(width: 6),
                          _iconChip(Icons.stay_current_landscape, _landscape,
                              () => setState(() => _landscape = true)),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // ── Quality + margins ────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _optionLabel('Quality'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip('High', _quality == 90,
                              () => setState(() => _quality = 90)),
                          _chip('Medium', _quality == 72,
                              () => setState(() => _quality = 72)),
                          _chip('Low', _quality == 50,
                              () => setState(() => _quality = 50)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _optionLabel('Margins'),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip('None', _margin == 0.0,
                              () => setState(() => _margin = 0.0)),
                          _chip('Normal', _margin == 20.0,
                              () => setState(() => _margin = 20.0)),
                          _chip('Wide', _margin == 40.0,
                              () => setState(() => _margin = 40.0)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.2,
        ),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _iconChip(IconData icon, bool selected, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? cs.onPrimary : cs.onSurfaceVariant,
        ),
      ),
    );
  }

  // ─── Image list ──────────────────────────────────────────────────────────

  Widget _buildImageListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Text(
            'Images (${_images.length})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _addMore,
            icon: const Icon(Icons.add_photo_alternate, size: 18),
            label: const Text('Add more'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageTile(int index) {
    final file = _images[index];
    // Use both path and index in key to handle duplicate files gracefully
    return Material(
      key: ValueKey('${file.path}_$index'),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Page number
            Container(
              width: 28,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(
                file,
                width: 52,
                height: 68,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 52,
                  height: 68,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName(file.path),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  FutureBuilder<FileStat>(
                    future: file.stat(),
                    builder: (_, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final kb = snap.data!.size / 1024;
                      return Text(
                        kb >= 1024
                            ? '${(kb / 1024).toStringAsFixed(1)} MB'
                            : '${kb.toStringAsFixed(0)} KB',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Remove button
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: Colors.grey[500],
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove',
              onPressed: () => _removeImage(index),
            ),
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_handle, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom bar ──────────────────────────────────────────────────────────

  Widget _buildConvertBar() {
    final String sizeLabel = _pageSizeLabel();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${_images.length} page${_images.length == 1 ? '' : 's'} · $sizeLabel · ${_qualityLabel()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _images.isNotEmpty ? _convert : null,
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(
                  _images.isEmpty
                      ? 'Add images to convert'
                      : 'Convert ${_images.length} image${_images.length == 1 ? '' : 's'} to PDF',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pageSizeLabel() {
    if (_pageSize == 'fit') return 'Fit to image';
    if (_landscape) return '$_pageSize Landscape';
    return '$_pageSize Portrait';
  }

  String _qualityLabel() {
    if (_quality >= 85) return 'High quality';
    if (_quality >= 65) return 'Medium quality';
    return 'Low quality';
  }
}
