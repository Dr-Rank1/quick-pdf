import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quick_pdf/services/share_service.dart';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:quick_pdf/services/file_picker_service.dart';
import 'package:quick_pdf/services/ocr_service.dart';

class ExportTextScreen extends StatefulWidget {
  final File? initialFile;
  const ExportTextScreen({super.key, this.initialFile});

  @override
  State<ExportTextScreen> createState() => _ExportTextScreenState();
}

class _ExportTextScreenState extends State<ExportTextScreen> {
  File? _file;
  bool _isProcessing = false;
  int _progress = 0;
  int _total = 0;
  String _extractedText = '';
  final _textCtrl = TextEditingController();
  final _ocrService = OcrService();
  Future<void>? _ocrInflight;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _file = widget.initialFile;
      _extractText();
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    final pending = _ocrInflight;
    if (pending != null) {
      pending.whenComplete(_ocrService.dispose);
    } else {
      _ocrService.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFile() async {
    final files = await FilePickerService.pickMultipleFiles(
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    if (files == null || files.isEmpty) return;
    setState(() {
      _file = files.first;
      _extractedText = '';
      _textCtrl.clear();
    });
    _extractText();
  }

  Future<void> _extractText() async {
    if (_file == null) return;
    final op = _extractTextBody();
    _ocrInflight = op;
    try {
      await op;
    } finally {
      if (identical(_ocrInflight, op)) _ocrInflight = null;
    }
  }

  Future<void> _extractTextBody() async {
    setState(() { _isProcessing = true; _progress = 0; _total = 0; });
    try {
      final pages = await _ocrService.extractText(
        _file!,
        onProgress: (c, t) {
          if (mounted) setState(() { _progress = c; _total = t; });
        },
      );
      final text = pages.map((p) => p.text).join('\n\n---\n\n');
      if (mounted) {
        setState(() {
          _extractedText = text;
          _textCtrl.text = text;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('OCR failed: $e'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportTxt() async {
    final text = _textCtrl.text;
    if (text.isEmpty) { _snack('No text to export.'); return; }
    final dir = await getApplicationDocumentsDirectory();
    final stem = _file != null
        ? fileStem(_file!.path)
        : 'extract';
    final out = File('${dir.path}/${stem}_text.txt');
    await out.writeAsString(text);
    if (mounted) {
      await ShareService.files([XFile(out.path)],
          subject: '${stem}_text.txt');
    }
  }

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: _textCtrl.text));
    _snack('Copied to clipboard');
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Text'),
        actions: [
          if (_extractedText.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy all',
              onPressed: _copyAll,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Export .txt',
              onPressed: _exportTxt,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // File selector
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: ListTile(
                onTap: _isProcessing ? null : _pickFile,
                leading: Icon(Icons.picture_as_pdf, color: cs.error),
                title: Text(
                  _file != null
                      ? fileName(_file!.path)
                      : 'Tap to pick a PDF or image',
                  style: TextStyle(
                    fontWeight:
                        _file != null ? FontWeight.w600 : FontWeight.normal,
                    color: _file != null ? null : cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.folder_open_outlined),
              ),
            ),
          ),

          // Progress
          if (_isProcessing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                      value: _total > 0 ? _progress / _total : null),
                  const SizedBox(height: 4),
                  Text(
                    _total > 0
                        ? 'Scanning page $_progress of $_total…'
                        : 'Scanning…',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

          // Text editor
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: TextField(
                controller: _textCtrl,
                maxLines: null,
                expands: true,
                readOnly: _isProcessing,
                decoration: InputDecoration(
                  hintText: _file == null
                      ? 'Extracted text will appear here…'
                      : _isProcessing
                          ? 'Scanning…'
                          : 'Edit extracted text here',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
