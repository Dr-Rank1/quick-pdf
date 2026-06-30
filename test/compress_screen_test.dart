import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_pdf/ui/compress_screen.dart';

void main() {
  late Directory tmpDir;
  late File pdfFile;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('qpdf_compress_test_');
    pdfFile = File('${tmpDir.path}/sample.pdf');
    await pdfFile.writeAsString('%PDF-1.4');
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  Widget buildSubject() {
    return MaterialApp(home: CompressScreen(file: pdfFile));
  }

  group('CompressScreen', () {
    testWidgets('renders idle state with presets and compress action',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Compression preset'), findsOneWidget);
      expect(find.text('Balanced'), findsOneWidget);
      expect(find.text('Maximum'), findsOneWidget);
      expect(find.text('High Quality'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Output name'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Compress PDF'), findsOneWidget);
    });

    testWidgets('shows JPEG quality slider when Custom preset is selected',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsNothing);

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      expect(find.text('JPEG quality'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });
  });
}
