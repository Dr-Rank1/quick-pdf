import 'package:share_plus/share_plus.dart';

export 'package:share_plus/share_plus.dart' show XFile;

/// Thin wrapper around [SharePlus] for sharing files and text.
class ShareService {
  ShareService._();

  static Future<ShareResult> files(
    List<XFile> files, {
    String? subject,
    String? text,
  }) {
    return SharePlus.instance.share(
      ShareParams(files: files, subject: subject, text: text),
    );
  }

  static Future<ShareResult> text(
    String text, {
    String? subject,
  }) {
    return SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
  }
}
