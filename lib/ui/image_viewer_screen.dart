import 'dart:io';

import 'package:flutter/material.dart';
import 'package:quick_pdf/services/share_service.dart';
import 'package:quick_pdf/utils/path_utils.dart';

/// Full-screen viewer for image documents in the library.
class ImageViewerScreen extends StatelessWidget {
  final String path;

  const ImageViewerScreen({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          fileName(path),
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () => ShareService.files(
              [XFile(path)],
              subject: fileName(path),
            ),
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 6.0,
        child: Center(child: Image.file(File(path))),
      ),
    );
  }
}
