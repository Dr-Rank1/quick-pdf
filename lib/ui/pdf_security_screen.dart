import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quick_pdf/utils/path_utils.dart';
import 'package:quick_pdf/core/pdf_manager.dart';
import 'package:quick_pdf/services/document_database.dart';

class EditMetadataScreen extends StatefulWidget {
  final File pdfFile;

  const EditMetadataScreen({super.key, required this.pdfFile});

  @override
  State<EditMetadataScreen> createState() => _EditMetadataScreenState();
}

class _EditMetadataScreenState extends State<EditMetadataScreen> {
  bool _isProcessing = false;
  final _authorController = TextEditingController();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();

  bool get _hasChanges =>
      _authorController.text.isNotEmpty ||
      _titleController.text.isNotEmpty ||
      _subjectController.text.isNotEmpty;

  @override
  void dispose() {
    _authorController.dispose();
    _titleController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Metadata')),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf, color: cs.error),
                    title: Text(
                      fileName(widget.pdfFile.path),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _fmtSize(widget.pdfFile.lengthSync()),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Document Properties',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            prefixIcon: Icon(Icons.title),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _authorController,
                          decoration: const InputDecoration(
                            labelText: 'Author',
                            prefixIcon: Icon(Icons.person_outline),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _subjectController,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            prefixIcon: Icon(Icons.subject),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _hasChanges ? _applyMetadata : null,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Metadata', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
    );
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  Future<void> _applyMetadata() async {
    setState(() => _isProcessing = true);
    try {
      final updatedFile = await PDFManager.updatePDFMetadata(
        widget.pdfFile,
        author: _authorController.text.trim().isNotEmpty ? _authorController.text.trim() : null,
        title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
        subject: _subjectController.text.trim().isNotEmpty ? _subjectController.text.trim() : null,
      );
      final thumbPath = await PDFManager.generateThumbnail(updatedFile.path);
      await DocumentDatabase().insertDocument(updatedFile.path, thumbnailPath: thumbPath);
      if (mounted) {
        PDFManager.hapticFeedbackSuccess();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metadata saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        PDFManager.hapticFeedbackError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
        setState(() => _isProcessing = false);
      }
    }
  }
}
