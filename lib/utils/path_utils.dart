import 'package:path/path.dart' as p;

/// Returns the file name portion of [filePath] (cross-platform).
String fileName(String filePath) => p.basename(filePath);

/// Returns the file name without its extension.
String fileStem(String filePath) => p.basenameWithoutExtension(filePath);
