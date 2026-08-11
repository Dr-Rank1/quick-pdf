import 'package:quick_pdf/services/error_logger.dart';
import 'dart:io';
import 'package:quick_pdf/utils/path_utils.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/file_picker_service.dart';
import 'package:quick_pdf/services/tool_success_service.dart';
import 'package:quick_pdf/router/app_navigation.dart';
import 'package:pdf_render_maintained/pdf_render.dart';

// ─── Data ────────────────────────────────────────────────────────────────────

class MergeItem {
  final File file;
  int? pageCount;
  Uint8List? thumbnail;
  Set<int>? selectedPages; // null = all pages; 1-indexed

  MergeItem({required this.file});

  String get name => fileName(file.path);

  int get includedPageCount =>
      selectedPages?.length ?? (pageCount ?? 0);

  bool get isLoaded => pageCount != null;

  String get pagesLabel {
    if (!isLoaded) return '…';
    final total = pageCount!;
    final sel = selectedPages;
    if (sel == null || sel.length == total) return '$total pages';
    final sorted = sel.toList()..sort();
    return '${sorted.length}/$total: ${_rangeString(sorted)}';
  }

  static String _rangeString(List<int> pages) {
    if (pages.isEmpty) return '';
    final parts = <String>[];
    int s = pages[0], p = pages[0];
    for (int i = 1; i < pages.length; i++) {
      if (pages[i] == p + 1) {
        p = pages[i];
      } else {
        parts.add(s == p ? '$s' : '$s–$p');
        s = p = pages[i];
      }
    }
    parts.add(s == p ? '$s' : '$s–$p');
    return parts.join(', ');
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class MergeScreen extends StatefulWidget {
  final List<File> initialFiles;
  const MergeScreen({super.key, required this.initialFiles});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<MergeItem> _items = [];
  bool _isMerging = false;
  int _mergeProgressPage = 0;
  int _mergeProgressTotal = 0;
  final TextEditingController _nameController = TextEditingController();

  int get _totalPages =>
      _items.fold(0, (s, i) => s + i.includedPageCount);

  @override
  void initState() {
    super.initState();
    final ts = DateTime.now();
    _nameController.text =
        'Merged_${ts.year}${_d(ts.month)}${_d(ts.day)}_${_d(ts.hour)}${_d(ts.minute)}';
    for (final f in widget.initialFiles) {
      _addItem(f);
    }
  }

  String _d(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ─── Item management ───────────────────────────────────────────────────

  Future<void> _addItem(File file) async {
    final item = MergeItem(file: file);
    setState(() => _items.add(item));
    await _loadItemMetadata(item);
  }

  Future<void> _loadItemMetadata(MergeItem item) async {
    try {
      final doc = await PdfDocument.openFile(item.file.path);
      final page = await doc.getPage(1);
      final rendered = await page.render(width: 120, height: 160);
      final uiImage = await rendered.createImageIfNotAvailable();
      final bd = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();
      final int count = doc.pageCount;
      await doc.dispose();

      if (mounted) {
        setState(() {
          item.pageCount = count;
          item.thumbnail = bd?.buffer.asUint8List();
        });
      }
    } catch (_) {
      if (mounted) setState(() => item.pageCount = 0);
    }
  }

  Future<void> _addMore() async {
    final picked = await FilePickerService.pickMultipleFiles(
      allowedExtensions: ['pdf'],
    );
    if (picked != null) {
      for (final f in picked) {
        await _addItem(f);
      }
    }
  }

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  // ─── Page picker ───────────────────────────────────────────────────────

  Future<void> _openPagePicker(int index) async {
    final item = _items[index];
    if (item.pageCount == null || item.pageCount == 0) return;

    final initial = item.selectedPages ??
        Set<int>.from(List.generate(item.pageCount!, (i) => i + 1));

    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PagePickerSheet(
        file: item.file,
        totalPages: item.pageCount!,
        initialSelection: initial,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        item.selectedPages =
            result.length == item.pageCount ? null : result;
      });
    }
  }

  // ─── Merge ─────────────────────────────────────────────────────────────

  Future<void> _merge() async {
    final active = _items
        .where((i) => i.isLoaded && i.includedPageCount > 0)
        .toList();
    if (active.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 PDFs to merge')),
      );
      return;
    }

    setState(() {
      _isMerging = true;
      _mergeProgressPage = 0;
      _mergeProgressTotal = active.fold(0, (s, i) => s + i.includedPageCount);
    });
    try {
      final pageSelections = active
          .map((i) => i.selectedPages?.toList()
            ?..sort())
          .toList();

      final File merged = await PDFManager.mergePDFFiles(
        active.map((i) => i.file).toList(),
        pageSelections: pageSelections,
        outputName: _nameController.text.trim(),
        onProgress: (cur, tot) {
          if (mounted) setState(() { _mergeProgressPage = cur; _mergeProgressTotal = tot; });
        },
      );

      final thumbPath = await PDFManager.generateThumbnail(merged.path);
      await DocumentDatabase().insertDocument(merged.path, thumbnailPath: thumbPath);
      PDFManager.hapticFeedbackSuccess();
      await ToolSuccessService.onMajorOperationComplete();

      if (mounted) {
        context.replaceWithPdfViewer(merged.path);
      }
    } catch (e, stack) {
      await ErrorLogger.log('merge', e, stack);
      PDFManager.hapticFeedbackError();
      if (mounted) {
        setState(() => _isMerging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merge failed: $e')),
        );
      }
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge PDFs'),
        actions: [
          if (!_isMerging)
            TextButton(
              onPressed: _items.length >= 2 ? _merge : null,
              child: Text(
                'Merge',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _items.length >= 2
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
            ),
        ],
      ),
      body: _isMerging ? _buildProgress() : _buildContent(),
    );
  }

