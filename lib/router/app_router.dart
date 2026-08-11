import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_pdf/router/app_routes.dart';
import 'package:quick_pdf/router/route_extra.dart';
import 'package:quick_pdf/ui/annotate_pdf_screen.dart';
import 'package:quick_pdf/ui/batch_screen.dart';
import 'package:quick_pdf/ui/compress_screen.dart';
import 'package:quick_pdf/ui/convert_screen.dart';
import 'package:quick_pdf/ui/export_text_screen.dart';
import 'package:quick_pdf/ui/format_converter_screen.dart';
import 'package:quick_pdf/ui/home_screen.dart';
import 'package:quick_pdf/ui/image_viewer_screen.dart';
import 'package:quick_pdf/ui/merge_screen.dart';
import 'package:quick_pdf/ui/ocr_text_screen.dart';
import 'package:quick_pdf/ui/onboarding_screen.dart';
import 'package:quick_pdf/ui/page_manager_screen.dart';
import 'package:quick_pdf/ui/password_protect_screen.dart';
import 'package:quick_pdf/ui/pdf_security_screen.dart';
import 'package:quick_pdf/ui/pdf_viewer_screen.dart';
import 'package:quick_pdf/ui/scanner_screen.dart';
import 'package:quick_pdf/ui/settings_screen.dart';
import 'package:quick_pdf/ui/sign_pdf_screen.dart';
import 'package:quick_pdf/ui/split_screen.dart';
import 'package:quick_pdf/ui/tools_screen.dart';
import 'package:quick_pdf/ui/watermark_screen.dart';
import 'package:quick_pdf/ui/main_nav_page.dart';

Widget _missingExtraScaffold(String title, String message) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}

File? _fileExtra(Object? extra) {
  if (extra is File) return extra;
  return null;
}

GoRouter createAppRouter({required bool showOnboarding}) {
  return GoRouter(
    initialLocation:
        showOnboarding ? AppRoutes.onboarding : AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            QuickPDFHomePage(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tools,
                builder: (context, state) => const ToolsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.convert,
        builder: (context, state) {
          final images = state.extra as List<File>? ?? const [];
          return ConvertScreen(initialImages: images);
        },
      ),
      GoRoute(
        path: AppRoutes.merge,
        builder: (context, state) {
          final files = state.extra as List<File>? ?? const [];
          return MergeScreen(initialFiles: files);
        },
      ),
      GoRoute(
        path: AppRoutes.split,
        builder: (context, state) {
          final file = _fileExtra(state.extra);
          if (file == null) {
            return _missingExtraScaffold(
              'Split PDF',
              'No PDF selected. Go back and choose a file to split.',
            );
          }
          return SplitScreen(file: file);
        },
      ),
      GoRoute(
        path: AppRoutes.compress,
        builder: (context, state) {
          final file = _fileExtra(state.extra);
          if (file == null) {
            return _missingExtraScaffold(
              'Compress PDF',
              'No PDF selected. Go back and choose a file to compress.',
            );
          }
          return CompressScreen(file: file);
        },
      ),
      GoRoute(
        path: AppRoutes.ocr,
        builder: (context, state) {
          final file = _fileExtra(state.extra);
          if (file == null) {
            return _missingExtraScaffold(
              'OCR',
              'No PDF selected. Go back and choose a file for OCR.',
            );
          }
          return OcrTextScreen(file: file);
        },
      ),
      GoRoute(
        path: AppRoutes.formatConverter,
        builder: (context, state) => const FormatConverterScreen(),
      ),
      GoRoute(
        path: AppRoutes.pdfExport,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! PdfExportExtra) {
            return _missingExtraScaffold(
              'Export PDF',
              'Missing export details. Go back and try again.',
            );
          }
          return PdfExportScreen(file: extra.file, format: extra.format);
        },
      ),
      GoRoute(
        path: AppRoutes.exportText,
        builder: (context, state) => const ExportTextScreen(),
      ),
      GoRoute(
        path: AppRoutes.annotate,
        builder: (context, state) => const AnnotatePdfScreen(),
      ),
      GoRoute(
        path: AppRoutes.sign,
        builder: (context, state) => const SignPdfScreen(),
      ),
      GoRoute(
        path: AppRoutes.batch,
        builder: (context, state) => const BatchScreen(),
      ),
      GoRoute(
        path: AppRoutes.pageManager,
        builder: (context, state) {
          final file = _fileExtra(state.extra);
          if (file == null) {
            return _missingExtraScaffold(
              'Page Manager',
              'No PDF selected. Go back and choose a file.',
            );
          }
          return PageManagerScreen(pdfFile: file);
        },
      ),
      GoRoute(
        path: AppRoutes.watermark,
        builder: (context, state) => const WatermarkScreen(),
      ),
      GoRoute(
        path: AppRoutes.passwordProtect,
        builder: (context, state) => const PasswordProtectScreen(),
      ),
      GoRoute(
        path: AppRoutes.editMetadata,
        builder: (context, state) {
          final file = _fileExtra(state.extra);
          if (file == null) {
            return _missingExtraScaffold(
              'Edit Metadata',
              'No PDF selected. Go back and choose a file.',
            );
          }
          return EditMetadataScreen(pdfFile: file);
        },
      ),
      GoRoute(
        path: AppRoutes.pdfViewer,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'];
          if (path == null || path.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Missing PDF path')),
            );
          }
          return PDFViewerScreen(
            pdfPath: path,
            heroTag: state.uri.queryParameters['hero'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.imageViewer,
        builder: (context, state) {
          final path = state.uri.queryParameters['path'];
          if (path == null || path.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Missing image path')),
            );
          }
          return ImageViewerScreen(path: path);
        },
      ),
    ],
  );
}
