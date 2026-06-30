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
          final file = state.extra! as File;
          return SplitScreen(file: file);
        },
      ),
      GoRoute(
        path: AppRoutes.compress,
        builder: (context, state) {
          final file = state.extra! as File;
          return CompressScreen(file: file);
        },
      ),
      GoRoute(
        path: AppRoutes.ocr,
        builder: (context, state) {
          final file = state.extra! as File;
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
          final extra = state.extra! as PdfExportExtra;
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
          final file = state.extra! as File;
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
          final file = state.extra! as File;
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
