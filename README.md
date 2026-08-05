<p align="center">
  <img src="docs/logo.jpeg" alt="phantasm_read" width="160"/>
</p>

# phantasm_read

Cross-platform Flutter comic / novel / PDF reader package (`0.0.1`).

[中文文档](README_zh.md)

## Install

```yaml
dependencies:
  phantasm_read: ^0.0.1
```

License: [MIT](LICENSE)

```dart
import 'package:phantasm_read/phantasm_read.dart';
```

## Quick start

```dart
ComicReader(
  bookId: 'comic_1',
  pages: ComicPages.fromUrls(imageUrls),
  settings: const ReaderSettings(brightness: 0.8, keepScreenOn: true),
);

NovelReader(
  bookId: 'book_1',
  source: NovelSource.text('/path/to/book.txt'),
  settings: const ReaderSettings(
    typography: NovelTypography(fontSize: 18, lineHeight: 1.6),
    // novelReadingMode defaults to horizontal (book-style paging)
  ),
);

PdfReader(
  bookId: 'pdf_1',
  source: PdfSource.bytes(pdfBytes),
);
```

---

## Feature overview

| Area | Summary |
|------|---------|
| Comic | Multi-source / CBZ, vertical & horizontal, RTL, zoom, double-page, fit, thumbs, bookmarks, trial, watermark, ink, sync hook |
| Novel | EPUB + txt/md/html, search, nested TOC, themes, TTS, media overlay, bookmarks/highlights, watermark, ink |
| PDF | `pdf` 3.13.0 + `printing` raster, paging, zoom, watermark, trial, progress |
| Shared | Settings / progress / bookmark stores, brightness, wakelock, tap zones, progress bar, JSON export, `onSync` |

---

## Comic (`ComicReader`)

Powered by `extended_image` **10.1.0**.

### Sources

| API | Description |
|-----|-------------|
| `ComicPages.fromFiles` | Local image file paths |
| `ComicPages.fromUrls` | Remote image URLs |
| `ComicPages.fromBytes` | In-memory image bytes |
| `ComicArchive.fromBytes` | CBZ/ZIP → sorted jpg/png/gif/webp/bmp pages |

### Reading & display

- Modes: `ComicReadingMode.vertical` / `horizontal` (toolbar switchable)
- RTL: `rtl` (reverses horizontal paging and tap zones)
- Double-page: `ReaderSettings.doublePage` (horizontal only)
- Fit: `ComicFitMode.contain` / `width` / `height`
- Background: black / gray / white (`comicBackground`)
- Gesture zoom (~1×–4×); double-tap toggles 1× ↔ 2.5×
- Neighbor precache (including second page in double-page)
- Loading indicator; failed loads can retry

### Navigation & progress

- Swipe pages; drag top `ReaderProgressBar`; jump-to-page dialog
- Thumbnail grid jump
- Keyboard / volume keys (reversed under RTL)
- Tap zones: prev / toggle toolbar / next (`tapZonesEnabled`)
- Trial: `trialLimit` + `onTrialLimitReached` (blocks out-of-range navigation and callbacks to host; **no built-in dialog/overlay**)
- Persistence: `persistProgress` → `ReaderProgressStore`
- Callbacks: `onPageChanged`, `onSessionTick` (~30s), `onSync`

### Bookmarks & toolbar

- Toggle bookmark on current page; bookmark list (jump / delete)
- Watermark: `watermarkText`
- Freehand ink: `enableInk`
- Optional toolbar: `showToolbar`; immersive chrome: `immersive`
- Toolbar: page label, progress, brightness, direction, fit, double-page, bookmarks, thumbs, keep-awake, background, jump

### Constructor highlights

`pages` · `bookId` · `readingMode` · `settings` · `rtl` · `initialPage` · `persistProgress` · `persistSettings` · `trialLimit` · `onTrialLimitReached` · `watermarkText` · `enableInk` · `pageTurnEffect` · `onPageChanged` · `onSettingsChanged` · `onSessionTick` · `onSync` · `showToolbar`

