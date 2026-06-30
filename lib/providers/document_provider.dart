import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_pdf/services/document_database.dart';

/// Provides the shared [DocumentDatabase] instance and wires cache
/// invalidation for [documentsProvider].
final documentDatabaseProvider = Provider<DocumentDatabase>((ref) {
  final db = DocumentDatabase();
  db.onDocumentsChanged = () {
    ref.invalidate(documentsProvider);
  };
  ref.onDispose(() {
    db.onDocumentsChanged = null;
  });
  return db;
});

/// Async document list for the home screen and other consumers.
class DocumentsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    ref.watch(documentDatabaseProvider);
    return ref.read(documentDatabaseProvider).getAllDocuments();
  }
}

final documentsProvider =
    AsyncNotifierProvider<DocumentsNotifier, List<Map<String, dynamic>>>(
  DocumentsNotifier.new,
);
