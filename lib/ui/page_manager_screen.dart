import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf_render_maintained/pdf_render.dart' as render;
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:quick_pdf/services/document_database.dart';

class PageManagerScreen extends StatefulWidget {
  final File pdfFile;
  const PageManagerScreen({super.key, required this.pdfFile});

  @override
  State<PageManagerScreen> createState() => _PageManagerScreenState();
}

class _PageManagerScreenState extends State<PageManagerScreen> {
  List<_PageItem> _pages = [];
  bool _loading = true;
  bool _isProcessing = false;
  int _progress = 0;
  bool _multiSelect = false;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    render.PdfDocument? doc;
    try {
      doc = await render.PdfDocument.openFile(widget.pdfFile.path);
      if (!mounted) {
        await doc.dispose();
        return;
      }
      final count = doc.pageCount;
      final items = <_PageItem>[];

      for (int i = 1; i <= count; i++) {
        items.add(_PageItem(pageNumber: i));
      }
      setState(() {
        _pages = items;
        _loading = false;
      });

      // Load thumbnails async
      for (int i = 0; i < items.length; i++) {
        if (!mounted) break;
        try {
          final page = await doc.getPage(items[i].pageNumber);
          final rendered = await page.render(width: 120);
          try {
            final uiImage = await rendered.createImageIfNotAvailable();
            final bd =
                await uiImage.toByteData(format: ui.ImageByteFormat.png);
            uiImage.dispose();
            if (mounted && bd != null && i < _pages.length) {
              setState(() => _pages[i].thumb = bd.buffer.asUint8List());
            }
          } finally {
            rendered.dispose();
          }
        } catch (_) {}
        await Future.delayed(Duration.zero);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load pages: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      try {
        await doc?.dispose();
      } catch (_) {}
    }
  }

  int get _selectedCount =>
      _pages.where((p) => p.selected).length;

  void _toggleSelect(int index) {
    setState(() => _pages[index].selected = !_pages[index].selected);
  }

  void _selectAll() => setState(() {
        for (final p in _pages) {
          p.selected = true;
        }
      });

  void _deselectAll() => setState(() {
        for (final p in _pages) {
          p.selected = false;
        }
      });

  void _deleteSelected() async {
    if (_selectedCount == 0) return;
    if (_selectedCount == _pages.length) {
      _snack('Cannot delete all pages.');
      return;
    }
    setState(() {
      _pages.removeWhere((p) => p.selected);
      for (int i = 0; i < _pages.length; i++) {
        _pages[i].selected = false;
      }
      _multiSelect = false;
    });
  }

  void _rotatePage(int index, bool clockwise) {
    setState(() {
      final next =
          _pages[index].rotationDegrees + (clockwise ? 90 : -90);
      _pages[index].rotationDegrees = ((next % 360) + 360) % 360;
    });
  }

