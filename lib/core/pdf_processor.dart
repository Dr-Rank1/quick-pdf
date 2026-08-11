import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;

/// Message types for isolate communication
class PdfProcessorMessage {
  final int id;
  final dynamic data;
  final SendPort responsePort;

  PdfProcessorMessage(this.id, this.data, this.responsePort);
}

class PdfProcessorResponse {
  final int id;
  final dynamic result;
  final dynamic error;

  PdfProcessorResponse(this.id, this.result, this.error);
}

/// Isolate entry point for PDF processing
void pdfProcessorEntryPoint(SendPort sendPort) {
  final ReceivePort receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) async {
    if (message == 'KILL') {
      receivePort.close();
      Isolate.current.kill(priority: Isolate.immediate);
      return;
    }
    if (message is PdfProcessorMessage) {
      try {
        dynamic result;
        switch (message.data['type']) {
          case 'convertImagesToPDF':
            result = await _convertImagesToPDFIsolate(
              (message.data['paths'] as List).cast<String>(),
              pageSize: message.data['pageSize'] as String? ?? 'A4',
              landscape: message.data['landscape'] as bool? ?? false,
              quality: message.data['quality'] as int? ?? 85,
              margin: (message.data['margin'] as num?)?.toDouble() ?? 20.0,
            );
            break;
          default:
            throw Exception('Unknown processing type: ${message.data['type']}');
        }
        message.responsePort
            .send(PdfProcessorResponse(message.id, result, null));
      } catch (e) {
        message.responsePort
            .send(PdfProcessorResponse(message.id, null, e.toString()));
      }
    }
  });
}

class PdfProcessorIsolate {
  final ReceivePort _receivePort = ReceivePort();
  final SendPort _sendPort;
  final Isolate _isolate;
  final Map<int, Completer<dynamic>> _completers = {};
  int _nextRequestId = 0;
  bool _killed = false;

  PdfProcessorIsolate._internal(this._sendPort, this._isolate) {
    _receivePort.listen((dynamic message) {
      if (message is PdfProcessorResponse) {
        final completer = _completers.remove(message.id);
        if (completer != null) {
          if (message.error != null) {
            completer.completeError(Exception(message.error));
          } else {
            completer.complete(message.result);
          }
        }
      }
    });
  }

  static Future<PdfProcessorIsolate> spawn() async {
    final ReceivePort handshake = ReceivePort();
    final isolate =
        await Isolate.spawn(pdfProcessorEntryPoint, handshake.sendPort);
    final SendPort sendPort = await handshake.first as SendPort;
    handshake.close();
    return PdfProcessorIsolate._internal(sendPort, isolate);
  }

  Future<dynamic> _sendMessage(dynamic data) async {
    if (_killed) {
      throw StateError('PdfProcessorIsolate has been killed');
    }
    final id = _nextRequestId++;
    final completer = Completer<dynamic>();
    _completers[id] = completer;
    _sendPort.send(PdfProcessorMessage(id, data, _receivePort.sendPort));
    return completer.future;
  }

  /// Converts images by path so the main isolate never holds all raw bytes.
  Future<List<int>> convertImagesToPDF(
    List<String> imagePaths, {
    String pageSize = 'A4',
    bool landscape = false,
    int quality = 85,
    double margin = 20.0,
  }) async {
    return await _sendMessage({
      'type': 'convertImagesToPDF',
      'paths': imagePaths,
      'pageSize': pageSize,
      'landscape': landscape,
      'quality': quality,
      'margin': margin,
    }) as List<int>;
  }

  Future<void> kill() async {
    if (_killed) return;
    _killed = true;
    try {
      _sendPort.send('KILL');
    } catch (_) {
      try {
        _isolate.kill(priority: Isolate.immediate);
      } catch (_) {}
    }
    _receivePort.close();
    for (final completer in _completers.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('PdfProcessorIsolate killed'));
      }
    }
    _completers.clear();
  }
}

pdf.PdfPageFormat _pageFormatFromName(String name) {
  switch (name) {
    case 'Letter':
      return pdf.PdfPageFormat.letter;
    case 'A3':
      return pdf.PdfPageFormat.a3;
    case 'Legal':
      return pdf.PdfPageFormat.legal;
    default:
      return pdf.PdfPageFormat.a4;
  }
}

/// Soft cap so phone photos (12MP+) don't OOM while decoding.
const int _kMaxDecodeEdge = 2500;

Future<List<int>> _convertImagesToPDFIsolate(
  List<String> imagePaths, {
  String pageSize = 'A4',
  bool landscape = false,
  int quality = 85,
  double margin = 20.0,
}) async {
  if (imagePaths.isEmpty) {
    throw Exception('No images to convert');
  }

  final target = pw.Document(compress: true);

  for (final path in imagePaths) {
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception('Image not found: $path');
    }

    // Read + decode one image at a time; release before the next.
    final Uint8List rawBytes = await file.readAsBytes();
    img.Image? original = img.decodeImage(rawBytes);
    if (original == null) {
      throw Exception('Failed to decode image: $path');
    }

    // Cap decode size early to avoid multi-megapixel RGBA spikes.
    final int longest = original.width > original.height
        ? original.width
        : original.height;
    if (longest > _kMaxDecodeEdge) {
      final scale = _kMaxDecodeEdge / longest;
      original = img.copyResize(
        original,
        width: (original.width * scale).round().clamp(1, _kMaxDecodeEdge),
        height: (original.height * scale).round().clamp(1, _kMaxDecodeEdge),
        interpolation: img.Interpolation.linear,
      );
    }

    final bool isFit = pageSize == 'fit';

    late pdf.PdfPageFormat format;
    if (isFit) {
      // PDF points ≈ CSS px for fit mode; keep page size reasonable.
      format = pdf.PdfPageFormat(
        original.width.toDouble(),
        original.height.toDouble(),
      );
    } else {
      format = _pageFormatFromName(pageSize);
      if (landscape) format = format.landscape;
    }

    final double availW = isFit ? format.width : format.width - 2 * margin;
    final double availH = isFit ? format.height : format.height - 2 * margin;
    if (availW <= 0 || availH <= 0) {
      throw Exception('Margins are too large for the selected page size');
    }

    final double scaleX = availW / original.width;
    final double scaleY = availH / original.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;
    final double displayW = original.width * scale;
    final double displayH = original.height * scale;

    // ~144 DPI equivalent for the display size.
    final int targetPx = (displayW * 2).round().clamp(1, _kMaxDecodeEdge);
    final int targetPy = (displayH * 2).round().clamp(1, _kMaxDecodeEdge);

    final img.Image source =
        (original.width > targetPx || original.height > targetPy)
            ? img.copyResize(
                original,
                width: targetPx,
                height: targetPy,
                interpolation: img.Interpolation.linear,
              )
            : original;

    final Uint8List encoded =
        Uint8List.fromList(img.encodeJpg(source, quality: quality.clamp(20, 95)));

    target.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.all(isFit ? 0 : margin),
        build: (_) => pw.Center(
          child: pw.Image(
            pw.MemoryImage(encoded),
            width: displayW,
            height: displayH,
          ),
        ),
      ),
    );
  }

  return await target.save();
}
