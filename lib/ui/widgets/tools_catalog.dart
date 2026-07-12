import 'package:flutter/material.dart';

/// Identifies each tool entry in the catalog.
enum ToolId {
  scan,
  convert,
  importFiles,
  merge,
  split,
  compress,
  formatConverter,
  extractText,
  exportText,
  annotate,
  sign,
  batch,
  pageManager,
  watermark,
  passwordProtect,
  editMetadata,
}

/// A single tool row in the catalog.
class ToolEntry {
  final ToolId id;
  final String group;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool showOnHomeTab;

  const ToolEntry({
    required this.id,
    required this.group,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.showOnHomeTab = false,
  });
}

/// Shared catalog metadata for Home tools tab and Tools screen.
class ToolsCatalog {
  ToolsCatalog._();

  static const List<ToolEntry> entries = [
    ToolEntry(
      id: ToolId.scan,
      group: 'Create',
      icon: Icons.camera_alt,
      color: Color(0xFF1565C0),
      title: 'Scan Document',
      subtitle: 'Use your camera to scan pages into a PDF',
      showOnHomeTab: true,
    ),
    ToolEntry(
      id: ToolId.convert,
      group: 'Create',
      icon: Icons.image,
      color: Color(0xFF2E7D32),
      title: 'Images to PDF',
      subtitle: 'Combine JPG, PNG, WEBP photos into one PDF',
      showOnHomeTab: true,
    ),
    ToolEntry(
      id: ToolId.importFiles,
      group: 'Create',
      icon: Icons.folder_open_outlined,
      color: Colors.indigo,
      title: 'Import Files',
      subtitle: 'Add existing PDFs or images to your library',
      showOnHomeTab: true,
    ),
    ToolEntry(
      id: ToolId.merge,
      group: 'PDF Tools',
      icon: Icons.merge_type,
      color: Color(0xFFE65100),
      title: 'Merge PDFs',
      subtitle: 'Combine multiple PDFs, choose pages per document',
      showOnHomeTab: true,
    ),
    ToolEntry(
      id: ToolId.split,
      group: 'PDF Tools',
      icon: Icons.call_split,
      color: Color(0xFF7B1FA2),
      title: 'Split PDF',
      subtitle: 'Extract pages or split into individual files',
      showOnHomeTab: true,
    ),
    ToolEntry(
      id: ToolId.compress,
      group: 'PDF Tools',
      icon: Icons.compress,
      color: Color(0xFFC62828),
      title: 'Compress PDF',
      subtitle: 'Reduce file size with adjustable quality',
      showOnHomeTab: true,
    ),
    ToolEntry(
      id: ToolId.formatConverter,
      group: 'Convert & Extract',
      icon: Icons.swap_horiz,
      color: Colors.teal,
      title: 'Format Converter',
      subtitle: 'PDF → JPEG / PNG  ·  Images → PDF',
      showOnHomeTab: true,
    ),
    ToolEntry(
      id: ToolId.extractText,
      group: 'Convert & Extract',
      icon: Icons.text_snippet_outlined,
      color: Colors.indigo,
      title: 'Extract Text (OCR)',
      subtitle: 'Read text from PDFs and images — fully offline',
      showOnHomeTab: true,
    ),
    ToolEntry(
      id: ToolId.exportText,
      group: 'Convert & Extract',
      icon: Icons.text_fields,
      color: Colors.deepOrange,
      title: 'Export Text',
      subtitle: 'OCR all pages and export as .txt',
    ),
    ToolEntry(
      id: ToolId.annotate,
      group: 'Annotate & Sign',
      icon: Icons.draw_outlined,
      color: Colors.purple,
      title: 'Annotate PDF',
      subtitle: 'Draw on PDF pages with pen and highlighter',
    ),
    ToolEntry(
      id: ToolId.sign,
      group: 'Annotate & Sign',
      icon: Icons.draw,
      color: Color(0xFF2E7D32),
      title: 'Sign PDF',
      subtitle: 'Draw and place your signature on a PDF',
    ),
    ToolEntry(
      id: ToolId.batch,
      group: 'Batch',
      icon: Icons.playlist_add_check,
      color: Colors.amber,
      title: 'Batch Processing',
      subtitle: 'Apply one operation to multiple PDFs at once',
    ),
    ToolEntry(
      id: ToolId.pageManager,
      group: 'Organise',
      icon: Icons.view_module,
      color: Colors.pink,
      title: 'Page Manager',
      subtitle: 'Reorder, delete, and rotate PDF pages',
      showOnHomeTab: true,
    ),
    ToolEntry(
      id: ToolId.watermark,
      group: 'Organise',
      icon: Icons.water_drop_outlined,
      color: Colors.cyan,
      title: 'Watermark',
      subtitle: 'Add a text watermark to all pages',
      showOnHomeTab: true,
    ),
    ToolEntry(
      id: ToolId.passwordProtect,
      group: 'Security & Metadata',
      icon: Icons.lock_outline,
      color: Colors.blueGrey,
      title: 'Password Protect',
      subtitle: 'Encrypt a PDF or remove its password',
      showOnHomeTab: true,
    ),
    ToolEntry(
      id: ToolId.editMetadata,
      group: 'Security & Metadata',
      icon: Icons.edit_document,
      color: Colors.brown,
      title: 'Edit Metadata',
      subtitle: 'Set title, author, and subject of a PDF',
      showOnHomeTab: true,
    ),
  ];

