import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quick_pdf/ui/home_screen.dart';

import 'test_helpers.dart';

void main() {
  late Directory tmpDir;

  setUpAll(() {
    initTestDatabase();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('qpdf_home_test_');
    await useTempDatabase(tmpDir);
  });

  tearDown(() async {
    await disposeTempDatabase(tmpDir);
  });

  group('HomeScreen', () {
    Widget buildSubject() {
      return const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      );
    }

    testWidgets('renders two tabs: Recent and Tools', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Tools'), findsOneWidget);
    });

    testWidgets('FAB is visible on Recent tab', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('switching to Tools tab hides FAB', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('Tools tab shows grouped headers', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE'), findsOneWidget);
      expect(find.text('PDF TOOLS'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('SECURITY & METADATA'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('SECURITY & METADATA'), findsOneWidget);
    });
  });
}
