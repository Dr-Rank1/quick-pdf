import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ScannerService {
  /// Returns a back-facing CameraDescription, or the first available camera.
  static Future<CameraDescription?> getBackCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return null;
      return cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
    } catch (_) {
      return null;
    }
  }

  /// Creates and initialises a CameraController at high resolution.
  static Future<CameraController?> createController(
      CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.jpeg,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
      return controller;
    } catch (_) {
      await controller.dispose();
      return null;
    }
  }

  /// Runs the document-enhancement pipeline in a Dart isolate so the UI
  /// stays fully responsive while processing a high-resolution photo.
  static Future<File> enhanceDocument(
    File imageFile, {
    bool blackAndWhite = false,
  }) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String outputPath =
        '${appDocDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final String resultPath = await compute(
      _enhancePipeline,
      {
        'inputPath': imageFile.path,
        'outputPath': outputPath,
        'bw': blackAndWhite,
      },
    );

    return File(resultPath);
  }

  /// Isolate entry point — pure Dart, no Flutter plugins.
  static String _enhancePipeline(Map<String, dynamic> params) {
    final String inputPath = params['inputPath'] as String;
    final String outputPath = params['outputPath'] as String;
    final bool blackAndWhite = params['bw'] as bool;

    final Uint8List bytes = File(inputPath).readAsBytesSync();

    if (!blackAndWhite) {
      // Colour mode: write the raw camera JPEG unchanged.
      // Any re-encoding through the image package risks desaturation depending
      // on the device/package version — the camera's own processing already
      // handles exposure, white-balance and sharpening correctly.
      File(outputPath).writeAsBytesSync(bytes);
      return outputPath;
    }

    // B&W mode: downsample first so high-res camera frames don't OOM.
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      File(outputPath).writeAsBytesSync(bytes);
      return outputPath;
    }

    const maxEdge = 2200;
    final longest =
        image.width > image.height ? image.width : image.height;
    if (longest > maxEdge) {
      final scale = maxEdge / longest;
      image = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }

    image = img.grayscale(image);
    image = img.normalize(image, min: 0, max: 255);
    image = img.contrast(image, contrast: 1.9);

    File(outputPath).writeAsBytesSync(img.encodeJpg(image, quality: 90));
    return outputPath;
  }
}
