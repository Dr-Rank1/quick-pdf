# QuickPDF — Application Overview

> **Version:** 1.0.1+6  
> **Package:** `quick_pdf`  
> **Platforms:** Android, iOS, Windows, Linux, macOS, Web (Flutter multi-platform scaffold)  
> **Primary target:** Mobile — offline PDF utility for students, freelancers, and office workers

---

## Table of Contents

1. [What the App Does](#1-what-the-app-does)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Application Startup](#3-application-startup)
4. [Navigation & Screen Map](#4-navigation--screen-map)
5. [UI Layer — Detailed](#5-ui-layer--detailed)
6. [Services Layer](#6-services-layer)
7. [Core PDF Processing](#7-core-pdf-processing)
8. [Data Model & Storage](#8-data-model--storage)
9. [State Management](#9-state-management)
10. [Theme & Design System](#10-theme--design-system)
11. [Advertising & Monetization](#11-advertising--monetization)
12. [Dependencies](#12-dependencies)
13. [Platform Configuration](#13-platform-configuration)
14. [Testing](#14-testing)
15. [Source File Index](#15-source-file-index)
16. [Known Gaps & Technical Debt](#16-known-gaps--technical-debt)

---

## 1. What the App Does

QuickPDF is an **offline-first PDF workstation**. All document processing — merge, split, compress, OCR, encryption, scanning, annotation, signing — happens **on-device**. There is no backend, no cloud sync, and no account system.

### Core value proposition

| Capability | Description |
|------------|-------------|
| **Document library** | Index PDFs and images in a local SQLite database with thumbnails, favourites, and full-text search |
| **Create** | Scan documents with the camera, import files, convert images to PDF |
| **Edit** | Merge, split, compress, reorder/delete pages, add watermarks |
| **Convert** | PDF ↔ images, OCR text extraction, export to `.txt` |
| **Annotate & sign** | Draw on pages, place a saved signature |
| **Security** | AES-256 password protection (Syncfusion), metadata editing |
| **Batch** | Apply compress or watermark to multiple PDFs at once |

### Privacy model

- OCR uses **Google ML Kit** locally — no network calls for text recognition
- Files live in the app's private documents directory
- A written privacy policy is shown in Settings (`PRIVACY_POLICY.md` rendered via `flutter_markdown`)
- Temporary OCR renders are deleted per-page during processing

---

## 2. High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         PRESENTATION LAYER                           │
│  MaterialApp → OnboardingScreen | QuickPDFHomePage (IndexedStack)      │
│    ├─ HomeScreen (library + embedded tools tab)                      │
│    ├─ ToolsScreen (full tool catalog)                                │
│    └─ SettingsScreen                                                 │
│                                                                      │
│  Tool screens push via MaterialPageRoute (imperative navigation)     │
└───────────────────────────────┬──────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────┐
│                          SERVICE LAYER                               │
│  DocumentDatabase  OcrService  ScannerService  FilePickerService       │
│  AdService  ShareService  ErrorLogger  ThemeNotifier (Riverpod)      │
└───────────────────────────────┬──────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────┐
│                           CORE LAYER                                 │
│  PDFManager (static facade)                                          │
│    ├─ Main isolate: pdf_render → image → pdf package               │
│    ├─ Background isolate: PdfProcessorIsolate (images → PDF)         │
│    └─ Syncfusion: encrypt / decrypt without rasterizing              │
└───────────────────────────────┬──────────────────────────────────────┘
                                │
┌───────────────────────────────▼──────────────────────────────────────┐
│                          PERSISTENCE                                   │
│  SQLite (documents.db)  │  App documents dir  │  Cache (thumbnails)  │
└──────────────────────────────────────────────────────────────────────┘
```

### Key architectural decisions

| Decision | Rationale |
|----------|-----------|
| **No router package** | All navigation is `Navigator.push(MaterialPageRoute(...))` — simple, explicit, no deep-link table |
| **Singleton `DocumentDatabase`** | One DB connection; `ChangeNotifier` broadcasts list changes to `_DocumentGrid` |
| **Riverpod for theme only** | Everything else uses `StatefulWidget` + `setState` — minimal global state |
| **Rasterize-then-rebuild** | Most PDF edits render pages to bitmaps and rebuild with the `pdf` package — reliable but lossy for vector content |
| **Syncfusion for encryption** | Preserves PDF structure; avoids rasterizing for password protect/unlock |
| **Isolates for image→PDF** | Heavy JPEG encoding off the UI thread via `PdfProcessorIsolate` |

---

## 3. Application Startup

**File:** `lib/main.dart`

### `main()` sequence

```
1. WidgetsFlutterBinding.ensureInitialized()
2. SharedPreferences.getInstance()
   └─ read 'has_seen_onboarding' (default false)
3. SystemChrome.setSystemUIOverlayStyle(transparent status bar)
4. runApp(ProviderScope(child: QuickPDFApp(showOnboarding: !hasSeenOnboarding)))
5. addPostFrameCallback:
   └─ MobileAds.instance.initialize()
   └─ AdService().loadInterstitial()
```

**Design intent:** Prefs are loaded **before** `runApp` so the first frame shows either onboarding or home — no splash spinner for routing.

### `QuickPDFApp` (ConsumerWidget)

- Watches `themeProvider` → `ThemeMode` (light / dark / system)
- Builds `MaterialApp` with:
  - `title: 'QuickPDF'`
  - `debugShowCheckedModeBanner: false`
  - `theme` + `darkTheme` from `_buildTheme(seed: 0xFF1A237E)`
  - `home`: `OnboardingScreen` **or** `QuickPDFHomePage`

### Theme construction (`_buildTheme`)

Uses Material 3 `ColorScheme.fromSeed` with:
- **Primary seed:** deep navy `#1A237E`
- **Secondary:** amber `#FFB300`

Customizes: `AppBarTheme`, `CardTheme`, `NavigationBarTheme`, `FloatingActionButtonTheme`, `InputDecorationTheme`, `ListTileTheme`.

---

## 4. Navigation & Screen Map

### Top-level flow

```
App Launch
    │
    ├─ [first launch] ──► OnboardingScreen (4 pages)
    │                           │
    │                           └─ pushReplacement ──► QuickPDFHomePage
    │
    └─ [returning user] ──► QuickPDFHomePage
                                │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
               HomeScreen  ToolsScreen  SettingsScreen
               (tab 0)     (tab 1)      (tab 2)
```

### `QuickPDFHomePage` (`lib/ui/main_nav_page.dart`)

- **Body:** `IndexedStack` — preserves tab state when switching
- **Bottom:** `NavigationBar` with Home / Tools / Settings
- **Ads:** `_BannerAdArea` widget sits above the nav bar, loads a `BannerAd` via `AdService.bannerAdUnitId`

### Navigation pattern everywhere else

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => SomeScreen(initialArgs: ...)),
);
```

No named routes, no `go_router`, no route guards.

### Screen reachability matrix

| Screen | Reached from |
|--------|--------------|
| `ScannerScreen` | Home FAB sheet, Home tools tab, ToolsScreen |
| `ConvertScreen` | Home FAB, Home tools, ToolsScreen (with `initialImages`) |
| `MergeScreen` | Home quick action, ToolsScreen (with `initialFiles`) |
| `SplitScreen` | Home quick action, ToolsScreen (with `file`) |
| `CompressScreen` | Home quick action, ToolsScreen (with `file`) |
| `OcrTextScreen` | Home quick action, ToolsScreen (with `file`) |
| `FormatConverterScreen` | Home tools, ToolsScreen |
| `ExportTextScreen` | ToolsScreen only |
| `AnnotatePdfScreen` | ToolsScreen only |
| `SignPdfScreen` | ToolsScreen only |
| `BatchScreen` | ToolsScreen only |
| `PageManagerScreen` | Home tools, ToolsScreen (with `pdfFile`) |
| `WatermarkScreen` | Home tools, ToolsScreen |
| `PasswordProtectScreen` | Home tools, ToolsScreen |
| `EditMetadataScreen` | Home tools (`pdf_security_screen.dart`), ToolsScreen |
| `PDFViewerScreen` | Document grid tap, search results, post-tool completion |
| `_ImageViewerScreen` | Document grid tap (image files, private widget in `home_screen.dart`) |

---

## 5. UI Layer — Detailed

### 5.1 Onboarding (`onboarding_screen.dart`)

**Purpose:** First-run education; sets `has_seen_onboarding = true` in SharedPreferences.

**Structure:**
- `PageView` with 4 pages, animated page indicators
- Navy vertical gradient background (matches brand)
- Pages: *Privacy First*, *All-in-One Utility*, *Lightweight & Powerful*, *Works 100% Offline*
- Actions: **Skip**, **Next**, **Get Started** — all call `_finish()` → `pushReplacement` to `QuickPDFHomePage`

---

### 5.2 Home Screen (`home_screen.dart`)

The largest UI file (~1,600 lines). Acts as the **document library hub**.

#### App bar

- Title: `QuickPDF`
- Bottom: `TabBar` — **Recent** | **Tools**
- Action: search icon → `showSearch(context, delegate: DocumentSearchDelegate())`

#### Tab 0 — Recent (`_DocumentGrid`)

**State variables:**
- `_docs` — list from `DocumentDatabase.getAllDocuments()`
- `_loading` — shows `CircularProgressIndicator` until first DB fetch
- `_sortMode` — `recent | name | size | added`
- `_isGridView` — toggle grid vs list layout
- `_search` / `_filterType` — `all | pdf | image`

**DB integration:**
- `initState`: `_db.addListener(_reload)` + `_load()`
- `_load()`: fetches docs, handles errors gracefully (sets `_loading = false`)
- `dispose`: removes listener

**UI sections (CustomScrollView slivers):**
1. Search `TextField` — filters by filename client-side
2. Filter chips — All / PDF / Image
3. Sort popup — Recently opened, Date added, Name, File size
4. View toggle — grid ↔ list
5. Content — `SliverGrid` of `_DocCard` or `SliverList` of `_DocListTile`
6. Empty state — icon + "No documents yet" + hint text

**`_DocCard` interactions:**
- Tap → open file (`PDFViewerScreen` or `_ImageViewerScreen`)
- Long press → bottom sheet: Share, Rename, Favourite, Details, Delete
- Hero tag: `doc_thumb_{path}` for thumbnail transition

**FAB (visible on Recent tab only):**
- Opens quick-add bottom sheet:
  - **Scan Document** → `ScannerScreen`
  - **Import Files** → `_addFiles()`
  - **Images to PDF** → `_quickConvert()`

#### `_addFiles()` import pipeline

```
1. FilePickerService.pickMultipleFiles(pdf + image extensions)
2. Set _isProcessing = true (full-screen overlay)
3. For each file:
   a. OcrService.extractText(path) → text_content
   b. PDFManager.generateThumbnail(path) → thumbnail_path
   c. DocumentDatabase.insertDocument(path, textContent, thumbnailPath)
4. AdService.recordToolCompletion()
5. _isProcessing = false
```

#### Tab 1 — Tools (`_HomeToolsTab`)

Embedded subset of `ToolsScreen` with staggered `FadeTransition` animations.

**Groups:** Create → Edit → Convert → Organise → Security

**Note:** This tab is a **subset** of `ToolsScreen`. Missing from home tools tab: Export Text, Annotate, Sign, Batch Processing.

#### Helper functions (top of file)

- `_fmtSize(int bytes)` — human-readable B / KB / MB
- `_relativeDate(String? isoDate)` — "3d ago", "Just now", etc.

---

### 5.3 Tools Screen (`tools_screen.dart`)

Full tool catalog as a `ListView` of grouped `_Tool` tiles.

| Group | Tools |
|-------|-------|
| **Create** | Scan Document, Images to PDF |
| **PDF Tools** | Merge, Split, Compress |
| **Convert & Extract** | Format Converter, Extract Text (OCR), Export Text |
| **Annotate & Sign** | Annotate PDF, Sign PDF |
| **Batch** | Batch Processing |
| **Organise** | Page Manager, Watermark |
| **Security & Metadata** | Password Protect, Edit Metadata |

Each tile: 42×42 colored icon container + title + subtitle + chevron. Most tools open a file picker first, then push the target screen with the selected file.

---

### 5.4 Settings Screen (`settings_screen.dart`)

`ConsumerStatefulWidget` — reads/writes prefs and watches `themeProvider`.

#### Sections

| Section | Controls |
|---------|----------|
| **Appearance** | Theme segmented button: System / Light / Dark → `themeProvider.notifier.setThemeMode()` |
| **Processing defaults** | Default image quality slider (50–100, stored as `default_image_quality`) |
| **OCR** | Language dropdown: en, fr, es, de, ar, sw (stored as `ocr_language`) |
| **Storage** | Documents used + cache used (recursive dir scan) |
| **Cache** | Clear thumbnails + temp files; calls `DocumentDatabase.clearThumbnailPaths()` |
| **Ads** | Toggle `ads_enabled` → `AdService.adsEnabled` |
| **About** | App version via `package_info_plus`, privacy policy markdown sheet |
| **Danger zone** | Clear error log |

#### SharedPreferences keys

| Key | Type | Default |
|-----|------|---------|
| `default_image_quality` | int | 75 |
| `ocr_language` | string | `en` |
| `ads_enabled` | bool | true |
| `theme_mode` | string | `system` |
| `has_seen_onboarding` | bool | false |
| `ad_completion_count` | int | 0 |

---

### 5.5 Tool Screens — Per-Screen Logic

#### Merge (`merge_screen.dart`)

**Input:** `List<File> initialFiles` (optional pre-selected)

**Data model:** `MergeItem { file, selectedPages: List<int> }`

**Flow:**
1. User adds/reorders PDFs (`ReorderableListView`)
2. Per-document page picker (`_PagePickerSheet`) — select specific pages
3. Quality segmented control: High (90) / Medium (72) / Low (50)
4. `PDFManager.mergePDFFiles(items, quality)` → output path
5. `DocumentDatabase.insertDocument` + navigate to `PDFViewerScreen`

---

#### Split (`split_screen.dart`)

**Modes:**
- **All pages** — one PDF per page
- **Range** — dual sliders for start/end page

**Flow:** `PDFManager.splitPDF` → list of output files → share all or open single result.

---

#### Compress (`compress_screen.dart`)

**Presets:** Maximum (50), Balanced (72), High Quality (90), or custom slider.

**UI shows:** original size → compressed size → reduction percentage.

**Core call:** `PDFManager.compressPDF(file, imageQuality, renderScale)`.

**Safety:** If output ≥ input size, original bytes are kept.

---

#### Convert (`convert_screen.dart`)

**Input:** `List<File> initialImages`

**Options:**
- Page size: A4, Letter, A3, Legal, Fit to image
- Landscape toggle
- Margin slider
- JPEG quality slider
- Reorderable image list

**Core call:** `PDFManager.convertImagesToPDF` (runs in background isolate).

---

#### Format Converter (`format_converter_screen.dart`)

Two directions:
1. **PDF → Images** — `_PdfExportScreen` renders each page, saves JPEG/PNG to documents
2. **Images → PDF** — delegates to `ConvertScreen`

---

#### OCR Text (`ocr_text_screen.dart`)

**Multi-page viewer** with extracted text per page.

**Features:**
- Edit mode — modify extracted text inline
- In-text search with highlight
- Copy page / copy all
- Share text or save `.txt` + share file
- Persists `text_content` to DB via `updateTextContent`

**Processing:** `OcrService.extractText(file)` on load.

---

#### Export Text (`export_text_screen.dart`)

Simpler OCR → single scrollable text field → export `.txt` via `ShareService`.

---

#### Scanner (`scanner_screen.dart`)

**Camera flow:**
1. `ScannerService.getBackCamera()` + `createController()`
2. Live preview with tap-to-focus, flash toggle, B&W mode toggle
3. Capture → page strip at bottom (reorderable thumbnails)
4. **Done** → `ScannerService.enhanceDocument` per page → `PDFManager.convertImagesToPDF`

**B&W pipeline** (in isolate via `compute`):
grayscale → normalize → contrast 1.9 → JPEG q=92

---

#### Page Manager (`page_manager_screen.dart`)

**UI:** `ReorderableGridView` of page thumbnails from `pdf_render`.

**Actions:**
- Drag to reorder
- Multi-select → delete pages or extract to new PDF
- Rotate button (90° increments) — **UI preview only**

**Save:** `PDFManager.reorderPages(pdfFile, pageOrder)` — rotation is **not** applied to output (known gap).

---

#### Watermark (`watermark_screen.dart`)

**Controls:** text, opacity slider, font size slider, rotation slider.

**Preview:** Live thumbnail with watermark overlay.

**Save:** `PDFManager.addWatermark` — rasterizes pages, composites rotated semi-transparent text via `pw.Stack`.

---

#### Password Protect (`password_protect_screen.dart`)

**Tabs:** Protect | Unlock

- **Protect:** user password + confirm → `PDFManager.encryptPDF` (Syncfusion AES-256)
- **Unlock:** enter password → `PDFManager.decryptPDF`

---

#### Edit Metadata (`pdf_security_screen.dart` → `EditMetadataScreen`)

Form fields: Title, Author, Subject.

**Save:** `PDFManager.updatePDFMetadata` — rasterizes and rebuilds PDF with new info dictionary.

---

#### Annotate PDF (`annotate_pdf_screen.dart`)

**Tools:** Pen, highlighter, eraser, stamp icons.

**Canvas:** Renders PDF page, draws strokes on overlay.

**Save:** `_save` calls rasterize pipeline — **stroke compositing onto output is incomplete** (known gap).

---

#### Sign PDF (`sign_pdf_screen.dart`)

**Two-step wizard:**
1. Draw signature on canvas → save to `quickpdf_saved_signature.png`
2. Place signature on PDF page (drag position)

**Monetization:** `AdService.showRewardedOrFallback` before applying.

**Save:** Composites signature image via `pw.Stack` onto rasterized page.

---

#### Batch (`batch_screen.dart`)

Pick multiple PDFs → choose operation (compress or watermark) → process sequentially.

**Monetization:** Rewarded ad gate via `showRewardedOrFallback`.

---

#### PDF Viewer (`pdf_viewer_screen.dart`)

**Engine:** `pdfx` `PdfController` + `PdfView`.

**Features:**
- Page navigation (prev/next, go-to-page dialog)
- Thumbnail strip
- Night mode (color matrix filter)
- Share via `ShareService.files`
- Updates `lastOpened` in DB on open

---

### 5.6 Shared Widgets

#### `DocumentSearchDelegate` (`widgets/search_delegate.dart`)

- Queries `DocumentDatabase.searchDocuments(query)` — matches `name` and `text_content`
- Shows snippets with highlighted search terms
- Tap result → `PDFViewerScreen`

---

## 6. Services Layer

### 6.1 DocumentDatabase (`document_database.dart`)

| Method | Behavior |
|--------|----------|
| `insertDocument` | Upsert by path; stores name, size, OCR text, thumb path, timestamps |
| `getAllDocuments` | Favourites first, `lastOpened DESC`; prunes DB rows whose files no longer exist |
| `getDocument` | Single row by path |
| `searchDocuments` | `LIKE` on name and text_content |
| `toggleFavourite` | Flips `is_favourite` 0↔1 |
| `updateLastOpened` | Sets timestamp to now |
| `updateTextContent` | Stores OCR text for search |
| `updatePath` | After file rename — updates path, name, size |
| `deleteDocument` | Removes DB row (caller deletes file separately) |
| `clearThumbnailPaths` | Nulls all `thumbnail_path` values (cache clear) |
| `resetForTesting` | Closes DB connection for test isolation |

**Listener pattern:** `_DocumentGrid` calls `addListener(_reload)` to refresh on any mutation.

---

### 6.2 OcrService (`ocr_service.dart`)

| Method | Input | Process |
|--------|-------|---------|
| `extractText` | File | Dispatches by extension |
| `extractTextFromImage` | Image path | `InputImage.fromFilePath` → ML Kit |
| `extractTextFromPdf` | PDF path | Render each page 1200–1800px → temp PNG → ML Kit → delete temp |

**Output model:** `OcrPageResult { page, text, wordCount, charCount, isEmpty }`

**Text structuring:** ML Kit blocks → lines joined with `\n`, blocks with `\n\n`.

**Note:** Settings `ocr_language` preference is saved but **not passed** to `TextRecognizer` — always uses default Latin script.

---

### 6.3 ScannerService (`scanner_service.dart`)

| Method | Purpose |
|--------|---------|
| `getBackCamera` | Prefer rear camera from `availableCameras()` |
| `createController` | `ResolutionPreset.high`, JPEG, no audio |
| `enhanceDocument` | Color passthrough or B&W pipeline in `compute()` isolate |

---

### 6.4 FilePickerService (`file_picker_service.dart`)

| Method | Backend |
|--------|---------|
| `pickMultipleFiles` | `file_picker` with optional extension filter |
| `pickImage` | `image_picker` single |
| `pickMultipleImages` | `image_picker` gallery multi |
| `hasEnoughStorage` | Stat check on documents dir (rough heuristic) |

---

### 6.5 AdService (`ad_service.dart`)

Singleton managing ad lifecycle. See [Section 11](#11-advertising--monetization).

---

### 6.6 ShareService (`share_service.dart`)

Thin wrapper over `share_plus` v12 API:

```dart
ShareService.files([XFile(...)], subject: '...')
ShareService.text('...', subject: '...')
```

Re-exports `XFile` for convenience.

---

### 6.7 ErrorLogger (`error_logger.dart`)

- Appends to `{documents}/quickpdf_errors.log`
- **512 KB cap** — rotates by clearing file
- Methods: `log`, `read`, `clear` — never throws

---

### 6.8 ThemeNotifier (`providers/theme_provider.dart`)

```dart
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(...);
```

Persists `theme_mode` as `light` | `dark` | `system` in SharedPreferences.

---

## 7. Core PDF Processing

**Files:** `lib/core/pdf_manager.dart`, `lib/core/pdf_processor.dart`

### 7.1 Processing strategies

```
┌─────────────────────────────────────────────────────────┐
│                    PDFManager                           │
├─────────────────────┬───────────────────────────────────┤
│ Main isolate        │ Background isolate                │
│ (pdf_render +       │ (PdfProcessorIsolate)             │
│  image + pdf pkg)   │                                   │
│                     │                                   │
│ merge, compress,    │ convertImagesToPDF                │
│ split, watermark,   │                                   │
│ reorder, metadata,  │                                   │
│ thumbnails          │                                   │
├─────────────────────┴───────────────────────────────────┤
│ Syncfusion (syncfusion_flutter_pdf)                     │
│ encryptPDF, decryptPDF — no rasterization               │
└─────────────────────────────────────────────────────────┘
```

### 7.2 Rasterization pipeline (used by most operations)

```
1. PdfDocument.openData(bytes)          // pdf_render
2. page.render(width, height)         // scale varies by operation
3. img.Image.fromBytes(RGBA)          // image package
4. img.encodeJpg(png)(quality)        // compress to raster
5. pw.Document.addPage(pw.Image(...)) // pdf package rebuild
6. doc.save() → File in app documents directory
```

**Yield pattern:** `await Future.delayed(Duration.zero)` between pages to keep UI responsive.

### 7.3 Operation parameters

| Operation | Render scale | Quality | Notes |
|-----------|-------------|---------|-------|
| Merge | 2.0× if q≥80, 1.5× if q≥60, else 1.0× | User-selected | Per-page rasterize |
| Compress | User `renderScale` | User `imageQuality` | Never outputs larger than input |
| Split | 2.0× | 90 | One file per page |
| Watermark | 2.0× | 90 | Text overlaid via `pw.Stack` |
| Metadata | 2.0× | 90 | Rebuilds info dict |
| Reorder | 2.0× | 90 | Pages in `pageOrder`; omitted = deleted |
| Thumbnail | Fit 200px wide | PNG | Cached by `path.hashCode` |

### 7.4 Image → PDF isolate protocol

**`PdfProcessorIsolate`** communicates via `SendPort` / `ReceivePort`:

```dart
PdfProcessorMessage { requestId, operation, payload }
PdfProcessorResponse { requestId, result | error }
```

**`_convertImagesToPDFIsolate`:**
1. Decode image bytes
2. Scale to fit page (A4/Letter/A3/Legal/fit) minus margins
3. Downsample to ~144 DPI (2px per point)
4. JPEG encode → `pw.Page` with centered image
5. One page per input image

### 7.5 Encryption (Syncfusion)

```dart
PdfDocument(inputBytes)
  → security.userPassword / ownerPassword
  → algorithm: aesx256Bit
  → saveSync() → Protected_QuickPDF_{timestamp}.pdf
```

Decrypt opens with password, clears security, saves as `Unlocked_QuickPDF_{timestamp}.pdf`.

### 7.6 Output file naming conventions

| Pattern | Operation |
|---------|-----------|
| `QuickPDF_{timestamp}.pdf` | Generic / scan output |
| `Merged_QuickPDF_{timestamp}.pdf` | Merge |
| `Compressed_{originalName}` | Compress |
| `{stem}_p{pageNum}.pdf` | Split |
| `Protected_QuickPDF_{timestamp}.pdf` | Encrypt |
| `Unlocked_QuickPDF_{timestamp}.pdf` | Decrypt |
| `Watermarked_{originalName}` | Watermark |
| `Reordered_{originalName}` | Page manager |
| `UpdatedMetadata_{originalName}` | Metadata edit |
| `Annotated_{originalName}` | Annotate |

### 7.7 Thumbnail cache

- **Path:** `{cacheDir}/thumbnails/thumb_{path.hashCode}.png`
- **Invalidation:** Regenerates if source `modified` is newer than thumbnail
- **Skip:** Returns null for missing/empty/corrupt files

---

## 8. Data Model & Storage

### 8.1 SQLite schema (`documents.db`, version 4)

```sql
CREATE TABLE documents (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  path            TEXT NOT NULL UNIQUE,
  name            TEXT NOT NULL,
  size            INTEGER,
  text_content    TEXT,           -- added v2
  thumbnail_path  TEXT,           -- added v3
  is_favourite    INTEGER NOT NULL DEFAULT 0,  -- added v4
  dateAdded       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  lastOpened      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 8.2 Physical storage layout

| Location | Contents |
|----------|----------|
| `getApplicationDocumentsDirectory()` | PDFs, exports, `documents.db`, error log, saved signature PNG |
| `getApplicationCacheDirectory()/thumbnails/` | Generated thumbnail PNGs |
| `getTemporaryDirectory()` | OCR temp page renders (deleted per-page) |

### 8.3 Data flow: import → library → search

```
User picks file
    → OcrService.extractText()        → text_content in DB
    → PDFManager.generateThumbnail()    → thumbnail_path in DB
    → DocumentDatabase.insertDocument()
    → notifyListeners()
    → _DocumentGrid._reload()

User searches
    → DocumentSearchDelegate
    → DocumentDatabase.searchDocuments(query)
    → matches name LIKE %query% OR text_content LIKE %query%
```

### 8.4 Orphan handling

`getAllDocuments()` and `searchDocuments()` verify `File(path).exists()`. Missing files are batch-deleted from DB and listeners are notified.

---

## 9. State Management

### Riverpod (minimal)

| Provider | Type | Used by |
|----------|------|---------|
| `themeProvider` | `StateNotifierProvider<ThemeNotifier, ThemeMode>` | `QuickPDFApp`, `SettingsScreen` |

### ChangeNotifier

| Class | Listeners |
|-------|-----------|
| `DocumentDatabase` | `_DocumentGrid` via `addListener(_reload)` |

### StatefulWidget + setState (everywhere else)

Each tool screen manages its own:
- File references
- Progress enums (`_State.loading`, `_State.done`, etc.)
- Form controllers
- Slider values
- Result file paths

### SharedPreferences (direct access)

Used in: `main.dart`, `SettingsScreen`, `AdService`, `ThemeNotifier`, `OnboardingScreen`.

**No** global document provider, no Riverpod for PDF operations or document list.

---

## 10. Theme & Design System

### Color palette

| Token | Value | Usage |
|-------|-------|-------|
| Primary seed | `#1A237E` (deep navy) | AppBar, FAB, chips, indicators |
| Secondary | `#FFB300` (amber) | Accent via `ColorScheme` |
| PDF files | `colorScheme.error` (red) | File type icon in grid |
| Images | Green | File type icon in grid |
| Tool categories | Hardcoded `Colors.*.shade*` per screen | Icon containers |

### Component patterns

| Pattern | Implementation |
|---------|----------------|
| **Cards** | 0 elevation, 12px radius, `outlineVariant` border |
| **Tool tiles** | 42×42 rounded icon box (12% opacity fill) + ListTile |
| **Inputs** | 10px radius `OutlineInputBorder`, dense padding |
| **SnackBars** | `SnackBarBehavior.floating` throughout |
| **Bottom sheets** | Quick-add, document options, file details (`DraggableScrollableSheet`) |
| **Progress** | `CircularProgressIndicator` + `LinearProgressIndicator` with page counts |
| **Empty states** | 96×96 icon in `primaryContainer` rounded box + title + subtitle |
| **Haptics** | `PDFManager.hapticFeedbackSuccess()` / `hapticFeedbackError()` after tool ops |
| **Hero transitions** | `doc_thumb_{path}` on grid cards |

### Animation

- `_HomeToolsTab`: staggered `FadeTransition` (40ms delay per item)
- Onboarding: `PageView` with dot indicators
- Scanner: page strip with reorderable thumbnails

---

## 11. Advertising & Monetization

### Ad units (`AdService`)

| Type | Unit ID |
|------|---------|
| Banner | `ca-app-pub-9418386170210711/8362178112` |
| Interstitial | `ca-app-pub-9418386170210711/3537611287` |
| Rewarded | Same as interstitial (placeholder — needs real rewarded ID) |

### AdMob App ID (Android manifest)

`ca-app-pub-9418386170210711~3373959750`

### Frequency capping

`recordToolCompletion()` increments `ad_completion_count` in prefs. Shows interstitial every **3rd** completion.

Called after: file import (`_addFiles`), and various tool completions.

### Rewarded ads

Used by `SignPdfScreen` and `BatchScreen` via `showRewardedOrFallback`:
- If ad fails or ads disabled → **feature proceeds immediately** (never blocked)
- `onUserEarnedReward` triggers the actual operation

### User control

Settings toggle `ads_enabled` → sets `AdService.adsEnabled` static flag.

### Initialization

Deferred to post-first-frame in `main()` so ads never delay app launch.

---

## 12. Dependencies

### Production (`pubspec.yaml`)

| Package | Version | Role |
|---------|---------|------|
| `pdf` | ^3.10.8 | Build PDFs (`pw.Document`, pages, images) |
| `printing` | ^5.14.0 | PDF printing infrastructure |
| `pdfx` | ^2.5.0 | In-app PDF viewing |
| `pdf_render` | ^1.4.0 | Page rendering, thumbnails, OCR input |
| `syncfusion_flutter_pdf` | ^27.2.2 | AES-256 encrypt/decrypt |
| `file_picker` | ^8.0.0+1 | Document selection |
| `image_picker` | ^1.1.2 | Camera/gallery access |
| `camera` | ^0.11.0 | Document scanner |
| `image` | ^4.1.7 | Image encode/decode/resize |
| `google_mlkit_text_recognition` | ^0.13.0 | Offline OCR |
| `sqflite` | ^2.3.3+1 | SQLite database |
| `path_provider` | ^2.1.3 | App directories |
| `path` | ^1.9.0 | Path join, basename |
| `share_plus` | ^12.0.2 | Native share sheet |
| `google_mobile_ads` | ^5.1.0 | AdMob |
| `flutter_riverpod` | ^2.5.1 | Theme state |
| `shared_preferences` | ^2.2.3 | User preferences |
| `flutter_markdown` | ^0.7.1 | Privacy policy rendering |
| `package_info_plus` | ^8.0.0 | Version display |
| `crypto` | ^3.0.3 | Available (limited direct use) |
| `haptic_feedback` | ^0.5.0 | Available (app uses Flutter's `HapticFeedback`) |

### Dev

| Package | Role |
|---------|------|
| `sqflite_common_ffi` 2.4.0 | Desktop/unit test SQLite |
| `mocktail` | Mocking |
| `flutter_lints` | Lint rules |
| `flutter_launcher_icons` | App icon generation |

---

## 13. Platform Configuration

### Android (`android/app/src/main/AndroidManifest.xml`)

**Permissions:**

| Permission | Purpose |
|------------|---------|
| `CAMERA` | Document scanning |
| `READ_EXTERNAL_STORAGE` (≤ API 32) | File access |
| `WRITE_EXTERNAL_STORAGE` (≤ API 29) | File saving |
| `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` | Android 13+ media |
| `INTERNET` | AdMob |
| `AD_ID` | Advertising identifier |

**Application:**
- `applicationId`: `com.rank.quickpdf`
- Icon: `@mipmap/launcher_icon`
- `launchMode`: `singleTop`
- AdMob meta-data in `<application>`

**Build (`build.gradle.kts`):**
- `compileSdk 36`
- Release: minify + ProGuard enabled
- Signing from `key.properties` (gitignored)

### iOS / Desktop / Web

Standard Flutter platform folders exist. Primary development and testing target is Android. Desktop platforms support the Flutter scaffold but some plugins (camera, ML Kit) are mobile-specific.

---

## 14. Testing

### Test infrastructure (`test/test_helpers.dart`)

- `initTestDatabase()` — `sqfliteFfiInit()` + `databaseFactoryFfi`
- `FakePathProvider` — redirects all path_provider calls to a temp dir
- `useTempDatabase()` / `disposeTempDatabase()` — per-test isolation

### Test files

| File | Tests | Coverage |
|------|-------|----------|
| `document_database_test.dart` | 5 | Insert/fetch, orphan pruning, delete, favourites, search |
| `home_screen_test.dart` | 4 | Tab labels, FAB visibility, tools headers |
| `pdf_manager_test.dart` | 4 | Thumbnail null cases, page count edge cases |

### Gaps

- No tests for merge/compress/OCR UI flows
- No integration tests
- No ad service tests
- Widget tests requiring live SQLite in `HomeScreen` are limited on Windows without Developer Mode

---

## 15. Source File Index

```
lib/
├── main.dart                          # App entry, theme, AdMob init
├── core/
│   ├── pdf_manager.dart               # All PDF operations (static)
│   └── pdf_processor.dart             # Isolate for image→PDF
├── providers/
│   └── theme_provider.dart            # Riverpod theme notifier
├── services/
│   ├── ad_service.dart                # AdMob singleton
│   ├── document_database.dart         # SQLite + ChangeNotifier
│   ├── error_logger.dart              # File-based error log
│   ├── file_picker_service.dart       # File/image picking
│   ├── ocr_service.dart               # ML Kit text recognition
│   ├── scanner_service.dart           # Camera + image enhancement
│   └── share_service.dart             # share_plus wrapper
└── ui/
    ├── main_nav_page.dart             # 3-tab shell + banner ad
    ├── onboarding_screen.dart         # First-run intro
    ├── home_screen.dart               # Library + tools tab (largest file)
    ├── tools_screen.dart              # Full tool catalog
    ├── settings_screen.dart           # Preferences + storage
    ├── merge_screen.dart
    ├── split_screen.dart
    ├── compress_screen.dart
    ├── convert_screen.dart
    ├── format_converter_screen.dart
    ├── ocr_text_screen.dart
    ├── export_text_screen.dart
    ├── scanner_screen.dart
    ├── page_manager_screen.dart
    ├── watermark_screen.dart
    ├── password_protect_screen.dart
    ├── pdf_security_screen.dart       # EditMetadataScreen
    ├── annotate_pdf_screen.dart
    ├── sign_pdf_screen.dart
    ├── batch_screen.dart
    ├── pdf_viewer_screen.dart
    └── widgets/
        └── search_delegate.dart       # Global document search
```

---

## 16. Known Gaps & Technical Debt

| Issue | Impact | Location |
|-------|--------|----------|
| **Settings `default_image_quality` not consumed** | User preference has no effect on compress/convert defaults | `SettingsScreen` saves; tool screens use hardcoded values |
| **Settings `ocr_language` not wired** | Language dropdown is cosmetic | `OcrService` always uses default `TextRecognizer()` |
| **Page rotation not saved** | Rotate preview in UI but output ignores rotation | `page_manager_screen.dart` |
| **Annotate save incomplete** | Strokes may not appear in saved PDF | `annotate_pdf_screen.dart` |
| **Duplicate tools UI** | Home tools tab is a subset of ToolsScreen — can drift | `home_screen.dart` vs `tools_screen.dart` |
| **Windows path handling** | Many files use `path.split('/')` instead of `basename()` | ~20 files across `lib/ui/` and `lib/core/` |
| **`flutter_markdown` discontinued** | Should migrate to `flutter_markdown_plus` | `pubspec.yaml` |
| **Rewarded ad unit ID** | Uses same ID as interstitial (placeholder) | `ad_service.dart` |
| **Rasterize-all strategy** | Vector PDFs lose text selectability after most edits | Architectural — by design for reliability |

---

*Generated from source analysis of QuickPDF v1.0.1+6. For build and release instructions, see `README.md`. For the original shorter doc, see `DOCUMENTATION.md`.*
