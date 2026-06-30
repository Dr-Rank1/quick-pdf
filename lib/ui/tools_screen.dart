import 'package:flutter/material.dart';
import 'package:quick_pdf/router/app_navigation.dart';
import 'package:quick_pdf/services/ad_service.dart';
import 'package:quick_pdf/services/document_import_service.dart';
import 'package:quick_pdf/services/file_picker_service.dart';
import 'package:quick_pdf/ui/widgets/desktop_drop_zone.dart';
import 'package:quick_pdf/ui/widgets/tools_catalog.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  Map<ToolId, VoidCallback?> _actions(BuildContext context) => {
        ToolId.scan: () => context.pushScan(),
        ToolId.convert: () async {
          final r = await FilePickerService.pickMultipleFiles(
              allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp']);
          if (r == null || r.isEmpty || !context.mounted) return;
          context.pushConvert(r);
        },
        ToolId.merge: () async {
          final r = await FilePickerService.pickMultipleFiles(
              allowedExtensions: ['pdf']);
          if (r == null || r.isEmpty || !context.mounted) return;
          context.pushMerge(r);
        },
        ToolId.split: () async {
          final r = await FilePickerService.pickMultipleFiles(
              allowedExtensions: ['pdf']);
          if (r == null || r.isEmpty || !context.mounted) return;
          context.pushSplit(r.first);
        },
        ToolId.compress: () async {
          final r = await FilePickerService.pickMultipleFiles(
              allowedExtensions: ['pdf']);
          if (r == null || r.isEmpty || !context.mounted) return;
          context.pushCompress(r.first);
        },
        ToolId.formatConverter: () => context.pushFormatConverter(),
        ToolId.extractText: () async {
          final r = await FilePickerService.pickMultipleFiles(
            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'bmp', 'webp'],
          );
          if (r == null || r.isEmpty || !context.mounted) return;
          context.pushOcr(r.first);
        },
        ToolId.exportText: () => context.pushExportText(),
        ToolId.annotate: () => context.pushAnnotate(),
        ToolId.sign: () => context.pushSign(),
        ToolId.batch: () => context.pushBatch(),
        ToolId.pageManager: () async {
          final r = await FilePickerService.pickMultipleFiles(
              allowedExtensions: ['pdf']);
          if (r == null || r.isEmpty || !context.mounted) return;
          context.pushPageManager(r.first);
        },
        ToolId.watermark: () => context.pushWatermark(),
        ToolId.passwordProtect: () => context.pushPasswordProtect(),
        ToolId.editMetadata: () async {
          final r = await FilePickerService.pickMultipleFiles(
              allowedExtensions: ['pdf']);
          if (r == null || r.isEmpty || !context.mounted) return;
          context.pushEditMetadata(r.first);
        },
      };

  Future<void> _onDesktopDrop(BuildContext context, List<String> paths) async {
    final count = await DocumentImportService.instance.importPaths(paths);
    if (!context.mounted || count == 0) return;
    AdService().recordToolCompletion();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Imported $count file${count == 1 ? '' : 's'}'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: DesktopDropZone(
        onFilesDropped: (paths) => _onDesktopDrop(context, paths),
        child: ToolsListView(
          entries: ToolsCatalog.entries,
          actions: _actions(context),
          dividerHeight: 24,
        ),
      ),
    );
  }
}
