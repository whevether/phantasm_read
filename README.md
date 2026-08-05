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
| PDF | WebView PDF, watermark, trial overlay, brightness / keep-awake, progress persistence |
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
- Trial: `maxReadablePages` caps readable pages
- Persistence: `persistProgress` → `ReaderProgressStore`
- Callbacks: `onPageChanged`, `onSessionTick` (~30s), `onSync`

### Bookmarks & toolbar

- Toggle bookmark on current page; bookmark list (jump / delete)
- Watermark: `watermarkText`
- Freehand ink: `enableInk`
- Optional toolbar: `showToolbar`; immersive chrome: `immersive`
- Toolbar: page label, progress, brightness, direction, fit, double-page, bookmarks, thumbs, keep-awake, background, jump

### Constructor highlights

`pages` · `bookId` · `readingMode` · `settings` · `rtl` · `initialPage` · `persistProgress` · `persistSettings` · `maxReadablePages` · `watermarkText` · `enableInk` · `pageTurnEffect` · `onPageChanged` · `onSettingsChanged` · `onSessionTick` · `onSync` · `showToolbar`

```dart
ComicReader(
  bookId: 'comic_1',
  pages: ComicPages.fromUrls(urls),
  readingMode: ComicReadingMode.horizontal,
  maxReadablePages: 3,
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
- Top progress bar seeks by chapter ratio
- Keyboard / volume keys; tap zones
- Watermark / ink: `watermarkText` / `enableInk`

### TTS & audio

| API | Role |
|-----|------|
| `FlutterTts` | Speaks **current text paragraph** |
| `MediaOverlayCue` + `MediaOverlayPlayer` | Timed karaoke cues; `mediaOverlaySource` + `mediaOverlayCues`; `onKaraokeCue` |
| `AudiobookController` | Standalone `playFile` / `playUrl` (not wired into reader toolbar) |

### Constructor highlights

`source` · `bookId` · `settings` · `encoding` · `initialCfi` · `persistProgress` · `persistSettings` · `maxReadablePages` · `watermarkText` · `enableInk` · `mediaOverlayCues` · `mediaOverlaySource` · callbacks · `showToolbar` · `rtl`

```dart
NovelReader(
  bookId: 'novel_1',
  source: NovelSource.epub('/path/to/book.epub'),
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

Loads PDF via WebView `data:application/pdf;base64,…` (**no** native pdfium).

### Implemented

| Feature | Notes |
|---------|-------|
| Sources | `PdfSource.file` / `PdfSource.bytes` |
| Render | WebView `<embed>` |
| Brightness / wake | `ReaderSettings.brightness`, `keepScreenOn` |
| Watermark | `watermarkText` |
| Trial | `maxReadablePages` full-screen “trial ended” overlay |
| Progress | `persistProgress` stores `pageIndex` |
| Chrome | Simple status + top progress bar (trial-based estimate) |
| Callback | `onPageChanged` (host-driven at init) |

```dart
PdfReader(
  bookId: 'doc_1',
  source: PdfSource.file('/path/to/doc.pdf'),
  maxReadablePages: 5,
  watermarkText: 'CONFIDENTIAL',
);
```

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
| `clampTrialPage` / `trialPageCount` | Trial helpers |
| `InkAnnotationLayer` / `InkStroke` | Freehand ink, undo/clear, JSON |
| `PageCurl` / `CurlPageView` / `PageTurnEffect` | Page-curl helpers (standalone) |
| `MediaOverlayPlayer` / `AudiobookController` | Audio + karaoke |

---

## Known limitations

| Item | Status |
|------|--------|
| `ComicReader.pageTurnEffect` | Declared; comic path still uses `ExtendedImageGesturePageView` — use `CurlPageView` yourself |
| `NovelReader.maxReadablePages` | Exposed; not applied on novel body (comic / PDF do) |
| EPUB TTS | Text path speaks current paragraph; EPUB does not read body text |
| Auto-scroll | Text path only |
| Media overlay → EPUB | Karaoke jumps by paragraph, not CFI |
| Novel bookmark/highlight list UI | Persist yes; no list sheet (comic has bookmark list) |
| Ink | Drawable via `enableInk`; no toolbar undo/clear; not persisted by default |
| PDF page nav | Depends on system WebView PDF; no reliable page sync; `percentage` always 0 |
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
| Comic | Remote images, watermark, 3-page trial, ink, `onSync` snackbar, bookmark export |
| Novel (text) | Temp txt, themes / TTS, watermark, ink, JSON export, sync |
| PDF | In-memory sample PDF, watermark, trial overlay |

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) / [CHANGELOG_zh.md](CHANGELOG_zh.md).
