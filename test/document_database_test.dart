import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_pdf/services/document_database.dart';

import 'test_helpers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
Future<File> _touchFile(Directory dir, String name) async {
  final f = File('${dir.path}/$name');
  await f.writeAsString('');
  return f;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  late Directory tmpDir;

  setUpAll(initTestDatabase);

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('qpdf_test_');
    await useTempDatabase(tmpDir);
  });

  tearDown(() async {
    await disposeTempDatabase(tmpDir);
  });

  group('DocumentDatabase', () {
    test('insert and fetch a document', () async {
      final db = DocumentDatabase();
      final f = await _touchFile(tmpDir, 'test.pdf');
      await db.insertDocument(f.path);

      final doc = await db.getDocument(f.path);
      expect(doc, isNotNull);
      expect(doc!['name'], equals('test.pdf'));
    });

    test('getAllDocuments returns rows immediately; background prunes orphans',
        () async {
      final db = DocumentDatabase();
      final real = await _touchFile(tmpDir, 'real.pdf');
      await db.insertDocument(real.path);

      final ghost = await _touchFile(tmpDir, 'ghost.pdf');
      await db.insertDocument(ghost.path);
      await ghost.delete();

      final docs = await db.getAllDocuments();
      expect(docs.map((d) => d['name']).toList(), contains('real.pdf'));
      expect(docs.map((d) => d['name']).toList(), contains('ghost.pdf'));

      await db.awaitOrphanPrune();
      final pruned = await db.getAllDocuments();
      expect(pruned.map((d) => d['name']).toList(), contains('real.pdf'));
      expect(pruned.map((d) => d['name']).toList(),
          isNot(contains('ghost.pdf')));
    });

    test('deleteDocument removes it from fetch', () async {
      final db = DocumentDatabase();
      final f = await _touchFile(tmpDir, 'del.pdf');
      await db.insertDocument(f.path);
      await db.deleteDocument(f.path);

      final doc = await db.getDocument(f.path);
      expect(doc, isNull);
    });

    test('toggleFavourite flips is_favourite', () async {
      final db = DocumentDatabase();
      final f = await _touchFile(tmpDir, 'fav.pdf');
      await db.insertDocument(f.path);

      await db.toggleFavourite(f.path);
      final after = await db.getDocument(f.path);
      expect(after!['is_favourite'], equals(1));

      await db.toggleFavourite(f.path);
      final reset = await db.getDocument(f.path);
      expect(reset!['is_favourite'], equals(0));
    });

    test('searchDocuments filters by name', () async {
      final db = DocumentDatabase();
      final a = await _touchFile(tmpDir, 'alpha.pdf');
      final b = await _touchFile(tmpDir, 'beta.pdf');
      await db.insertDocument(a.path);
      await db.insertDocument(b.path);

      final results = await db.searchDocuments('alpha');
      expect(results.length, equals(1));
      expect(results.first['name'], equals('alpha.pdf'));
    });
  });
}
