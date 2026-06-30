/// Central route path constants and URI builders for [go_router].
abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const tools = '/tools';
  static const settings = '/settings';

  static const scan = '/scan';
  static const convert = '/convert';
  static const merge = '/merge';
  static const split = '/split';
  static const compress = '/compress';
  static const ocr = '/ocr';
  static const formatConverter = '/format-converter';
  static const pdfExport = '/pdf-export';
  static const exportText = '/export-text';
  static const annotate = '/annotate';
  static const sign = '/sign';
  static const batch = '/batch';
  static const pageManager = '/page-manager';
  static const watermark = '/watermark';
  static const passwordProtect = '/password-protect';
  static const editMetadata = '/edit-metadata';
  static const pdfViewer = '/pdf-viewer';
  static const imageViewer = '/image-viewer';

  static String pdfViewerLocation(String path, {String? heroTag}) {
    return Uri(
      path: pdfViewer,
      queryParameters: {
        'path': path,
        if (heroTag != null) 'hero': heroTag,
      },
    ).toString();
  }

  static String imageViewerLocation(String path) {
    return Uri(
      path: imageViewer,
      queryParameters: {'path': path},
    ).toString();
  }
}