```dart
ComicReader(
  bookId: 'comic_1',
  pages: ComicPages.fromUrls(urls),
  readingMode: ComicReadingMode.horizontal,
  trialLimit: ReaderTrialLimit.pages(3, startPage: 0),
  onTrialLimitReached: (event) {
    // Dialog, SnackBar, paywall, etc. — host decides
    // event.limit / currentIndex / targetIndex / totalCount / action
  },
  watermarkText: 'user@example.com',
  enableInk: true,
  onSync: (payload) async { /* upload progress / bookmarks */ },
);
```

---

## Novel (`NovelReader`)

EPUB and common text formats.

### Sources (`NovelSource`)

| Format | Factories |
|--------|-----------|
| EPUB | `epub` / `epubAsset` / `epubUrl` / `epubBytes` |
| TXT | `text` / `textAsset` / `textUrl` / `textBytes` |
| Markdown | `markdown` / `markdownAsset` |
| HTML | `html` / `htmlAsset` |

Also: `NovelBytesSource.file` / `asset` / `url` / `bytes`.

### EPUB (offline epub.js + WebView)

- Bundled `assets/epubjs/` (no CDN)
- Flow: `paginated` / `scrolled` (follows `NovelReadingMode`)
- `EpubViewerController`: chapters, paging, search, current CFI
- Typography / theme colors synced into epub.js via JS bridge
- Resume: `initialCfi`; `onLocationChanged` (CFI)
- TOC: `onChaptersLoaded` / `onChapterChanged`

### Text (txt / md / html)

- Encoding: UTF-8 with GBK / GB18030 fallback; optional `encoding`
- Strip HTML tags; light Markdown cleanup
- Vertical: scrollable selectable text
- Horizontal: paragraph pagination + `PageView` (`rtl` supported)
- Chapter heuristics: `第×章` / `Chapter N` / `# heading`
- Search: `searchParagraphs` → `NovelSearchHit`
- APIs: `jumpToParagraph` / `nextPage` / `prevPage`

### Navigation, typography & toolbar

- Prev/next chapter & page, chapter tree, full-text search
- Bookmarks (CFI or paragraph index), highlights (stored excerpt; yellow on text path)
- Font size / line height / margins / letter spacing / align
- Font chips: `NovelFontOption.defaults`
- Themes: `NovelThemePreset.defaults` (Cream / White / Sepia / Green / Dark / AMOLED)
- Vertical ↔ horizontal, brightness, keep-awake
- Auto-scroll (**text path**), TTS, media-overlay play/pause
- Top progress bar seeks by chapter ratio (trial-aware readable range)
- Keyboard / volume keys; tap zones
- Trial: `trialLimit` (counts **chapters**) + `onTrialLimitReached`; body truncation; callbacks on chapter list / search / paging overflow
- Watermark / ink: `watermarkText` / `enableInk`

### TTS & audio

| API | Role |
|-----|------|
| `FlutterTts` | Speaks **current text paragraph** |
| `MediaOverlayCue` + `MediaOverlayPlayer` | Timed karaoke cues; `mediaOverlaySource` + `mediaOverlayCues`; `onKaraokeCue` |
| `AudiobookController` | Standalone `playFile` / `playUrl` (not wired into reader toolbar) |

### Constructor highlights

`source` · `bookId` · `settings` · `encoding` · `initialCfi` · `persistProgress` · `persistSettings` · `trialLimit` · `onTrialLimitReached` · `watermarkText` · `enableInk` · `mediaOverlayCues` · `mediaOverlaySource` · callbacks · `showToolbar` · `rtl`

```dart
NovelReader(
  bookId: 'novel_1',
  source: NovelSource.epub('/path/to/book.epub'),
  trialLimit: ReaderTrialLimit.chapters(3, startChapter: 0),
  onTrialLimitReached: (event) { /* host UI */ },
  watermarkText: 'trial',
  enableInk: true,
  mediaOverlaySource: UrlSource('https://example.com/narration.mp3'),
  mediaOverlayCues: const [
    MediaOverlayCue(startMs: 0, endMs: 2000, paragraphIndex: 0),
  ],
  onSync: (payload) async {},
);
```

