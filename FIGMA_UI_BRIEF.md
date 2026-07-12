# QuickPDF — Figma AI Design Brief

> Paste this into Figma AI / Figma Make as the product & UI context for redesigning the app.
> Goal: produce a modern, mobile-first UI system and key screens for **QuickPDF**.

---

## 1. Product snapshot

**Product name:** QuickPDF  
**One-liner:** An offline-first PDF workstation for phone and tablet.  
**Platform:** Mobile app (Android / iOS first; tablet-friendly layouts matter).  
**Audience:** Students, freelancers, and office workers who need fast PDF tasks without uploading files to the cloud.

**Core promise**
- All document work happens on-device
- Privacy-first (no account required)
- Fast utility workflows: scan → edit → share

**Monetization (UI implications only)**
- Free tier shows a small banner ad above the bottom navigation
- Optional “Remove Ads” premium purchase in Settings
- Occasional full-screen interstitial after completing several tools
- Do **not** design splash ads, interstitial walls on every tap, or ad-heavy home clutter

---

## 2. Brand & visual direction

**Brand name treatment:** “QuickPDF” should feel like a product mark, not a generic utility title. Prefer a confident wordmark + simple mark (document/PDF glyph is fine if refined).

**Current seed palette (evolve, don’t copy blindly)**
- Primary: deep navy `#1A237E`
- Accent: amber `#FFB300`
- Surfaces: clean Material-like light mode + true dark mode
- Semantic colors for tools (merge orange, compress red, OCR indigo, lock blue-grey, etc.) — keep colorful tool identity, but unify into a disciplined system

**Design principles for the redesign**
1. **Utility first** — every screen has one clear job
2. **Document as hero** — thumbnails, page previews, and file names dominate over marketing chrome
3. **Fast paths** — primary actions within 1–2 taps from Home
4. **Calm density** — information-rich without dashboard clutter
5. **Trust & privacy** — offline/privacy cues should feel quiet and confident, not loud badges everywhere
6. **Touch-friendly** — large hit targets, clear secondary actions in overflow menus
7. **Adaptive** — phone portrait default; scale gracefully to large phones and tablets (2 → 4 → 6 column document grids)

**Typography**
- Expressive but readable product sans for UI
- Strong hierarchy: screen title / section label / file name / metadata
- Avoid generic Inter-only look if proposing a distinctive system; keep OCR/editor screens highly legible

**Motion**
- Short, purposeful: tab switches, document open hero, tool completion success, import progress pill
- No decorative noise

---

## 3. Information architecture

### Top-level shell
Persistent bottom navigation (3 destinations) + optional ad banner strip above it:

1. **Home**
2. **Tools**
3. **Settings**

### Home (document library hub)
Home itself has an inner tab bar:
- **Recent** — document library
- **Tools** — abbreviated tool shortcuts (subset of full Tools catalog)

**FAB on Recent only:** “Add document” opens a sheet:
- Scan Document
- Import from Files
- Images to PDF

### Tools (full catalog)
Grouped list / grid of all PDF utilities (see section 5).

### Settings
Appearance, processing defaults, storage, premium/ads, privacy, about.

### Global overlays / system UI
- Onboarding (first launch)
- Search (document search)
- PDF viewer / image viewer
- Tool screens pushed on top of the shell
- Floating import progress pill (non-blocking)
- Snackbars for success/errors

---

## 4. Key user flows to design

1. **First open** → Onboarding (4 screens) → Home Recent  
2. **Add file** → FAB → Import / Scan / Images→PDF → file appears in Recent  
3. **Open document** → tap card → PDF Viewer (or Image Viewer) with hero thumbnail transition  
4. **Run a tool** → Tools (or Home Tools) → pick files → configure → process with progress → open result / return to library  
5. **Search** → App bar search → results → open document  
6. **Remove ads** → Settings → Premium → purchase / restore  
7. **Unlock encrypted PDF** → Password Protect / Unlock → optional biometric save prompt  

---

## 5. Screen inventory (what Figma should produce)

### A. System & shell
- App icon concepts
- Splash / launch feel (simple; no marketing carousel on every launch)
- Bottom nav + banner ad slot (ad is a reserved rectangle; do not invent fake ad content beyond a labeled placeholder)
- Light + dark themes

### B. Onboarding (4 pages)
Theme: navy gradient currently; redesign allowed if brand-consistent.  
Pages:
1. Privacy First — files never leave device  
2. All-in-One Utility — scan, merge, compress, sign…  
3. Lightweight & Powerful  
4. Works 100% Offline  
Actions: Skip / Next / Get Started

### C. Home — Recent (library)
Must include:
- App bar with brand title + search
- Inner tabs: Recent | Tools
- Search field
- Filter chips: All / PDF / Image
- Sort control + grid/list toggle
- Document **grid cards** (thumbnail, type badge, favourite star, filename, size, relative date)
- Document **list rows** (thumbnail, name, type chip, size, date, overflow menu)
- Empty state with CTAs: **Scan Document** + **Import Files**
- Loading skeleton matching card/list layout (shimmer)
- Long-press / overflow actions: Open, Details, Share, Rename, Delete
- File details bottom sheet (thumbnail, path, dates, PDF metadata)
- FAB “+”
- Responsive grid: 2 cols phone / 4 tablet / 6 large

