import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class DocumentDatabase {
  static DocumentDatabase? _instance;
  factory DocumentDatabase() => _instance ??= DocumentDatabase._internal();
  DocumentDatabase._internal();

  static Database? _database;
  Future<void>? _orphanPruneFuture;

  /// Called after any mutation so Riverpod can refresh [documentsProvider].
  VoidCallback? onDocumentsChanged;

  void _notifyChanged() => onDocumentsChanged?.call();

  /// Awaits any in-flight background orphan prune (for tests).
  @visibleForTesting
  Future<void> awaitOrphanPrune() async {
    await _orphanPruneFuture;
  }

  void _scheduleOrphanPrune() {
    _orphanPruneFuture =
        (_orphanPruneFuture ?? Future.value()).then((_) => _pruneOrphans());
  }

  Future<void> _pruneOrphans() async {
    final db = await database;
    final all = await db.query('documents');
    final orphaned = <String>[];

    for (final doc in all) {
      final path = doc['path'] as String?;
      if (path == null) continue;
      if (!await File(path).exists()) {
        orphaned.add(path);
      }
    }

    if (orphaned.isEmpty) return;

    final batch = db.batch();
    for (final path in orphaned) {
      batch.delete('documents', where: 'path = ?', whereArgs: [path]);
    }
    await batch.commit(noResult: true);
    _notifyChanged();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Closes the open database so widget/unit tests can start with a clean DB.
  @visibleForTesting
  static Future<void> resetForTesting() async {
    await _instance?.awaitOrphanPrune();
    await _database?.close();
    _database = null;
    _instance?._orphanPruneFuture = null;
    _instance?.onDocumentsChanged = null;
    _instance = null;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'documents.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        size INTEGER,
        text_content TEXT,
        thumbnail_path TEXT,
        is_favourite INTEGER NOT NULL DEFAULT 0,
        dateAdded TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        lastOpened TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE documents ADD COLUMN text_content TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE documents ADD COLUMN thumbnail_path TEXT');
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE documents ADD COLUMN is_favourite INTEGER NOT NULL DEFAULT 0');
    }
  }

  /// Removes cached thumbnail PNGs that are no longer referenced by any document.
  /// Age alone must not delete thumbs still pointed to by the library.
  Future<void> cleanupStaleThumbnails({
    Duration maxAge = const Duration(days: 30),
  }) async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final thumbDir = Directory('${cacheDir.path}/thumbnails');
      if (!await thumbDir.exists()) return;

      final db = await database;
      final rows = await db.query('documents', columns: ['thumbnail_path', 'path']);
      final referenced = <String>{};
      for (final row in rows) {
        final thumb = row['thumbnail_path'] as String?;
        if (thumb != null && thumb.isNotEmpty) {
          referenced.add(thumb);
        }
        final docPath = row['path'] as String?;
        if (docPath != null) {
          final key = sha1.convert(utf8.encode(docPath)).toString();
          referenced.add('${thumbDir.path}/thumb_$key.png');
          // Legacy hashCode keys from older builds.
          referenced.add(
              '${thumbDir.path}/thumb_${docPath.hashCode.abs()}.png');
        }
      }

      final cutoff = DateTime.now().subtract(maxAge);
      await for (final entity in thumbDir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (!entity.path.toLowerCase().endsWith('.png')) continue;

        final isOrphan = !referenced.contains(entity.path);
        if (!isOrphan) continue;

        // Optional: only delete orphans older than maxAge to avoid racing
        // a thumb that was just written but not yet referenced.
        final stat = await entity.stat();
        final lastUsed = stat.accessed.isAfter(stat.modified)
            ? stat.accessed
            : stat.modified;
        if (lastUsed.isBefore(cutoff)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {
      // Never block startup on cache cleanup failures.
    }
  }

  Future<void> insertDocument(String path,
      {String? textContent, String? thumbnailPath}) async {
    final db = await database;
    final File file = File(path);
    final existing = await db.query(
      'documents',
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );

    final row = <String, Object?>{
      'path': path,
      'name': basename(file.path),
      'size': await file.length(),
      'lastOpened': DateTime.now().toIso8601String(),
    };

    if (existing.isEmpty) {
      row['text_content'] = textContent;
      row['thumbnail_path'] = thumbnailPath;
      row['is_favourite'] = 0;
      row['dateAdded'] = DateTime.now().toIso8601String();
    } else {
      final prev = existing.first;
      // Preserve favourites and dateAdded on re-import of the same path.
      row['is_favourite'] = prev['is_favourite'] ?? 0;
      row['dateAdded'] =
          prev['dateAdded'] ?? DateTime.now().toIso8601String();
      row['text_content'] =
          textContent ?? prev['text_content'];
      row['thumbnail_path'] =
          thumbnailPath ?? prev['thumbnail_path'];
    }

    await db.insert(
      'documents',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notifyChanged();
  }

  Future<List<Map<String, dynamic>>> getAllDocuments() async {
    final db = await database;
    final all = await db.query('documents',
        orderBy: 'is_favourite DESC, lastOpened DESC');
    _scheduleOrphanPrune();
    return all;
  }

  Future<void> toggleFavourite(String path) async {
    final db = await database;
    final doc = await getDocument(path);
    if (doc == null) return;
    final current = (doc['is_favourite'] as int?) ?? 0;
    await db.update(
      'documents',
      {'is_favourite': current == 0 ? 1 : 0},
      where: 'path = ?',
      whereArgs: [path],
    );
    _notifyChanged();
  }

  Future<void> clearThumbnailPaths() async {
    final db = await database;
    await db.update('documents', {'thumbnail_path': null});
    _notifyChanged();
  }

  Future<Map<String, dynamic>?> getDocument(String path) async {
    final db = await database;
    final results = await db.query(
      'documents',
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> searchDocuments(String query,
      {int limit = 50}) async {
    final db = await database;
    if (query.isEmpty) {
      return getAllDocuments();
    }
    final String searchQuery = '%$query%';
    final results = await db.query(
      'documents',
      where: 'name LIKE ? OR text_content LIKE ?',
      whereArgs: [searchQuery, searchQuery],
      orderBy: 'is_favourite DESC, lastOpened DESC',
      limit: limit,
    );
    _scheduleOrphanPrune();
    return results;
  }

  Future<void> updateLastOpened(String path) async {
    final db = await database;
    await db.update(
      'documents',
      {'lastOpened': DateTime.now().toIso8601String()},
      where: 'path = ?',
      whereArgs: [path],
    );
    _notifyChanged();
  }

  Future<void> updateTextContent(String path, String textContent) async {
    final db = await database;
    await db.update(
      'documents',
      {'text_content': textContent},
      where: 'path = ?',
      whereArgs: [path],
    );
    _notifyChanged();
  }

  Future<void> updatePath(String oldPath, String newPath) async {
    final db = await database;
    final File newFile = File(newPath);
    await db.update(
      'documents',
      {
        'path': newPath,
        'name': basename(newPath),
        'size': await newFile.length(),
      },
      where: 'path = ?',
      whereArgs: [oldPath],
    );
    _notifyChanged();
  }

  Future<void> deleteDocument(String path) async {
    final db = await database;
    await db.delete(
      'documents',
      where: 'path = ?',
      whereArgs: [path],
    );
    _notifyChanged();
  }
}