Export bookmarks / highlights:

```dart
final json = await ReaderBookmarkStore.instance.exportJson('novel_1');
```

---

## PDF (`PdfReader`)

Uses **`pdf` 3.13.0** + **`printing` 5.15.0**: [Printing.raster](https://pub.dev/packages/printing) converts each page to a bitmap. Works on **Linux / Windows / Android / iOS / macOS** (desktop via printing’s bundled pdfium).

### Implemented

| Feature | Notes |
|---------|-------|
| Sources | `PdfSource.file` / `PdfSource.bytes` |
| Render | `Printing.raster` per-page bitmap; `InteractiveViewer` pinch zoom |
| Navigation | Swipe, tap zones, arrow / volume keys, top progress seek |
| Brightness / wake | `ReaderSettings.brightness`, `keepScreenOn` |
| Watermark | `watermarkText` |
| Trial | `trialLimit` caps readable pages + `onTrialLimitReached` (no built-in overlay) |
| Progress | `persistProgress` stores `pageIndex` + `percentage` |
| Callback | `onPageChanged` |
| Tuning | `rasterDpi` (default 120) |

```dart
PdfReader(
  bookId: 'doc_1',
  source: PdfSource.file('/path/to/doc.pdf'),
  trialLimit: ReaderTrialLimit.pages(5, startPage: 0),
  onTrialLimitReached: (event) { /* host UI */ },
  watermarkText: 'CONFIDENTIAL',
  rasterDpi: 120,
);
```

---

## Trial (`ReaderTrialLimit`)

All three readers use `trialLimit` for the preview window and `onTrialLimitReached` to report overflow attempts. **The package does not show trial-end UI** — dialogs, snackbars, and overlays are up to the host.

### Configuration

| Field | Meaning |
|-------|---------|
| `maxCount` | Readable pages (comic/PDF) or chapters (novel) |
| `startIndex` | First readable page/chapter (0-based) |
| `unit` | `ReaderTrialUnit.page` or `.chapter` |

Factories:

```dart
ReaderTrialLimit.pages(3, startPage: 0);       // comic / PDF
ReaderTrialLimit.chapters(3, startChapter: 0); // novel
```

### Callback `ReaderTrialLimitEvent`

| Field | Meaning |
|-------|---------|
| `limit` | Active trial config |
| `currentIndex` | Current page/chapter index |
| `targetIndex` | Page/chapter the user tried to reach |
| `totalCount` | Total pages/chapters |
| `action` | `next` · `seek` · `chapterSelect` · `search` |

### Behavior summary

| Reader | Unit | Package behavior |
|--------|------|------------------|
| Comic | page | Truncates `PageView`; callbacks on page next/seek/thumb overflow |
| Novel | chapter | Truncates body paragraphs; callbacks on chapter/search/paging overflow |
| PDF | page | Truncates `PageView`; callbacks on page next/seek overflow |

Legacy helpers: `trialPageCount` · `clampTrialPage` · `trialLimited` · `atTrialEnd`.

---

## Platform support

| Platform | Comic | Novel (text) | Novel (EPUB) | PDF |
|----------|-------|--------------|--------------|-----|
| Android / iOS | ✓ | ✓ | ✓ | ✓ |
| Linux / Windows / macOS | ✓ | ✓ | ✓ (`webview_flutter`) | ✓ (`printing` / pdfium) |
| Web | ✓ (URL images) | ✓ (asset / url / bytes) | WebView + assets required | pdf.js required |

Notes:

- **Linux / Windows**: local `file` paths work; EPUB uses WebView; PDF does not rely on system WebView PDF embed.
- Desktop **TTS / system brightness** may be limited (brightness falls back to overlay).
- On web, `NovelSource.*(path)` / `ComicPages.fromFiles` throw `UnsupportedError` — use asset / url / bytes.

---

## Shared APIs

### Settings

| API | Role |
|-----|------|
| `ReaderSettings` | Brightness, keep-awake, novel typography/colors/mode, comic fit/double-page/bg, tap zones, immersive |
| `ReaderSettingsStore` | SharedPreferences persistence |
| `NovelTypography` | Size, line height, font, letter spacing, align, margins |
| `NovelThemePreset` / `NovelFontOption` | Theme & font presets |

### Progress / bookmarks / sync

| API | Role |
|-----|------|
| `ReaderProgress` + `ReaderProgressStore` | Page / CFI / paragraph / percentage |
| `ReaderBookmark` / `ReaderHighlight` + `ReaderBookmarkStore` | Bookmarks, highlights, `exportJson` |
| `ReaderSyncHub` / `ReaderSyncPayload` / `onSync` | Host hook after local changes (no built-in upload) |

### Display & interaction

| API | Role |
|-----|------|
| `ReaderBrightness` / `BrightnessOverlay` | System brightness with overlay fallback |
| `ReaderWakeLock` | `wakelock_plus` |
| `ReaderImmersive` | Immersive system UI |
| `TapZoneDetector` / `TapZoneAction` | Prev / toolbar / next (RTL aware) |
| `ReaderProgressBar` | Top progress bar |
| `ReaderWatermark` | Watermark overlay |
| `ReaderTrialLimit` / `ReaderTrialLimitEvent` / `onTrialLimitReached` | Trial window + overflow callback |
| `trialPageCount` / `clampTrialPage` / `trialLimited` / `atTrialEnd` | Trial helpers (wrap `ReaderTrialLimit.pages`) |
| `InkAnnotationLayer` / `InkStroke` | Freehand ink, undo/clear, JSON |
| `PageCurl` / `CurlPageView` / `PageTurnEffect` | Page-curl helpers (standalone) |
| `MediaOverlayPlayer` / `AudiobookController` | Audio + karaoke |

---

## Known limitations

| Item | Status |
|------|--------|
| `ComicReader.pageTurnEffect` | Declared; comic path still uses `ExtendedImageGesturePageView` — use `CurlPageView` yourself |
| Comic double-page | Horizontal only; enabling double-page auto-switches from vertical |
| EPUB trial | Chapter-level blocking + callbacks; in-book paging may need host handling at deep jumps |
| EPUB TTS | Text path speaks current paragraph; EPUB does not read body text |
| Auto-scroll | Text path only |
| Media overlay → EPUB | Karaoke jumps by paragraph, not CFI |
| Novel bookmark/highlight list UI | Persist yes; no list sheet (comic has bookmark list) |
| Ink | Drawable via `enableInk`; no toolbar undo/clear; not persisted by default |
| Large PDFs | Page rasterization; high page count / `rasterDpi` increases memory and load time |
| Android PDF | System `PdfRenderer` requires **PDF 1.7+**, unencrypted; older/hand-written PDFs may fail |
| Markdown / HTML URL | No `*Url` factories (file / asset only) |
| Local file paths | May `UnsupportedError` on web — prefer asset / url / bytes |
| `onSync` | Host hook only; no cloud upload inside the package |

---

## Example app

```bash
cd example
flutter pub get
flutter run
```

| Entry | Demo |
|-------|------|
| Comic | Remote images, 3-page trial (default dialog feedback), ink, `onSync` snackbar, bookmark export |
| Novel (text) | 12-chapter sample, 3-chapter trial, themes / TTS, JSON export, sync |
| PDF | 5-page in-memory sample, 3-page trial, `onTrialLimitReached` demo |

Example **Advanced settings** configure trial count, start page/chapter, and feedback style (dialog / SnackBar / none).

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) / [CHANGELOG_zh.md](CHANGELOG_zh.md).

---

<p align="center">
  <img src="docs/pay.jpg" alt="Support the author" width="240"/>
</p>

<p align="center">If you find this project helpful, please consider supporting me.</p>
