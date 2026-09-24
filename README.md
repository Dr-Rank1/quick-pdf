# QuickPDF

QuickPDF is a comprehensive, offline-first PDF workstation for Android and iOS. All document processing, including merging, splitting, compressing, OCR text extraction, annotating, signing, and encryption, happens entirely on-device to ensure your data remains secure and private. There are no backend services, no cloud synchronization, and no account requirements.

## Core Features

- Document Library: Index PDFs and images in a local SQLite database with thumbnails, favourites, and full-text search capabilities.
- Create: Scan physical documents using the device camera, import existing files, and convert image files to PDF.
- Edit: Merge multiple PDFs, split documents, compress file sizes, reorder or delete pages, and apply custom watermarks.
- Convert: Convert between PDF and image formats, utilize local OCR for text recognition, and export to text files.
- Annotate and Sign: Draw directly on document pages and securely place a saved signature.
- Security: Apply AES-256 password protection and edit document metadata without rasterizing content.
- Batch Processing: Apply compression or watermarking to multiple PDF files simultaneously.

## Privacy by Design

- Local OCR: Employs Google ML Kit locally without any network calls for text recognition.
- Secure Storage: All files and databases reside in the application's private documents directory.
- Ephemeral Processing: Temporary OCR renders and caches are deleted immediately after processing.

## Documentation

- [`APP_OVERVIEW.md`](APP_OVERVIEW.md): Comprehensive technical application overview, architecture details, and data models.
- [`FIGMA_UI_BRIEF.md`](FIGMA_UI_BRIEF.md): UI implementation brief and design specifications.
- [`design_reference/`](design_reference/): Canonical references and design tokens.
- [`ads.txt`](ads.txt): Start.io authorized sellers list for deployment on developer domains.

## Development

QuickPDF is built using the Flutter framework. To build and run the application locally, ensure you have the Flutter SDK installed and configured.

1. Install dependencies:
```bash
flutter pub get
```

2. Run the application:
```bash
flutter run
```

## Platform Support

While primarily targeting mobile platforms (Android and iOS), the Flutter scaffold provides foundational support for Windows, Linux, macOS, and Web platforms.