  static List<ToolEntry> filtered({bool homeTabOnly = false}) {
    if (!homeTabOnly) return entries;
    return entries.where((e) => e.showOnHomeTab).toList();
  }

  static List<String> groupsFor(Iterable<ToolEntry> items) {
    final seen = <String>{};
    final result = <String>[];
    for (final entry in items) {
      if (seen.add(entry.group)) result.add(entry.group);
    }
    return result;
  }
}

/// Section header for a tool group.
class ToolGroupHeader extends StatelessWidget {
  final String title;

  const ToolGroupHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: muted,
        ),
      ),
    );
  }
}

/// Shared tool list tile used by Home and Tools screens.
class ToolListTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const ToolListTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final cs = Theme.of(context).colorScheme;
    final tileColor = enabled ? color : cs.onSurfaceVariant;
    final border = cs.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tileColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: tileColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: enabled ? cs.onSurface : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Builds a grouped tool list from catalog entries.
class ToolsListView extends StatelessWidget {
  final List<ToolEntry> entries;
  final Map<ToolId, VoidCallback?> actions;
  final Widget Function(Widget child, int animationIndex)? wrapChild;
  final double dividerHeight;

  const ToolsListView({
    super.key,
    required this.entries,
    required this.actions,
    this.wrapChild,
    this.dividerHeight = 20,
  });

  @override
  Widget build(BuildContext context) {
    final groups = ToolsCatalog.groupsFor(entries);
    final children = <Widget>[];
    var animIndex = 0;

    Widget wrap(Widget child) {
      if (wrapChild != null) return wrapChild!(child, animIndex++);
      return child;
    }

    Color colorFor(ToolEntry entry) {
      if (entry.id == ToolId.importFiles) {
        return Theme.of(context).colorScheme.primary;
      }
      return entry.color;
    }

    for (var gi = 0; gi < groups.length; gi++) {
      final group = groups[gi];
      if (gi > 0) {
        children.add(SizedBox(height: dividerHeight * 0.4));
      }
      children.add(wrap(ToolGroupHeader(title: group)));

      final groupEntries = entries.where((e) => e.group == group);
      for (final entry in groupEntries) {
        final action = actions[entry.id];
        children.add(
          wrap(
            ToolListTile(
              icon: entry.icon,
              color: colorFor(entry),
              title: entry.title,
              subtitle: entry.subtitle,
              onTap: action,
            ),
          ),
        );
      }
    }

    children.add(const SizedBox(height: 16));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      children: children,
    );
  }
}

