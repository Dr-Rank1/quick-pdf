import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf_render_maintained/pdf_render.dart' as render;
import 'package:pdfx/pdfx.dart';
import 'package:quick_pdf/services/share_service.dart';
import 'package:quick_pdf/ui/widgets/doc_thumb_hero.dart';
import 'package:quick_pdf/utils/path_utils.dart';

class PDFViewerScreen extends StatefulWidget {
  final String pdfPath;
  final String? heroTag;

  const PDFViewerScreen({super.key, required this.pdfPath, this.heroTag});

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  late PdfController _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _nightMode = false;
  bool _showCounter = false;
  bool _documentReady = false;
  Timer? _counterTimer;

  // Thumbnails for the strip
  final Map<int, Uint8List> _thumbs = {};
  bool _thumbsLoading = false;

  String get _filename =>
      fileStem(widget.pdfPath);

  @override
  void initState() {
    super.initState();
    _pdfController = PdfController(
      document: PdfDocument.openFile(widget.pdfPath),
    );
  }

  @override
  void dispose() {
    _counterTimer?.cancel();
    _pdfController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      _showCounter = true;
    });
    _counterTimer?.cancel();
    _counterTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showCounter = false);
    });
  }

  Future<void> _loadThumbs() async {
    if (_thumbsLoading || _totalPages == 0) return;
    _thumbsLoading = true;
    try {
      final doc = await render.PdfDocument.openFile(widget.pdfPath);
      for (int i = 1; i <= _totalPages; i++) {
        final page = await doc.getPage(i);
        final rendered = await page.render(width: 80);
        final uiImage = await rendered.createImageIfNotAvailable();
        final bd =
            await uiImage.toByteData(format: ui.ImageByteFormat.png);
        uiImage.dispose();
        if (bd != null && mounted) {
          setState(() => _thumbs[i] = bd.buffer.asUint8List());
        }
        await Future.delayed(Duration.zero);
      }
      await doc.dispose();
    } catch (_) {}
    _thumbsLoading = false;
  }

  Future<void> _goToPage() async {
    final controller = TextEditingController();
    final int? page = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '1 – $_totalPages',
            suffixText: 'of $_totalPages',
            isDense: true,
          ),
          onSubmitted: (v) {
            final p = int.tryParse(v.trim());
            if (p != null && p >= 1 && p <= _totalPages) {
              Navigator.pop(context, p);
            }
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final p = int.tryParse(controller.text.trim());
              if (p != null && p >= 1 && p <= _totalPages) {
                Navigator.pop(context, p);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (page != null) {
      await _pdfController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _nightMode ? Colors.black : null,
      appBar: AppBar(
        backgroundColor: _nightMode ? Colors.black : null,
        foregroundColor: _nightMode ? Colors.white : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _filename,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                'Page $_currentPage of $_totalPages',
                style: TextStyle(
                  fontSize: 12,
                  color: (_nightMode ? Colors.white : Theme.of(context).colorScheme.onSurface)
                      .withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        actions: [
          if (_totalPages > 1)
            IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              tooltip: 'Go to page',
              onPressed: _goToPage,
            ),
          IconButton(
            icon: Icon(_nightMode ? Icons.wb_sunny_outlined : Icons.nightlight_outlined),
            tooltip: _nightMode ? 'Day mode' : 'Night mode',
            onPressed: () => setState(() => _nightMode = !_nightMode),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── PDF view ──
          Hero(
            tag: widget.heroTag ?? docThumbHeroTag(widget.pdfPath),
            flightShuttleBuilder: docThumbHeroFlightShuttle,
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox.expand(
                child: ColoredBox(
                  color: _nightMode
                      ? Colors.black
                      : Theme.of(context).colorScheme.surface,
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: _documentReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: ColorFiltered(
            colorFilter: _nightMode
                ? const ColorFilter.matrix([
                    -1, 0, 0, 0, 255,
                    0, -1, 0, 0, 255,
                    0, 0, -1, 0, 255,
                    0,  0, 0, 1,   0,
                  ])
                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: PdfView(
              controller: _pdfController,
              scrollDirection: Axis.vertical,
              pageSnapping: false,
              onPageChanged: _onPageChanged,
              onDocumentLoaded: (doc) {
                setState(() {
                  _totalPages = doc.pagesCount;
                  _documentReady = true;
                });
                _loadThumbs();
              },
              onDocumentError: (error) =>
                  debugPrint('PDF viewer error: $error'),
            ),
          ),
          ),

          // ── Floating page counter ──
          if (_totalPages > 1)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showCounter ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$_currentPage / $_totalPages',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),

          // ── Navigation arrows ──
          if (_totalPages > 1)
            Positioned(
              bottom: _totalPages > 1 ? 100 : 20,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavButton(
                    icon: Icons.keyboard_arrow_up,
                    enabled: _currentPage > 1,
                    onTap: () => _pdfController.animateToPage(
                      _currentPage - 1,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _NavButton(
                    icon: Icons.keyboard_arrow_down,
                    enabled: _currentPage < _totalPages,
                    onTap: () => _pdfController.animateToPage(
                      _currentPage + 1,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ],
              ),
            ),

          // ── Thumbnail strip ──
          if (_totalPages > 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ThumbnailStrip(
                totalPages: _totalPages,
                currentPage: _currentPage,
                thumbs: _thumbs,
                nightMode: _nightMode,
                onPageTap: (p) => _pdfController.animateToPage(
                  p,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    try {
      await ShareService.files(
        [XFile(widget.pdfPath)],
        subject: _filename,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ── Thumbnail strip ───────────────────────────────────────────────────────────

class _ThumbnailStrip extends StatefulWidget {
  final int totalPages;
  final int currentPage;
  final Map<int, Uint8List> thumbs;
  final bool nightMode;
  final void Function(int page) onPageTap;

  const _ThumbnailStrip({
    required this.totalPages,
    required this.currentPage,
    required this.thumbs,
    required this.nightMode,
    required this.onPageTap,
  });

  @override
  State<_ThumbnailStrip> createState() => _ThumbnailStripState();
}

class _ThumbnailStripState extends State<_ThumbnailStrip> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(_ThumbnailStrip old) {
    super.didUpdateWidget(old);
    if (widget.currentPage != old.currentPage) {
      _scrollToPage(widget.currentPage);
    }
  }

  void _scrollToPage(int page) {
    final offset = (page - 1) * 68.0;
    if (_scroll.hasClients) {
      _scroll.animateTo(
        offset.clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.nightMode
        ? Colors.black87
        : Colors.black.withValues(alpha: 0.75);
    return Container(
      height: 80,
      color: bg,
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: widget.totalPages,
        itemBuilder: (_, i) {
          final page = i + 1;
          final isActive = page == widget.currentPage;
          final bytes = widget.thumbs[page];
          return GestureDetector(
            onTap: () => widget.onPageTap(page),
            child: Container(
              width: 52,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive ? Colors.white : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (bytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.memory(bytes, fit: BoxFit.cover),
                    )
                  else
                    Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: Text(
                          '$page',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10),
                        ),
                      ),
                    ),
                  if (isActive)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                          color: Colors.white.withValues(alpha: 0.18)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Nav button ────────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.35,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
