import 'package:quick_pdf/services/error_logger.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:quick_pdf/services/scanner_service.dart';
import 'package:quick_pdf/router/app_navigation.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isProcessing = false;
  bool _bwMode = false;
  bool _flashOn = false;
  Offset? _focusPoint;
  final List<File> _pages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final controller = _controller;
      if (controller == null) return;
      // Clear before dispose so build never uses a disposed controller.
      _controller = null;
      _isInitialized = false;
      _flashOn = false;
      if (mounted) setState(() {});
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null) {
        _initCamera();
      }
    }
  }

  Future<void> _initCamera() async {
    final old = _controller;
    _controller = null;
    _isInitialized = false;
    await old?.dispose();

    final camera = await ScannerService.getBackCamera();
    if (camera == null || !mounted) return;

    final controller = await ScannerService.createController(camera);
    if (!mounted) {
      await controller?.dispose();
      return;
    }

    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open camera')),
      );
      return;
    }

    setState(() {
      _controller = controller;
      _isInitialized = true;
    });
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !_isInitialized ||
        _isCapturing ||
        _isProcessing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final XFile photo = await controller.takePicture();
      if (!mounted || !identical(_controller, controller)) return;
      setState(() => _isProcessing = true);

      final File enhanced = await ScannerService.enhanceDocument(
        File(photo.path),
        blackAndWhite: _bwMode,
      );

      // Delete the raw camera temp file
      try {
        await File(photo.path).delete();
      } catch (_) {}

      if (!mounted || !identical(_controller, controller)) return;
      setState(() {
        _pages.add(enhanced);
        _isCapturing = false;
        _isProcessing = false;
      });
      HapticFeedback.lightImpact();
    } catch (e, stack) {
      await ErrorLogger.log('scanner', e, stack);
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    try {
      final next = !_flashOn;
      await _controller!
          .setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _flashOn = next);
    } catch (_) {
      // Flash not supported on this device
    }
  }

  Future<void> _onPreviewTap(TapUpDetails details, BoxConstraints box) async {
    if (_controller == null || !_isInitialized) return;
    final Offset normalized = Offset(
      details.localPosition.dx / box.maxWidth,
      details.localPosition.dy / box.maxHeight,
    );
    try {
      await _controller!.setFocusPoint(normalized);
      await _controller!.setExposurePoint(normalized);
      setState(() => _focusPoint = details.localPosition);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) setState(() => _focusPoint = null);
    } catch (_) {}
  }

  Future<void> _deletePage(int index) async {
    final file = _pages[index];
    setState(() => _pages.removeAt(index));
    try { await file.delete(); } catch (_) {}
  }

  Future<void> _done() async {
    if (_pages.isEmpty || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final File pdfFile = await PDFManager.convertImagesToPDF(List.from(_pages));
      final thumbPath = await PDFManager.generateThumbnail(pdfFile.path);
      await DocumentDatabase().insertDocument(pdfFile.path, thumbnailPath: thumbPath);

      if (mounted) {
        context.replaceWithPdfViewer(pdfFile.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            if (_isInitialized && _controller != null)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (_, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _onPreviewTap(d, constraints),
                    child: CameraPreview(_controller!),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Document guide (corner marks)
            if (_isInitialized)
              const Positioned.fill(child: _DocumentGuide()),

            // Tap-to-focus indicator
            if (_focusPoint != null)
              Positioned(
                left: _focusPoint!.dx - 30,
                top: _focusPoint!.dy - 30,
                child: const _FocusRing(),
              ),

            // Top bar
            Positioned(
              top: 0, left: 0, right: 0,
              child: _buildTopBar(),
            ),

            // Bottom panel
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildBottomPanel(),
            ),

            // Processing overlay
            if (_isProcessing && !_isCapturing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('Enhancing...', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Cancel',
            onPressed: () async {
              for (final f in List<File>.from(_pages)) {
                try {
                  await f.delete();
                } catch (_) {}
              }
              _pages.clear();
              if (mounted) Navigator.of(context).pop();
            },
          ),
          const Spacer(),
          if (_pages.isNotEmpty)
            Text(
              '${_pages.length} page${_pages.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          const Spacer(),
          // B&W toggle
          IconButton(
            icon: Icon(
              Icons.filter_b_and_w,
              color: _bwMode ? Colors.lightBlueAccent : Colors.white54,
            ),
            tooltip: _bwMode ? 'B&W (on)' : 'B&W (off)',
            onPressed: () => setState(() => _bwMode = !_bwMode),
          ),
          // Flash toggle
          IconButton(
            icon: Icon(
              _flashOn ? Icons.flashlight_on : Icons.flashlight_off,
              color: _flashOn ? Colors.yellow : Colors.white54,
            ),
            tooltip: _flashOn ? 'Light on' : 'Light off',
            onPressed: _toggleFlash,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thumbnail strip
          if (_pages.isNotEmpty)
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _buildThumb(i),
              ),
            ),

          // Controls row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Page count badge / empty slot
                SizedBox(
                  width: 72,
                  child: _pages.isNotEmpty
                      ? _buildSaveButton()
                      : null,
                ),

                // Shutter button
                _buildShutterButton(),

                // Empty slot (symmetric layout)
                const SizedBox(width: 72),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShutterButton() {
    final busy = _isCapturing || _isProcessing;
    return GestureDetector(
      onTap: busy ? null : _capture,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: busy ? 64 : 72,
        height: busy ? 64 : 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: busy ? Colors.grey.shade600 : Colors.white,
          border: Border.all(
            color: busy ? Colors.grey : Colors.white70,
            width: 4,
          ),
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isProcessing ? null : _done,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      child: const Text('Save PDF', style: TextStyle(fontSize: 13)),
    );
  }

  Widget _buildThumb(int index) {
    return GestureDetector(
      onTap: () => _showPreview(index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 62,
            height: 74,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white38, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.file(_pages[index], fit: BoxFit.cover),
            ),
          ),
          // Page number badge
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
          // Delete button
          Positioned(
            top: -6,
            right: 2,
            child: GestureDetector(
              onTap: () => _deletePage(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPreview(int index) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.file(_pages[index]),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete page',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deletePage(index);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 8,
              child: Text(
                'Page ${index + 1} of ${_pages.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Overlay & indicators ─────────────────────────────────────────────────

class _DocumentGuide extends StatelessWidget {
  const _DocumentGuide();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GuidePainter());
  }
}

class _GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double mh = size.width * 0.07;
    final double mv = size.height * 0.14;
    const double arm = 28;

    final corners = [
      // top-left
      [Offset(mh, mv + arm), Offset(mh, mv), Offset(mh + arm, mv)],
      // top-right
      [Offset(size.width - mh - arm, mv), Offset(size.width - mh, mv), Offset(size.width - mh, mv + arm)],
      // bottom-left
      [Offset(mh, size.height - mv - arm), Offset(mh, size.height - mv), Offset(mh + arm, size.height - mv)],
      // bottom-right
      [
        Offset(size.width - mh - arm, size.height - mv),
        Offset(size.width - mh, size.height - mv),
        Offset(size.width - mh, size.height - mv - arm)
      ],
    ];

    for (final c in corners) {
      final path = Path()
        ..moveTo(c[0].dx, c[0].dy)
        ..lineTo(c[1].dx, c[1].dy)
        ..lineTo(c[2].dx, c[2].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _FocusRing extends StatefulWidget {
  const _FocusRing();

  @override
  State<_FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<_FocusRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween(begin: 1.4, end: 1.0).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeOut),
    );
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.yellow, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