  Future<void> _saveChanges() async {
    setState(() { _isProcessing = true; _progress = 0; });
    try {
      // Build the page order using the current arrangement
      final pageOrder = _pages.map((p) => p.pageNumber).toList();
      final rotations = _pages.map((p) => p.rotationDegrees).toList();
      final out = await PDFManager.reorderPages(
        widget.pdfFile,
        pageOrder: pageOrder,
        rotations: rotations,
        onProgress: (c, t) {
          if (mounted) setState(() => _progress = c);
        },
      );
      final thumbPath = await PDFManager.generateThumbnail(out.path);
      await DocumentDatabase()
          .insertDocument(out.path, thumbnailPath: thumbPath);
      PDFManager.hapticFeedbackSuccess();
      await AdService().recordToolCompletion();
      if (mounted) {
        _snack('Saved: ${fileName(out.path)}');
        Navigator.of(context).pop();
      }
    } catch (e) {
      PDFManager.hapticFeedbackError();
      if (mounted) _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _extractSelected() async {
    final selected = _pages.where((p) => p.selected).toList();
    if (selected.isEmpty) {
      _snack('Select pages to extract first.');
      return;
    }
    setState(() { _isProcessing = true; _progress = 0; });
    try {
      final pageOrder = selected.map((p) => p.pageNumber).toList();
      final rotations = selected.map((p) => p.rotationDegrees).toList();
      final out = await PDFManager.reorderPages(
        widget.pdfFile,
        pageOrder: pageOrder,
        rotations: rotations,
        onProgress: (c, t) {
          if (mounted) setState(() => _progress = c);
        },
      );
      final thumbPath = await PDFManager.generateThumbnail(out.path);
      await DocumentDatabase()
          .insertDocument(out.path, thumbnailPath: thumbPath);
      PDFManager.hapticFeedbackSuccess();
      if (mounted) _snack('Extracted ${selected.length} pages to ${fileName(out.path)}');
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
      appBar: AppBar(
        title: Text(_multiSelect && _selectedCount > 0
            ? '$_selectedCount selected'
            : 'Page Manager'),
        actions: [
          if (_multiSelect) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select all',
              onPressed: _selectAll,
            ),
            IconButton(
              icon: const Icon(Icons.deselect),
              tooltip: 'Deselect all',
              onPressed: _deselectAll,
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Extract selected',
              onPressed: _extractSelected,
            ),
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete selected',
              onPressed: _selectedCount > 0 ? _deleteSelected : null,
            ),
          ],
          IconButton(
            icon: Icon(_multiSelect
                ? Icons.close
                : Icons.check_box_outlined),
            tooltip:
                _multiSelect ? 'Exit selection' : 'Multi-select',
            onPressed: () {
              setState(() {
                _multiSelect = !_multiSelect;
                if (!_multiSelect) _deselectAll();
              });
            },
          ),
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Processing page $_progress…',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ReorderableGridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                  childAspectRatio: 0.7,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      final item = _pages.removeAt(oldIndex);
                      _pages.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (int i = 0; i < _pages.length; i++)
                      _PageTile(
                        key: ValueKey('${_pages[i].pageNumber}_$i'),
                        item: _pages[i],
                        index: i,
                        multiSelect: _multiSelect,
                        onToggleSelect: () => _toggleSelect(i),
                        onRotateCW: () => _rotatePage(i, true),
                        onRotateCCW: () => _rotatePage(i, false),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _saveChanges,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Save'),
      ),
    );
  }
}

class _PageItem {
  final int pageNumber;
  Uint8List? thumb;
  bool selected = false;
  int rotationDegrees = 0;
  _PageItem({required this.pageNumber});
}

class _PageTile extends StatelessWidget {
  final _PageItem item;
  final int index;
  final bool multiSelect;
  final VoidCallback onToggleSelect;
  final VoidCallback onRotateCW;
  final VoidCallback onRotateCCW;

  const _PageTile({
    required super.key,
    required this.item,
    required this.index,
    required this.multiSelect,
    required this.onToggleSelect,
    required this.onRotateCW,
    required this.onRotateCCW,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: multiSelect ? onToggleSelect : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              border: item.selected
                  ? Border.all(color: cs.primary, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: item.thumb != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Transform.rotate(
                      angle: item.rotationDegrees * 3.14159 / 180,
                      child: Image.memory(item.thumb!,
                          fit: BoxFit.contain),
                    ),
                  )
                : Center(
                    child: Text(
                      '${item.pageNumber}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
          ),

          // Page number badge
          Positioned(
            bottom: 22,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'p. ${item.pageNumber}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 9),
                ),
              ),
            ),
          ),

          // Rotation buttons (always visible, small)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RotBtn(icon: Icons.rotate_left, onTap: onRotateCCW),
                _RotBtn(icon: Icons.rotate_right, onTap: onRotateCW),
              ],
            ),
          ),

          // Selection overlay
          if (multiSelect && item.selected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _RotBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RotBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 20,
        color: Colors.black38,
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}

// ── Placeholder ReorderableGridView ──────────────────────────────────────────
// Replace with `reorderable_grid_view` package if needed; this simple version
// wraps ReorderableListView in a GridView-style layout.

class ReorderableGridView extends StatelessWidget {
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsets padding;
  final double childAspectRatio;
  final List<Widget> children;
  final void Function(int oldIndex, int newIndex) onReorder;

  static count({
    required int crossAxisCount,
    required double crossAxisSpacing,
    required double mainAxisSpacing,
    required EdgeInsets padding,
    required double childAspectRatio,
    required List<Widget> children,
    required void Function(int oldIndex, int newIndex) onReorder,
  }) => ReorderableGridView(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        padding: padding,
        childAspectRatio: childAspectRatio,
        onReorder: onReorder,
        children: children,
      );

  const ReorderableGridView({
    super.key,
    required this.crossAxisCount,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
    required this.padding,
    required this.childAspectRatio,
    required this.children,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: padding,
      itemCount: children.length,
      onReorderItem: onReorder,
      buildDefaultDragHandles: false,
      itemBuilder: (_, i) => ReorderableDragStartListener(
        key: children[i].key!,
        index: i,
        child: children[i],
      ),
    );
  }
}
