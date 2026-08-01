import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/providers/document_provider.dart';
import 'package:quick_pdf/services/share_service.dart';
import 'package:quick_pdf/services/file_picker_service.dart';
import 'package:quick_pdf/router/app_navigation.dart';
import 'package:quick_pdf/ui/widgets/search_delegate.dart';
import 'package:quick_pdf/ui/widgets/tools_catalog.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/services/document_import_service.dart';
import 'package:quick_pdf/ui/widgets/desktop_drop_zone.dart';
import 'package:quick_pdf/ui/widgets/doc_thumb_hero.dart';
import 'package:quick_pdf/theme/app_colors.dart';
import 'package:quick_pdf/theme/app_theme.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:startapp_sdk/startapp.dart';

String _fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

String _relativeDate(String? isoDate) {
  if (isoDate == null) return '';
  final dt = DateTime.tryParse(isoDate);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
  if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'Just now';
}

enum _SortMode { recent, name, size, added }

int _gridCrossAxisCount(double width) {
  if (width >= 900) return 6;
  if (width >= 600) return 4;
  return 2;
}

double _gridChildAspectRatio(int columns) {
  switch (columns) {
    case 6:
      return 0.82;
    case 4:
      return 0.76;
    default:
      return 0.72;
  }
}

List<Map<String, dynamic>> _skeletonMockDocs(int count) => List.generate(
      count,
      (i) => {
        'path': '/skeleton/mock_$i.pdf',
        'name': 'Sample document ${i + 1}.pdf',
        'size': 245760 * (i + 1),
        'thumbnail_path': null,
        'lastOpened': DateTime.now().toIso8601String(),
        'is_favourite': 0,
      },
    );

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _importDone = 0;
  int _importTotal = 0;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ─── Quick actions ─────────────────────────────────────────────────────────

  Future<void> _quickScan() => context.pushScan();

  Future<void> _quickConvert() async {
    final r = await FilePickerService.pickMultipleFiles(
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp']);
    if (r == null || r.isEmpty || !mounted) return;
    await context.pushConvert(r);
  }

  Future<void> _quickMerge() async {
    final r = await FilePickerService.pickMultipleFiles(allowedExtensions: ['pdf']);
    if (r == null || r.isEmpty || !mounted) return;
    await context.pushMerge(r);
  }

  Future<void> _quickSplit() async {
    final r = await FilePickerService.pickMultipleFiles(allowedExtensions: ['pdf']);
    if (r == null || r.isEmpty || !mounted) return;
    await context.pushSplit(r.first);
  }

  Future<void> _quickCompress() async {
    final r = await FilePickerService.pickMultipleFiles(allowedExtensions: ['pdf']);
    if (r == null || r.isEmpty || !mounted) return;
    await context.pushCompress(r.first);
  }

  Future<void> _quickExtract() async {
    final r = await FilePickerService.pickMultipleFiles(
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    if (r == null || r.isEmpty || !mounted) return;
    await context.pushOcr(r.first);
  }

  Future<void> _quickFormat() => context.pushFormatConverter();

  Future<void> _quickMetadata() async {
    final r = await FilePickerService.pickMultipleFiles(allowedExtensions: ['pdf']);
    if (r == null || r.isEmpty || !mounted) return;
    await context.pushEditMetadata(r.first);
  }

  Future<void> _quickProtect() => context.pushPasswordProtect();

  Future<void> _quickWatermark() => context.pushWatermark();

  Future<void> _quickPageManager() async {
    final r =
        await FilePickerService.pickMultipleFiles(allowedExtensions: ['pdf']);
    if (r == null || r.isEmpty || !mounted) return;
    await context.pushPageManager(r.first);
  }

  // ─── Document open ──────────────────────────────────────────────────────────

  Future<void> _onDocumentTap(String path) async {
    await ref.read(documentDatabaseProvider).updateLastOpened(path);
    if (!mounted) return;
    final ext = path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'bmp', 'webp'].contains(ext)) {
      await context.openImageViewer(path);
    } else {
      await context.openPdfViewer(path, heroTag: docThumbHeroTag(path));
    }
  }

  // ─── Add files ─────────────────────────────────────────────────────────────

  Future<void> _importPaths(List<String> paths) async {
    if (paths.isEmpty || !mounted) return;

    setState(() {
      _importDone = 0;
      _importTotal = paths.length;
    });

    final count = await DocumentImportService.instance.importPaths(
      paths,
      onProgress: (done, total) {
        if (mounted) {
          setState(() {
            _importDone = done;
            _importTotal = total;
          });
        }
      },
    );

    if (!mounted) return;
    setState(() {
      _importDone = 0;
      _importTotal = 0;
    });

    if (count > 0) {
      AdService().recordToolCompletion();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Added $count file${count == 1 ? '' : 's'}'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _addFiles() async {
    final result = await FilePickerService.pickMultipleFiles(
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (!mounted || result == null || result.isEmpty) return;
    await _importPaths(result.map((f) => f.path).toList());
  }

  // ─── FAB quick-add bottom sheet ────────────────────────────────────────────

  void _showQuickAddSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Add document',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue, size: 18),
              ),
              title: const Text('Scan Document'),
              subtitle: const Text('Use your camera to scan pages'),
              onTap: () { Navigator.pop(context); _quickScan(); },
            ),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder_open_outlined,
                    color: Colors.green, size: 18),
              ),
              title: const Text('Import from Files'),
              subtitle: const Text('Pick a PDF or image from storage'),
              onTap: () { Navigator.pop(context); _addFiles(); },
            ),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image, color: Colors.orange, size: 18),
              ),
              title: const Text('Images to PDF'),
              subtitle: const Text('Combine photos into a single PDF'),
              onTap: () { Navigator.pop(context); _quickConvert(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final muted = AppColors.muted(brightness);
    final border = AppColors.border(brightness);

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      appBar: AppBar(
        title: const QuickPdfWordmark(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface2(brightness),
                side: BorderSide(color: border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(Icons.search, color: muted, size: 20),
              onPressed: () => showSearch(
                  context: context, delegate: DocumentSearchDelegate()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    _HomeTabPill(
                      label: 'Recent',
                      selected: _tabs.index == 0,
                      onTap: () => _tabs.animateTo(0),
                    ),
                    const SizedBox(width: 4),
                    _HomeTabPill(
                      label: 'Tools',
                      selected: _tabs.index == 1,
                      onTap: () => _tabs.animateTo(1),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: border),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabs,
            children: [
              // ── Tab 0: Recent ──
              _DocumentGrid(
                onDocumentTap: _onDocumentTap,
                onDocumentDelete: (path) async {
                  await ref.read(documentDatabaseProvider).deleteDocument(path);
                  try { await File(path).delete(); } catch (_) {}
                },
                onImportDropped: _importPaths,
                onScan: _quickScan,
                onImport: _addFiles,
              ),
              // ── Tab 1: Tools ──
              _HomeToolsTab(
                onAddFiles: _importTotal > 0 ? null : _addFiles,
                onScan: _quickScan,
                onConvert: _quickConvert,
                onMerge: _quickMerge,
                onSplit: _quickSplit,
                onCompress: _quickCompress,
                onExtract: _quickExtract,
                onFormat: _quickFormat,
                onMetadata: _quickMetadata,
                onProtect: _quickProtect,
                onWatermark: _quickWatermark,
                onPageManager: _quickPageManager,
              ),
            ],
          ),
          if (_importTotal > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 88,
              child: _ImportProgressPill(
                done: _importDone,
                total: _importTotal,
              ),
            ),
        ],
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton(
              onPressed: _showQuickAddSheet,
              tooltip: 'Add document',
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _HomeTabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HomeTabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.muted(Theme.of(context).brightness);
    return Material(
      color: selected ? AppColors.navy : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Home Tools tab ───────────────────────────────────────────────────────────

class _HomeToolsTab extends StatefulWidget {
  final VoidCallback? onAddFiles;
  final VoidCallback onScan;
  final VoidCallback onConvert;
  final VoidCallback onMerge;
  final VoidCallback onSplit;
  final VoidCallback onCompress;
  final VoidCallback onExtract;
  final VoidCallback onFormat;
  final VoidCallback onMetadata;
  final VoidCallback onProtect;
  final VoidCallback onWatermark;
  final VoidCallback onPageManager;

  const _HomeToolsTab({
    required this.onAddFiles,
    required this.onScan,
    required this.onConvert,
    required this.onMerge,
    required this.onSplit,
    required this.onCompress,
    required this.onExtract,
    required this.onFormat,
    required this.onMetadata,
    required this.onProtect,
    required this.onWatermark,
    required this.onPageManager,
  });

  @override
  State<_HomeToolsTab> createState() => _HomeToolsTabState();
}

class _HomeToolsTabState extends State<_HomeToolsTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final List<Animation<double>> _anims = [];

  static const _itemCount = 20;
  static const _delay = Duration(milliseconds: 40);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: Duration(milliseconds: 300 + _itemCount * _delay.inMilliseconds),
      vsync: this,
    );
    for (int i = 0; i < _itemCount; i++) {
      final start = (i * _delay.inMilliseconds) /
          _ctrl.duration!.inMilliseconds;
      _anims.add(CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, (start + 0.3).clamp(0.0, 1.0),
            curve: Curves.easeOut),
      ));
    }
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _fade(int index, Widget child) => FadeTransition(
        opacity: index < _anims.length ? _anims[index] : const AlwaysStoppedAnimation(1.0),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return ToolsListView(
      entries: ToolsCatalog.filtered(homeTabOnly: true),
      dividerHeight: 20,
      actions: {
        ToolId.scan: widget.onScan,
        ToolId.convert: widget.onConvert,
        ToolId.importFiles: widget.onAddFiles,
        ToolId.merge: widget.onMerge,
        ToolId.split: widget.onSplit,
        ToolId.compress: widget.onCompress,
        ToolId.formatConverter: widget.onFormat,
        ToolId.extractText: widget.onExtract,
        ToolId.pageManager: widget.onPageManager,
        ToolId.watermark: widget.onWatermark,
        ToolId.passwordProtect: widget.onProtect,
        ToolId.editMetadata: widget.onMetadata,
      },
      wrapChild: (child, index) => _fade(index, child),
    );
  }
}

// ─── Document grid / list ─────────────────────────────────────────────────────

class _DocumentGrid extends ConsumerStatefulWidget {
  final Future<void> Function(String) onDocumentTap;
  final Future<void> Function(String) onDocumentDelete;
  final Future<void> Function(List<String> paths) onImportDropped;
  final VoidCallback onScan;
  final VoidCallback onImport;

  const _DocumentGrid({
    required this.onDocumentTap,
    required this.onDocumentDelete,
    required this.onImportDropped,
    required this.onScan,
    required this.onImport,
  });

  @override
  ConsumerState<_DocumentGrid> createState() => _DocumentGridState();
}

class _DocumentGridState extends ConsumerState<_DocumentGrid> {
  _SortMode _sortMode = _SortMode.recent;
  bool _isGridView = true;
  String _search = '';
  String _filterType = 'all'; // 'all' | 'pdf' | 'image'
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> docs) {
    var list = docs.where((d) {
      final name = (d['name'] as String? ?? '').toLowerCase();
      final ext = name.split('.').last;
      // Search filter
      if (_search.isNotEmpty &&
          !name.contains(_search.toLowerCase())) {
        return false;
      }
      // Type filter
      if (_filterType == 'pdf' && ext != 'pdf') { return false; }
      if (_filterType == 'image' &&
          !['jpg', 'jpeg', 'png', 'bmp', 'webp'].contains(ext)) { return false; }
      return true;
    }).toList();

    switch (_sortMode) {
      case _SortMode.recent:
        // DB already returns is_favourite DESC, lastOpened DESC
        break;
      case _SortMode.name:
        list.sort((a, b) =>
            (a['name'] as String? ?? '')
                .toLowerCase()
                .compareTo((b['name'] as String? ?? '').toLowerCase()));
        break;
      case _SortMode.size:
        list.sort((a, b) =>
            (b['size'] as int? ?? 0).compareTo(a['size'] as int? ?? 0));
        break;
      case _SortMode.added:
        list.sort((a, b) => (b['dateAdded'] as String? ?? '')
            .compareTo(a['dateAdded'] as String? ?? ''));
        break;
    }
    return list;
  }

  Future<void> _renameDoc(String path, String name) async {
    final ext =
        name.contains('.') ? name.substring(name.lastIndexOf('.')) : '';
    final nameWithoutExt =
        ext.isNotEmpty ? name.substring(0, name.lastIndexOf('.')) : name;
    final controller = TextEditingController(text: nameWithoutExt);

    final String? newBaseName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'New name',
            suffixText: ext,
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Rename')),
        ],
      ),
    );

    controller.dispose();
    if (newBaseName == null ||
        newBaseName.isEmpty ||
        newBaseName == nameWithoutExt) {
      return;
    }

    try {
      final file = File(path);
      final newPath = '${file.parent.path}/$newBaseName$ext';
      await file.rename(newPath);
      await ref.read(documentDatabaseProvider).updatePath(path, newPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Rename failed: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);

    return docsAsync.when(
      loading: () => _buildSkeletonLoading(context),
      error: (e, _) => Center(child: Text('Could not load documents: $e')),
      data: (docs) => DesktopDropZone(
        onFilesDropped: widget.onImportDropped,
        child: _buildDocumentList(context, docs),
      ),
    );
  }

  Widget _buildSkeletonLoading(BuildContext context) {
    final mockCount = _isGridView ? 6 : 8;
    final mockDocs = _skeletonMockDocs(mockCount);

    void noop() {}

    return Skeletonizer(
      enabled: true,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: TextField(
                enabled: false,
                decoration: InputDecoration(
                  hintText: 'Search documents…',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Row(
                children: [
                  _FilterChip(label: 'All', selected: true, onTap: noop),
                  const SizedBox(width: 6),
                  _FilterChip(label: 'PDF', selected: false, onTap: noop),
                  const SizedBox(width: 6),
                  _FilterChip(label: 'Image', selected: false, onTap: noop),
                ],
              ),
            ),
          ),
          if (_isGridView)
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final cols = _gridCrossAxisCount(constraints.crossAxisExtent);
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _DocCard(
                        doc: mockDocs[i],
                        onTap: noop,
                        onDelete: noop,
                        onRename: noop,
                        onToggleFavourite: noop,
                      ),
                      childCount: mockDocs.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: _gridChildAspectRatio(cols),
                    ),
                  ),
                );
              },
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 96),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _DocListItem(
                    doc: mockDocs[i],
                    onTap: noop,
                    onDelete: noop,
                    onRename: noop,
                  ),
                  childCount: mockDocs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentList(
      BuildContext context, List<Map<String, dynamic>> docs) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered(docs);

    return CustomScrollView(
      slivers: [
        // ── Search bar ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search documents…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ),

        // ── Filter chips + sort/view-toggle ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(
              children: [
                _FilterChip(
                    label: 'All',
                    selected: _filterType == 'all',
                    onTap: () => setState(() => _filterType = 'all')),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'PDF',
                    selected: _filterType == 'pdf',
                    onTap: () => setState(() => _filterType = 'pdf')),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Image',
                    selected: _filterType == 'image',
                    onTap: () => setState(() => _filterType = 'image')),
                const Spacer(),
                PopupMenuButton<_SortMode>(
                  tooltip: 'Sort',
                  icon: Icon(Icons.sort, size: 20, color: cs.onSurfaceVariant),
                  initialValue: _sortMode,
                  onSelected: (mode) => setState(() => _sortMode = mode),
                  itemBuilder: (_) => [
                    _sortItem(_SortMode.recent, Icons.access_time,
                        'Recently opened'),
                    _sortItem(_SortMode.added, Icons.calendar_today,
                        'Date added'),
                    _sortItem(_SortMode.name, Icons.sort_by_alpha, 'Name'),
                    _sortItem(_SortMode.size, Icons.data_usage, 'File size'),
                  ],
                ),
                IconButton(
                  tooltip: _isGridView ? 'List view' : 'Grid view',
                  icon: Icon(
                    _isGridView ? Icons.view_list : Icons.grid_view,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                  onPressed: () =>
                      setState(() => _isGridView = !_isGridView),
                ),
              ],
            ),
          ),
        ),

        if (filtered.isEmpty)
          SliverFillRemaining(
            child: _buildEmpty(
              context,
              onScan: widget.onScan,
              onImport: widget.onImport,
            ),
          )
        else if (_isGridView)
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final cols = _gridCrossAxisCount(constraints.crossAxisExtent);
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      if (AdService.shouldShowAds && (i + 1) % 9 == 0) {
                        return const _NativeAdCard();
                      }
                      final docIndex = AdService.shouldShowAds ? i - (i ~/ 9) : i;
                      if (docIndex >= filtered.length) return const SizedBox.shrink();
                      
                      return _DocCard(
                        doc: filtered[docIndex],
                        onTap: () =>
                            widget.onDocumentTap(filtered[docIndex]['path'] ?? ''),
                        onDelete: () =>
                            widget.onDocumentDelete(filtered[docIndex]['path'] ?? ''),
                        onRename: () => _renameDoc(
                            filtered[docIndex]['path'] ?? '', filtered[docIndex]['name'] ?? ''),
                        onToggleFavourite: () => ref
                            .read(documentDatabaseProvider)
                            .toggleFavourite(filtered[docIndex]['path'] ?? ''),
                      );
                    },
                    childCount: AdService.shouldShowAds ? filtered.length + (filtered.length ~/ 8) : filtered.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: _gridChildAspectRatio(cols),
                  ),
                ),
              );
            },
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 96),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  if (AdService.shouldShowAds && (i + 1) % 9 == 0) {
                    return const SizedBox(height: 80, child: _NativeAdCard());
                  }
                  final docIndex = AdService.shouldShowAds ? i - (i ~/ 9) : i;
                  if (docIndex >= filtered.length) return const SizedBox.shrink();
                  
                  return _DocListItem(
                    doc: filtered[docIndex],
                    onTap: () =>
                        widget.onDocumentTap(filtered[docIndex]['path'] ?? ''),
                    onDelete: () =>
                        widget.onDocumentDelete(filtered[docIndex]['path'] ?? ''),
                    onRename: () => _renameDoc(
                        filtered[docIndex]['path'] ?? '', filtered[docIndex]['name'] ?? ''),
                  );
                },
                childCount: AdService.shouldShowAds ? filtered.length + (filtered.length ~/ 8) : filtered.length,
              ),
            ),
          ),
      ],
    );
  }

  PopupMenuItem<_SortMode> _sortItem(
      _SortMode mode, IconData icon, String label) {
    final selected = _sortMode == mode;
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : null),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal)),
          if (selected) ...[
            const Spacer(),
            Icon(Icons.check,
                size: 16,
                color: Theme.of(context).colorScheme.primary),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(
    BuildContext context, {
    required VoidCallback onScan,
    required VoidCallback onImport,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.picture_as_pdf_outlined,
                  size: 48, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text('No documents yet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Scan a document or import files to get started',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 260,
              child: FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: const Text('Scan Document'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 260,
              child: OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.folder_open_outlined, size: 20),
                label: const Text('Import Files'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Grid card ────────────────────────────────────────────────────────────────

class _DocCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback onToggleFavourite;

  const _DocCard({
    required this.doc,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
    required this.onToggleFavourite,
  });

  String get _name => doc['name'] as String? ?? 'Unknown';
  int get _size => (doc['size'] as int?) ?? 0;
  String? get _thumbPath => doc['thumbnail_path'] as String?;
  String get _ext => _name.split('.').last.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showOptions(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: docThumbHeroTag(doc['path'] as String? ?? ''),
                    flightShuttleBuilder: docThumbHeroFlightShuttle,
                    child: Container(
                      color: cs.surfaceContainerHighest,
                      child: _buildThumbImage(cs),
                    ),
                  ),
                  // Favourite star
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: onToggleFavourite,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            (doc['is_favourite'] as int? ?? 0) == 1
                                ? Icons.star
                                : Icons.star_border,
                            color: (doc['is_favourite'] as int? ?? 0) == 1
                                ? Colors.amber
                                : Colors.white.withValues(alpha: 0.8),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // File type badge
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _ext,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  // Options button
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showOptions(context),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.more_vert,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        _fmtSize(_size),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '·',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _relativeDate(doc['lastOpened'] as String?),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
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

  Widget _buildThumbImage(ColorScheme cs) {
    final isPdf = _ext == 'PDF';
    if (_thumbPath != null) {
      return Image.file(
        File(_thumbPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(
            isPdf ? Icons.picture_as_pdf : Icons.image,
            size: 48,
            color: isPdf ? cs.error : Colors.green,
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        isPdf ? Icons.picture_as_pdf : Icons.image,
        size: 48,
        color: isPdf ? cs.error : Colors.green,
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Details'),
              onTap: () {
                Navigator.pop(context);
                _showFileDetails(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                ShareService.files(
                  [XFile(doc['path'] as String)],
                  subject: _name,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                onRename();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete file?'),
                    content: Text(
                        '"$_name" will be permanently deleted from your device.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirmed == true) onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFileDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FileDetailsSheet(doc: doc),
    );
  }
}

// ─── List item ────────────────────────────────────────────────────────────────

class _DocListItem extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _DocListItem({
    required this.doc,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  String get _name => doc['name'] as String? ?? 'Unknown';
  int get _size => (doc['size'] as int?) ?? 0;
  String? get _thumbPath => doc['thumbnail_path'] as String?;
  String get _ext => _name.split('.').last.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPdf = _ext == 'PDF';

    return Dismissible(
      key: Key(doc['path'] as String? ?? _name),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: Colors.red,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete file?'),
            content: Text(
                '"$_name" will be permanently deleted from your device.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 44,
            height: 56,
            child: _thumbPath != null
                ? Image.file(
                    File(_thumbPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(
                        isPdf ? Icons.picture_as_pdf : Icons.image,
                        size: 24,
                        color: isPdf ? cs.error : Colors.green,
                      ),
                    ),
                  )
                : Container(
                    color: cs.surfaceContainerHighest,
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.image,
                      size: 24,
                      color: isPdf ? cs.error : Colors.green,
                    ),
                  ),
          ),
        ),
        title: Text(
          _name,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(_ext,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant)),
            ),
            const SizedBox(width: 6),
            Text(_fmtSize(_size),
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(width: 6),
            Text('·', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _relativeDate(doc['lastOpened'] as String?),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[500]),
          onSelected: (v) {
            switch (v) {
              case 'open':
                onTap();
                break;
              case 'share':
                ShareService.files(
                  [XFile(doc['path'] as String)],
                  subject: _name,
                );
                break;
              case 'rename':
                onRename();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'open',
                child: ListTile(
                    dense: true,
                    leading: Icon(Icons.open_in_new, size: 18),
                    title: Text('Open'))),
            const PopupMenuItem(
                value: 'share',
                child: ListTile(
                    dense: true,
                    leading: Icon(Icons.share_outlined, size: 18),
                    title: Text('Share'))),
            const PopupMenuItem(
                value: 'rename',
                child: ListTile(
                    dense: true,
                    leading:
                        Icon(Icons.drive_file_rename_outline, size: 18),
                    title: Text('Rename'))),
            const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                    dense: true,
                    leading: Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    title: Text('Delete',
                        style: TextStyle(color: Colors.red)))),
          ],
        ),
      ),
    );
  }

}

// ─── Filter chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final muted = AppColors.muted(brightness);
    final border = AppColors.border(brightness);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.amber.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.amber : border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.amber : muted,
          ),
        ),
      ),
    );
  }
}