### D. Home — Tools (shortcut list)
Grouped tool tiles with icon, title, subtitle, chevron.  
Groups shown on Home (subset): Create, PDF Tools, Convert & Extract, Organise, Security & Metadata

### E. Tools screen (full catalog)
Same tile language, fuller set and groups:
- **Create:** Scan Document, Images to PDF, Import Files  
- **PDF Tools:** Merge PDFs, Split PDF, Compress PDF  
- **Convert & Extract:** Format Converter, Extract Text (OCR), Export Text  
- **Annotate & Sign:** Annotate PDF, Sign PDF  
- **Batch:** Batch Processing  
- **Organise:** Page Manager, Watermark  
- **Security & Metadata:** Password Protect, Edit Metadata  

### F. Tool screens (design patterns, not every pixel identical)
Create consistent templates:
1. **File picker / selected files header**
2. **Options panel** (sliders, chips, toggles, reorderable lists)
3. **Primary sticky CTA** (“Merge”, “Compress”, “Protect”…)
4. **Progress state** (determinate when possible)
5. **Success state** with Open / Share / Done

Priority tool UIs to design explicitly:
- Merge (multi-file order + page selection)
- Split (range / extract pages)
- Compress (quality presets + custom slider)
- Scan (camera capture + page strip)
- OCR Extract Text (results + copy/export)
- Page Manager (reorderable page thumbnails, rotate, delete)
- Watermark (text, opacity, position)
- Password Protect / Unlock (tabs; biometric unlock affordance)
- Annotate (pen/highlighter toolbar + page canvas)
- Sign (draw signature → place on page)
- Batch (select many → choose operation)
- Format Converter (PDF↔images)

### G. Viewers
- **PDF Viewer:** app bar with filename + page count, vertical scroll pages, night mode, go-to-page, share, optional thumbnail strip, floating page counter  
- **Image Viewer:** dark full-bleed, pinch-zoom, share

### H. Settings
Sections:
- Appearance (theme: system/light/dark)
- Processing defaults (image quality slider, OCR language)
- Storage (documents size, clear cache)
- Premium (Remove Ads purchase + restore)
- Ads toggle (hidden/disabled when premium)
- Privacy policy viewer
- About / version

### I. Search
Full-screen search of library by filename / OCR text; result rows with thumbnail.

### J. Micro-UI
- Import progress floating pill: “Importing files…” + progress + count  
- Confirmation dialogs (delete, etc.)  
- Bottom sheets (quick add, file options, details)

---

## 6. Content & component checklist for Figma

**Components to systemize**
- Nav bar item
- Ad banner placeholder (standard 320×50-ish slot)
- Document card / list item
- Filter chip
- Tool list tile / tool icon container
- Primary / secondary / destructive buttons
- FAB
- Empty state block
- Progress pill
- Settings section card
- Form controls: slider, dropdown, segmented control, switch
- Page thumbnail tile (for page manager / split / merge)

**Sample content**
- Filenames like `Lease_Agreement.pdf`, `Scan_Receipt_12.jpg`, `Thesis_Chapter_3.pdf`
- Metadata: `2.4 MB · 12 pages · Opened 2h ago`
- Empty copy: “No documents yet” / “Scan a document or import files to get started”

---

## 7. What “good” looks like for this redesign

- Home feels like a personal document vault, not a marketing landing page  
- Tools feel like a well-organized toolkit, not a wall of identical cards  
- Processing screens feel guided and calm  
- Privacy is communicated through clarity and offline confidence, not sticker spam  
- Ads are present but visually secondary  
- Tablet layouts use extra width for grids and side-by-side tool options where natural  

---

## 8. Explicit instructions for Figma AI

Please generate:
1. A compact **design system** (color, type, radius, elevation, components)
2. High-fidelity frames for: Onboarding, Home Recent (populated + empty + loading), Home Tools, Tools catalog, Settings, PDF Viewer, Merge, Compress, Scan, Password Protect
3. Light and dark variants for the shell and Home
4. A mobile frame set (390×844) plus at least one tablet Home (e.g. 1024×1366)
5. Component variants for document card (favourite on/off, PDF vs image)
6. Keep product name **QuickPDF** visible as a brand signal on Home/onboarding

Do **not**:
- Invent cloud sync, accounts, social feeds, or analytics dashboards
- Turn the first screen into a promo landing page with stats/cards clutter
- Hide primary document actions behind deep menus
- Make ads the visual focus of any screen

---

## 9. Current app reality (for reference)

QuickPDF already ships as a Flutter app with the IA above. This brief is for a **UI redesign**, not a product pivot. Preserve capabilities; elevate craft, hierarchy, and consistency.
