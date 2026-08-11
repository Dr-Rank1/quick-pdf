import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quick_pdf/core/pdf_manager.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;

  @override
  Future<String?> getApplicationCachePath() async =>
      Directory('${root.path}/cache').path;

  @override
  Future<String?> getTemporaryPath() async =>
      Directory('${root.path}/tmp').path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('qpdf_convert_test_');
    await Directory('${tmp.path}/cache').create();
    await Directory('${tmp.path}/tmp').create();
    PathProviderPlatform.instance = _FakePathProvider(tmp);
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  test('convertImagesToPDF builds a PDF from image paths without crashing',
      () async {
    final imageFile = File('${tmp.path}/sample.png');
    final image = img.Image(width: 120, height: 80);
    img.fill(image, color: img.ColorRgb8(40, 120, 200));
    await imageFile.writeAsBytes(Uint8List.fromList(img.encodePng(image)));

    final pdf = await PDFManager.convertImagesToPDF(
      [imageFile],
      pageSize: 'A4',
      quality: 70,
      margin: 10,
      outputName: 'ConvertTest',
    );

    expect(await pdf.exists(), isTrue);
    expect(await pdf.length(), greaterThan(100));
    final header = String.fromCharCodes(await pdf.openRead(0, 5).first);
    expect(header.startsWith('%PDF'), isTrue);
  });

  test('convertImagesToPDF rejects missing images', () async {
    await expectLater(
      () => PDFManager.convertImagesToPDF(
        [File('${tmp.path}/missing.jpg')],
      ),
      throwsA(isA<Exception>()),
    );
  });
}