// ─── File details bottom sheet ────────────────────────────────────────────────

class _FileDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> doc;
  const _FileDetailsSheet({required this.doc});

  @override
  State<_FileDetailsSheet> createState() => _FileDetailsSheetState();
}

class _FileDetailsSheetState extends State<_FileDetailsSheet> {
  int _pageCount = 0;
  bool _loadingPages = true;

  String get _path => widget.doc['path'] as String? ?? '';
  String get _name => widget.doc['name'] as String? ?? 'Unknown';
  String get _ext => _name.split('.').last.toLowerCase();

  @override
  void initState() {
    super.initState();
    if (_ext == 'pdf') {
      PDFManager.getPageCount(_path).then((count) {
        if (mounted) setState(() { _pageCount = count; _loadingPages = false; });
      });
    } else {
      _loadingPages = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = widget.doc['size'] as int? ?? 0;
    final thumbPath = widget.doc['thumbnail_path'] as String?;
    final lastOpened = widget.doc['lastOpened'] as String?;
    final dateAdded = widget.doc['dateAdded'] as String?;
    final title = widget.doc['title'] as String?;
    final author = widget.doc['author'] as String?;
    final subject = widget.doc['subject'] as String?;

    File? file;
    FileStat? stat;
    try {
      file = File(_path);
      stat = file.statSync();
    } catch (_) {}

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                // Thumbnail + name header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 72,
                        child: thumbPath != null
                            ? Image.file(File(thumbPath), fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    color: cs.surfaceContainerHighest,
                                    child: Icon(Icons.picture_as_pdf,
                                        color: cs.error)))
                            : Container(
                                color: cs.surfaceContainerHighest,
                                child: Icon(
                                  _ext == 'pdf'
                                      ? Icons.picture_as_pdf
                                      : Icons.image,
                                  color: _ext == 'pdf' ? cs.error : Colors.green,
                                )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(_fmtSize(size),
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 12)),
                          if (!_loadingPages && _pageCount > 0)
                            Text('$_pageCount pages',
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                // File path
                _DetailRow(
                  label: 'Path',
                  value: _path,
                  copyable: true,
                  cs: cs,
                ),
                // Dates
                if (dateAdded != null)
                  _DetailRow(
                    label: 'Added',
                    value: _formatDate(dateAdded),
                    cs: cs,
                  ),
                if (lastOpened != null)
                  _DetailRow(
                    label: 'Last opened',
                    value: _formatDate(lastOpened),
                    cs: cs,
                  ),
                if (stat != null)
                  _DetailRow(
                    label: 'Modified',
                    value: _formatDate(stat.modified.toIso8601String()),
                    cs: cs,
                  ),
                // PDF metadata
                if (title != null && title.isNotEmpty) ...[
                  const Divider(),
                  _DetailRow(label: 'Title', value: title, cs: cs),
                ],
                if (author != null && author.isNotEmpty)
                  _DetailRow(label: 'Author', value: author, cs: cs),
                if (subject != null && subject.isNotEmpty)
                  _DetailRow(label: 'Subject', value: subject, cs: cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  final ColorScheme cs;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.cs,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12),
                softWrap: true),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ));
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child:
                    Icon(Icons.copy, size: 15, color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Import progress pill ─────────────────────────────────────────────────────

class _ImportProgressPill extends StatelessWidget {
  final int done;
  final int total;

  const _ImportProgressPill({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = total > 0 ? done / total : 0.0;

    return Material(
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(28),
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                value: progress > 0 ? progress : null,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Importing files…',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      minHeight: 3,
                      backgroundColor: cs.surfaceContainerHighest,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$done / $total',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NativeAdCard extends StatefulWidget {
  const _NativeAdCard();
  @override
  State<_NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<_NativeAdCard> {
  StartAppNativeAd? _ad;

  @override
  void initState() {
    super.initState();
    if (AdService.shouldShowAds) {
      AdService().sdk.loadNativeAd().then((ad) {
        if (mounted) setState(() => _ad = ad);
      }).catchError((e) {
        debugPrint('Failed to load native ad: $e');
      });
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ad == null) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }
    return StartAppNative(
      _ad!,
      (context, setState, nativeAd) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: nativeAd.imageUrl != null
                    ? Image.network(nativeAd.imageUrl!, fit: BoxFit.cover)
                    : const Icon(Icons.ad_units, color: Colors.grey),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                      child: const Text('AD', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                    const SizedBox(height: 4),
                    Text(nativeAd.title ?? 'Advertisement', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    if (nativeAd.description != null)
                      Text(nativeAd.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

