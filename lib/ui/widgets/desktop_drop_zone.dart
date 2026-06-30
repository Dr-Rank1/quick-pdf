import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quick_pdf/services/document_import_service.dart';

bool get supportsDesktopDrop =>
    !kIsWeb &&
    (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// Wraps [child] with a desktop drag-and-drop target when supported.
class DesktopDropZone extends StatefulWidget {
  final Widget child;
  final Future<void> Function(List<String> paths) onFilesDropped;

  const DesktopDropZone({
    super.key,
    required this.child,
    required this.onFilesDropped,
  });

  @override
  State<DesktopDropZone> createState() => _DesktopDropZoneState();
}

class _DesktopDropZoneState extends State<DesktopDropZone> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    if (!supportsDesktopDrop) return widget.child;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) async {
        setState(() => _dragging = false);
        final paths = details.files
            .map((file) => file.path)
            .where(DocumentImportService.isSupportedPath)
            .toList();
        if (paths.isNotEmpty) {
          await widget.onFilesDropped(paths);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_dragging)
            IgnorePointer(
              child: Container(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.file_download_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          const Text('Drop PDFs or images to import'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