  Widget _buildProgress() {
    final hasProgress = _mergeProgressTotal > 0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            value: hasProgress
                ? _mergeProgressPage / _mergeProgressTotal
                : null,
          ),
          const SizedBox(height: 20),
          Text(
            hasProgress
                ? 'Page $_mergeProgressPage of $_mergeProgressTotal…'
                : 'Merging…',
            style: const TextStyle(fontSize: 15),
          ),
          if (hasProgress) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: _mergeProgressPage / _mergeProgressTotal,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildNameField(),
        _buildLosslessNote(),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 8),
            header: _buildListHeader(),
            footer: _buildAddMoreButton(),
            itemCount: _items.length,
            onReorderItem: _onReorder,
            itemBuilder: (_, i) => _buildItemCard(i),
          ),
        ),
        _buildMergeBar(),
      ],
    );
  }

  // ─── Options ───────────────────────────────────────────────────────────

  Widget _buildNameField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Output name',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.picture_as_pdf),
          suffixText: '.pdf',
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildLosslessNote() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Icon(Icons.text_fields, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lossless merge — text stays selectable',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── List ──────────────────────────────────────────────────────────────

  Widget _buildListHeader() {
    final loaded = _items.every((i) => i.isLoaded);
    final summary = loaded && _items.isNotEmpty
        ? '${_items.length} file${_items.length == 1 ? '' : 's'} · $_totalPages pages total'
        : '${_items.length} file${_items.length == 1 ? '' : 's'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: Row(
        children: [
          Text(summary,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          TextButton.icon(
            onPressed: _addMore,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add PDF'),
            style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Material(
      key: ValueKey('${item.file.path}_$index'),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // Order badge
                Container(
                  width: 26,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),

                // First-page thumbnail
                _buildThumb(item),
                const SizedBox(width: 10),

                // File info + page selection
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: item.isLoaded
                            ? () => _openPagePicker(index)
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.selectedPages == null
                                  ? Icons.layers
                                  : Icons.layers_outlined,
                              size: 13,
                              color: item.isLoaded
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.pagesLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: item.isLoaded
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                                decoration: item.isLoaded
                                    ? TextDecoration.underline
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Remove
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: Colors.grey[500],
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removeItem(index),
                ),

                // Drag handle
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.drag_handle, color: Colors.grey[400]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumb(MergeItem item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: 46,
        height: 60,
        color: Colors.grey[100],
        child: item.thumbnail != null
            ? Image.memory(item.thumbnail!, fit: BoxFit.cover)
            : item.isLoaded
                ? const Icon(Icons.picture_as_pdf,
                    color: Colors.red, size: 28)
                : const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))),
      ),
    );
  }

  Widget _buildAddMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: OutlinedButton.icon(
        onPressed: _addMore,
        icon: const Icon(Icons.add),
        label: const Text('Add more PDFs'),
        style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44)),
      ),
    );
  }

  // ─── Bottom bar ────────────────────────────────────────────────────────

  Widget _buildMergeBar() {
    final active = _items.where((i) => i.includedPageCount > 0).length;
    final canMerge = active >= 2;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: canMerge ? _merge : null,
            icon: const Icon(Icons.merge_type),
            label: Text(
              canMerge
                  ? 'Merge $active PDFs into $_totalPages pages'
                  : 'Add at least 2 PDFs',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Page picker bottom sheet ────────────────────────────────────────────────

class _PagePickerSheet extends StatefulWidget {
  final File file;
  final int totalPages;
  final Set<int> initialSelection;

  const _PagePickerSheet({
    required this.file,
    required this.totalPages,
    required this.initialSelection,
  });

  @override
  State<_PagePickerSheet> createState() => _PagePickerSheetState();
}

class _PagePickerSheetState extends State<_PagePickerSheet> {
  late Set<int> _selection;
  final Map<int, Uint8List?> _thumbs = {};

  @override
  void initState() {
    super.initState();
    _selection = Set.from(widget.initialSelection);
    _loadThumbs();
  }

  Future<void> _loadThumbs() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      for (int i = 1; i <= widget.totalPages; i++) {
        if (!mounted) break;
        final page = await doc.getPage(i);
        final rendered = await page.render(width: 110);
        final uiImage = await rendered.createImageIfNotAvailable();
        final bd =
            await uiImage.toByteData(format: ui.ImageByteFormat.png);
        uiImage.dispose();
        if (mounted) {
          setState(() => _thumbs[i] = bd?.buffer.asUint8List());
        }
      }
      await doc.dispose();
    } catch (_) {}
  }

  void _toggle(int p) => setState(() {
        _selection.contains(p) ? _selection.remove(p) : _selection.add(p);
      });

  @override
  Widget build(BuildContext context) {
    final allSelected = _selection.length == widget.totalPages;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName(widget.file.path),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_selection.length} of ${widget.totalPages} pages selected',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selection = {
                        for (int i = 1; i <= widget.totalPages; i++) i
                      }),
                  child: const Text('All'),
                ),
                TextButton(
                  onPressed: () => setState(() => _selection.clear()),
                  child: const Text('None'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Thumbnail grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.72,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: widget.totalPages,
              itemBuilder: (_, i) {
                final p = i + 1;
                final selected = _selection.contains(p);
                final thumb = _thumbs[p];
                return GestureDetector(
                  onTap: () => _toggle(p),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Page thumbnail
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[300]!,
                            width: selected ? 2.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: thumb != null
                              ? Image.memory(thumb, fit: BoxFit.cover)
                              : Container(
                                  color: Colors.grey[100],
                                  child: const Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                ),
                        ),
                      ),

                      // Dim overlay when excluded
                      if (!selected)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: ColoredBox(
                              color: Colors.white.withValues(alpha: 0.55)),
                        ),

                      // Page number
                      Positioned(
                        bottom: 4,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text('$p',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                          ),
                        ),
                      ),

                      // Checkmark
                      if (selected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  Theme.of(context).colorScheme.primary,
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 13),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Done button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selection.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selection),
                child: Text(
                  _selection.isEmpty
                      ? 'Select at least one page'
                      : allSelected
                          ? 'Include all ${widget.totalPages} pages'
                          : 'Include ${_selection.length} page${_selection.length == 1 ? '' : 's'}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
