import 'package:quick_pdf/services/error_logger.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quick_pdf/services/file_picker_service.dart';
import 'package:quick_pdf/services/ocr_service.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/tool_success_service.dart';
import 'package:quick_pdf/services/share_service.dart';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:path_provider/path_provider.dart';

class OcrTextScreen extends StatefulWidget {
  final File file;
  const OcrTextScreen({super.key, required this.file});

  @override
  State<OcrTextScreen> createState() => _OcrTextScreenState();
}

class _OcrTextScreenState extends State<OcrTextScreen> {
  final OcrService _ocrService = OcrService();

  // Results
  List<OcrPageResult> _results = [];
  List<String> _editedTexts = [];   // mirrors _results, holds in-progress edits
  File? _currentFile;

  // Processing state
  bool _isProcessing = false;
  int _processingPage = 0;
  int _processingTotal = 0;

  // View state
  int _currentPageIndex = 0;
  bool _isEditing = false;
  bool _isSearching = false;
  double _fontSize = 15.0;
  String _searchQuery = '';

  // Controllers
  final TextEditingController _editController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Computed
  int get _totalWords =>
      _results.fold(0, (s, r) => s + r.wordCount);
  int get _totalChars =>
      _results.fold(0, (s, r) => s + r.charCount);

  String get _displayText {
    if (_isEditing && _editedTexts.isNotEmpty) {
      if (_currentPageIndex < _editedTexts.length) {
        return _editedTexts[_currentPageIndex];
      }
    }
    if (_results.isNotEmpty && _currentPageIndex < _results.length) {
      return _results[_currentPageIndex].text;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file;
    _run(widget.file);
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _editController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Extraction ──────────────────────────────────────────────────────────

  Future<void> _run(File file) async {
    setState(() {
      _isProcessing = true;
      _processingPage = 0;
      _processingTotal = 0;
      _results = [];
      _editedTexts = [];
      _currentPageIndex = 0;
      _isEditing = false;
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });

    try {
      final results = await _ocrService.extractText(
        file,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _processingPage = current;
              _processingTotal = total;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _results = results;
        _editedTexts = results.map((r) => r.text).toList();
        _isProcessing = false;
      });

      // Persist extracted text for full-text search
      final allText = results.map((r) => r.text).join('\n\n---\n\n');
      if (allText.trim().isNotEmpty) {
        final db = DocumentDatabase();
        final existing = await db.getDocument(file.path);
        if (existing != null) {
          await db.updateTextContent(file.path, allText);
        } else {
          await db.insertDocument(file.path, textContent: allText);
        }
      }

      await ToolSuccessService.onMajorOperationComplete();
    } catch (e, stack) {
      await ErrorLogger.log('ocr', e, stack);
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extraction failed: $e')),
        );
      }
    }
  }

  // ─── Page navigation ─────────────────────────────────────────────────────

  void _goToPage(int index) {
    if (index < 0 || index >= _results.length) return;
    if (_isEditing && _editedTexts.isNotEmpty) {
      _editedTexts[_currentPageIndex] = _editController.text;
    }
    setState(() => _currentPageIndex = index);
    if (_isEditing && _editedTexts.isNotEmpty) {
      _editController.text = _editedTexts[index];
    }
    _scrollController.jumpTo(0);
  }

  // ─── Edit mode ───────────────────────────────────────────────────────────

  void _toggleEdit() {
    if (!_isEditing) {
      // Entering edit mode
      _editController.text =
          _editedTexts.isNotEmpty ? _editedTexts[_currentPageIndex] : '';
      setState(() {
        _isEditing = true;
        _isSearching = false;
      });
    } else {
      // Saving edits
      if (_editedTexts.isNotEmpty) {
        _editedTexts[_currentPageIndex] = _editController.text;
      }
      setState(() => _isEditing = false);
    }
  }

  // ─── Search ──────────────────────────────────────────────────────────────

  List<int> get _matchingPageIndices {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    return [
      for (int i = 0; i < _editedTexts.length; i++)
        if (_editedTexts[i].toLowerCase().contains(q)) i,
    ];
  }

  int _matchCount(int pageIndex) {
    if (_searchQuery.isEmpty) return 0;
    if (pageIndex < 0 || pageIndex >= _editedTexts.length) return 0;
    final q = _searchQuery.toLowerCase();
    final text = _editedTexts[pageIndex].toLowerCase();
    int n = 0, start = 0;
    while (true) {
      final idx = text.indexOf(q, start);
      if (idx == -1) break;
      n++;
      start = idx + q.length;
    }
    return n;
  }

  int get _totalMatchCount =>
      _results.isEmpty
          ? 0
          : List.generate(_results.length, _matchCount)
              .fold(0, (a, b) => a + b);

  void _nextMatchPage() {
    final pages = _matchingPageIndices;
    if (pages.isEmpty) return;
    final next = pages.firstWhere(
      (i) => i > _currentPageIndex,
      orElse: () => pages.first,
    );
    _goToPage(next);
  }

  void _prevMatchPage() {
    final pages = _matchingPageIndices;
    if (pages.isEmpty) return;
    final prev = pages.lastWhere(
      (i) => i < _currentPageIndex,
      orElse: () => pages.last,
    );
    _goToPage(prev);
  }

  // ─── Export actions ──────────────────────────────────────────────────────

  Future<void> _copyCurrentPage() async {
    final text = _displayText;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Page text copied')),
      );
    }
  }

  Future<void> _copyAll() async {
    final all = _editedTexts.join('\n\n');
    if (all.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: all));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All text copied ($_totalWords words)'),
        ),
      );
    }
  }

  Future<void> _saveAsTxt() async {
    final all = _editedTexts.join('\n\n');
    if (all.isEmpty) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final base = _currentFile != null
          ? fileStem(_currentFile!.path)
          : 'extracted';
      final outFile =
          File('${dir.path}/${base}_extracted.txt');
      await outFile.writeAsString(all);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: ${fileName(outFile.path)}'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => ShareService.files(
                [XFile(outFile.path)],
                subject: '$base — extracted text',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _shareText() async {
    final all = _editedTexts.join('\n\n');
    if (all.isEmpty) return;
    await ShareService.text(all, subject: 'Extracted text from QuickPDF');
  }

  Future<void> _pickAnotherFile() async {
    final result = await FilePickerService.pickMultipleFiles(
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'bmp', 'webp'],
      allowMultiple: false,
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _currentFile = result.first);
      await _run(result.first);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool hasText = _results.isNotEmpty &&
        _results.any((r) => r.text.trim().isNotEmpty);

    return Scaffold(
      appBar: _buildAppBar(hasText),
      body: Column(
        children: [
          if (_isProcessing) _buildProgressBanner(),
          if (_isSearching && !_isProcessing) _buildSearchBar(),
          if (hasText && !_isProcessing) _buildStatsBar(),
          if (_results.length > 1 && !_isProcessing) _buildPageSelector(),
          Expanded(
            child: _isProcessing
                ? _buildProcessingView()
                : hasText
                    ? _buildTextContent()
                    : _buildEmptyState(),
          ),
        ],
      ),
      bottomNavigationBar: hasText && !_isProcessing
          ? _buildBottomBar()
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(bool hasText) {
    return AppBar(
      title: Text(
        _currentFile != null ? fileName(_currentFile!.path) : 'Extract Text',
        style: const TextStyle(fontSize: 15),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (hasText && !_isEditing)
          IconButton(
            icon: Icon(
              Icons.search,
              color: _isSearching
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: 'Search in text',
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchQuery = '';
                _searchController.clear();
              }
            }),
          ),
        if (hasText)
          IconButton(
            icon: Icon(_isEditing ? Icons.done : Icons.edit_note),
            tooltip: _isEditing ? 'Save edits' : 'Edit text',
            onPressed: _toggleEdit,
          ),
        PopupMenuButton<String>(
          onSelected: (v) async {
            switch (v) {
              case 'copy_all':   await _copyAll();         break;
              case 'pick':       await _pickAnotherFile(); break;
              case 'font_small': setState(() => _fontSize = 12); break;
              case 'font_med':   setState(() => _fontSize = 15); break;
              case 'font_large': setState(() => _fontSize = 18); break;
              case 'font_xl':    setState(() => _fontSize = 22); break;
              case 'rerun':
                if (_currentFile != null) await _run(_currentFile!);
                break;
            }
          },
          itemBuilder: (_) => [
            if (hasText)
              const PopupMenuItem(
                value: 'copy_all',
                child: ListTile(
                  leading: Icon(Icons.copy_all),
                  title: Text('Copy all pages'),
                  dense: true,
                ),
              ),
            const PopupMenuItem(
              value: 'pick',
              child: ListTile(
                leading: Icon(Icons.file_open),
                title: Text('Open another file'),
                dense: true,
              ),
            ),
            if (hasText) ...[
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Text('Font size',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const PopupMenuItem(
                value: 'font_small',
                child: ListTile(
                  title: Text('Small', style: TextStyle(fontSize: 12)),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'font_med',
                child: ListTile(
                  title: Text('Medium', style: TextStyle(fontSize: 15)),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'font_large',
                child: ListTile(
                  title: Text('Large', style: TextStyle(fontSize: 18)),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'font_xl',
                child: ListTile(
                  title: Text('Extra Large', style: TextStyle(fontSize: 22)),
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'rerun',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Re-run extraction'),
                  dense: true,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildProgressBanner() {
    final pct = _processingTotal > 0
        ? _processingPage / _processingTotal
        : 0.0;
    return LinearProgressIndicator(value: pct > 0 ? pct : null);
  }

  Widget _buildProcessingView() {
    final label = _processingTotal > 0
        ? 'Extracting page $_processingPage of $_processingTotal…'
        : 'Extracting text…';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(label, style: const TextStyle(fontSize: 15)),
          if (_processingTotal > 1) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: _processingTotal > 0
                    ? _processingPage / _processingTotal
                    : null,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final pageLabel = _results.length == 1
        ? '1 page'
        : '${_results.length} pages';
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _statChip(Icons.menu_book_outlined, pageLabel),
          const SizedBox(width: 12),
          _statChip(Icons.short_text, '$_totalWords words'),
          const SizedBox(width: 12),
          _statChip(Icons.tag, '$_totalChars chars'),
          if (_searchQuery.isNotEmpty) ...[
            const Spacer(),
            Text(
              '$_totalMatchCount match${_totalMatchCount == 1 ? '' : 'es'}',
              style: TextStyle(
                fontSize: 12,
                color: _totalMatchCount > 0
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search in text…',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          if (_matchingPageIndices.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              tooltip: 'Previous match page',
              onPressed: _prevMatchPage,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Next match page',
              onPressed: _nextMatchPage,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageSelector() {
    return Container(
      height: 44,
      color: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: _results.length,
        itemBuilder: (_, i) {
          final isActive = i == _currentPageIndex;
          final matches = _matchCount(i);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => _goToPage(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'p.${i + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : null,
                      ),
                    ),
                    if (matches > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white30
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$matches',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextContent() {
    return _isEditing ? _buildEditView() : _buildReadView();
  }

  Widget _buildReadView() {
    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: _displayText.trim().isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_not_supported_outlined,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No text found on this page',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            : SelectableText.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: _fontSize,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  children: _buildHighlightedSpans(_displayText, _searchQuery),
                ),
              ),
      ),
    );
  }

  Widget _buildEditView() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _editController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(fontSize: _fontSize, height: 1.6),
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          hintText: 'No text on this page',
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasError = !_isProcessing && _results.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError ? Icons.warning_amber_outlined : Icons.text_snippet_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              hasError
                  ? 'No text could be extracted'
                  : 'No text found',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The document may contain only images or be blank.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _pickAnotherFile,
              icon: const Icon(Icons.file_open),
              label: const Text('Open another file'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _bottomAction(Icons.copy, 'Copy page', _copyCurrentPage),
          _bottomAction(Icons.save_alt, 'Save .txt', _saveAsTxt),
          _bottomAction(Icons.share, 'Share', _shareText),
        ],
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  List<TextSpan> _buildHighlightedSpans(String text, String query) {
    if (query.isEmpty) return [TextSpan(text: text)];

    final q = query.toLowerCase();
    final t = text.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (start < text.length) {
      final idx = t.indexOf(q, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          backgroundColor: Colors.yellow.withValues(alpha: 0.65),
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = idx + query.length;
    }
    return spans;
  }
}
