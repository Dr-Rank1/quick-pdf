# QuickPDF — UI Design Reference

> **Source of truth:** Figma Make export `Exciting App UI Design.zip`  
> **Canonical implementation preview:** [`design_reference/canonical/App.tsx`](design_reference/canonical/App.tsx)  
> **Figma file:** https://www.figma.com/design/0XXOVXAXVoBepm5XdlYjvb/Exciting-App-UI-Design  
> Use this document when implementing or regenerating Flutter UI. Do **not** invent a new visual system.

---

## 1. Product

**QuickPDF** — offline-first PDF workstation for phone.  
No accounts, no cloud sync. Brand wordmark: **Quick** + amber **PDF**.

---

## 2. Design tokens (from canonical App)

### Typography
- Family: **Plus Jakarta Sans** (400 / 500 / 600 / 700 / 800)
- Screen titles: 22px / weight 800
- Body labels: 13px / weight 600
- Metadata: 10–11px / muted
- Section labels: 11px / weight 700 / uppercase / letter-spacing 0.08em

### Color — Dark (default)
| Token | Hex | Use |
|-------|-----|-----|
| `APP_BG` | `#0B0E1C` | App chrome background |
| `SURFACE` | `#141828` | Cards, nav, sheets |
| `SURFACE2` | `#1B2036` | Inputs, icon wells, secondary fills |
| `BORDER` | `rgba(255,255,255,0.07)` | Hairline borders |
| `TEXT` | `#EEF1FF` | Primary text |
| `MUTED` | `#8891AA` | Secondary text / icons |
| `AMBER` | `#FFB300` | Accent, FAB, active nav, brand “PDF” |
| `NAVY` | `#1E2E8E` | Active home tab pill, premium gradient base |

### Color — Light
| Token | Hex |
|-------|-----|
| `APP_BG` | `#F2F4FF` |
| `SURFACE` | `#FFFFFF` |
| `SURFACE2` | `#E6EAF8` |
| `BORDER` | `rgba(0,0,0,0.07)` |
| `TEXT` | `#0D1130` |
| `MUTED` | `#6271A0` |
| `AMBER` / `NAVY` | same as dark |

### Shape & spacing
- Card radius: **12px** (list cards 10px)
- Icon well radius: **10px** (settings wells 8px)
- FAB: **52px** circle, amber fill, black icon, soft amber glow
- Phone content frame reference: **390 × 844**
- Horizontal padding: **16px**
- Grid: **2 columns**, gap **10px**

### Tool accent colors (icon wells)
Scan `#2196F3` · Images `#9C27B0` · Merge `#FF6B35` · Split `#FF9800` · Compress `#E53935` · OCR `#3F51B5` · Converter `#00BCD4` · Annotate `#FF9800` · Sign `#4CAF50` · Page Manager `#795548` · Watermark `#009688` · Lock `#607D8B` · Metadata `#8BC34A` · Batch `#FFB300`

---

## 3. Shell layout (bottom → top)

1. Home indicator (system)
2. **Ad banner** — 44px tall, dashed 320×50 placeholder (hide when premium)
3. **Bottom nav** — Home / Tools / Settings  
   - Active: amber icon + amber label + amber-tinted pill behind icon  
   - Inactive: muted
4. Screen content
5. Status / title area inside each screen

**Viewer** hides bottom nav + ad banner (full-bleed dark chrome).

---

## 4. Screens to match exactly

### Home
- Wordmark: `Quick` in text color + `PDF` in amber
- Search icon button (surface2, rounded 10)
- Segmented tabs: **Recent** | **Tools** (active = navy filled pill, white label)
- **Recent**
  - Search field (surface2, rounded 12)
  - Chips: All / PDF / Image (active = amber border + amber tint)
  - Grid/list toggle
  - Section: `RECENT · N FILES`
  - Doc cards: thumbnail mock (lined page + PDF/IMG badge), favourite star, name, `size · date`
  - Amber circular FAB → popover: Scan / Import / Images to PDF
- **Tools** (home subset): Create, PDF Tools, Convert & Extract, Annotate & Sign — `ToolTile` rows

### Tools (full catalog)
- Title + subtitle: “All PDF utilities — 100% on-device”
- Groups: Create, PDF Tools, Convert & Extract, Annotate & Sign, Organise, Security, Batch
- Same `ToolTile` pattern: 40×40 tinted icon well, title, desc, chevron

### Settings
- Theme (system / light / dark)
- Processing: image quality, OCR language
- Clear cache
- Privacy policy, version, licences
- **No Remove Ads / premium** — ads are permanent in the product

### PDF Viewer
- Near-black chrome (`#0A0A0A` / `#0E0E0E`)
- Back, filename, pages/size, Share, Download
- Vertical page stack with amber border on selected page
- Bottom pager: ‹ · page / total · ›

---

## 5. Components checklist

Implement in Flutter to match canonical `App.tsx`:
- [ ] Theme tokens (light/dark) + Plus Jakarta Sans
- [ ] Brand wordmark
- [ ] BottomNav (amber active)
- [ ] AdBanner placeholder slot
- [ ] DocThumbnail / DocCard (grid + list)
- [ ] FavStar
- [ ] Filter chips
- [ ] ToolTile + SectionLabel
- [ ] SectionCard + SettingRow + Toggle
- [ ] FAB + add-document menu
- [ ] Viewer chrome + page stack

---

## 6. Implementation rules

1. **Match this design** — layout, spacing, radii, and colors from `design_reference/canonical/App.tsx`
2. Preserve existing QuickPDF **features & navigation IA** (tools already in the Flutter app); this file defines **look & feel**
3. Dark mode is the primary showcase; light mode must use the LIGHT token set
4. Ads stay visually secondary (placeholder strip only)
5. Do not reintroduce purple-gradient marketing hero, cream/terracotta, or dense newspaper layouts
6. When unsure, open `App.tsx` and copy structure — it is the reference, not a suggestion

---

## 7. Files in repo

| Path | Role |
|------|------|
| `Exciting App UI Design.zip` | Original Figma Make export |
| `design_reference/canonical/App.tsx` | Full interactive UI reference |
| `design_reference/canonical/Screenshots.tsx` | Play Store screenshot layouts |
| `design_reference/canonical/theme.css` | CSS variable mirror |
| `design_reference/canonical/fonts.css` | Plus Jakarta Sans import |
| `FIGMA_UI_BRIEF.md` | This implementation brief |
| `store_assets/` | Icon, feature graphic, screenshots, AAB |
