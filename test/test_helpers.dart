import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quick_pdf/services/document_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  FakePathProvider(this._tmp);

  final Directory _tmp;

  @override
  Future<String?> getApplicationDocumentsPath() async => _tmp.path;

  @override
  Future<String?> getTemporaryPath() async => _tmp.path;

  @override
  Future<String?> getApplicationCachePath() async => _tmp.path;

  @override
  Future<String?> getApplicationSupportPath() async => _tmp.path;

  @override
  Future<String?> getDownloadsPath() async => _tmp.path;

  @override
  Future<String?> getLibraryPath() async => _tmp.path;

  @override
  Future<String?> getExternalStoragePath() async => _tmp.path;

  @override
  Future<List<String>?> getExternalCachePaths() async => [_tmp.path];

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async =>
      [_tmp.path];
}

void initTestDatabase() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

Future<void> useTempDatabase(Directory tmpDir) async {
  PathProviderPlatform.instance = FakePathProvider(tmpDir);
  await DocumentDatabase.resetForTesting();
}

Future<void> disposeTempDatabase(Directory tmpDir) async {
  await DocumentDatabase.resetForTesting();
  try {
    await tmpDir.delete(recursive: true);
  } on FileSystemException {
    // Windows may briefly retain sqlite file handles after close.
  }
}
