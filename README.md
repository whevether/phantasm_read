<p align="center">
  <img src="docs/logo.jpeg" alt="phantasm_read" width="160"/>
</p>

# phantasm_read

Cross-platform Flutter comic / novel / PDF reader package (`0.0.9`).

[中文文档](README_zh.md)

## Install

```yaml
dependencies:
  phantasm_read: ^0.0.9
```

Host prerequisites: wrap your `MaterialApp` content in `MaterialUiCompatibilityBridge` (from `material_ui`) when you mix it with Material widgets, and make sure `audioplayers` can run on your target platforms (media overlay / audiobook). The reader resolves its UI language from the ambient `Locale` (`strings` defaults to `ReaderStrings.auto`); pass `ReaderStrings.zh` etc. to pin a language.

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
| PDF | `printing` raster (`pdf` is transitive); comic-aligned toolbar / bookmarks / trial / ink / sync |
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
- RTL: `rtl` (reverses horizontal swipe direction)
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
- Tap anywhere: toggle toolbar only (no tap-to-page; page via swipe / keys / toolbar)
- Trial: `trialLimit` + `onTrialLimitReached` (swipe overscroll at the trial edge callbacks to host; **no built-in dialog/overlay**)
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
- Auto-scroll (text and EPUB), TTS, media-overlay play/pause
- Top progress bar seeks by chapter ratio (trial-aware readable range)
- Keyboard / volume keys; tap anywhere toggles toolbar only (page via swipe / toolbar)
- Trial: `trialLimit` (counts **chapters**) + `onTrialLimitReached`; body truncation; swipe overscroll / chapter list / search / toolbar overflow callbacks
- Watermark / ink: `watermarkText` / `enableInk`

### TTS & audio

| API | Role |
|-----|------|
| `NovelTtsEngine` | Optional injection; speaks **current text paragraph** (toolbar toggle). Wire `flutter_tts` (or similar) in the host app on mobile; toolbar button hidden when omitted — macOS/desktop builds avoid the native plugin |
| `MediaOverlayCue` + `MediaOverlayPlayer` | Timed karaoke cues; `mediaOverlaySource` + `mediaOverlayCues`; `onKaraokeCue` |
| `AudiobookController` | Standalone `playFile` / `playUrl` (not wired into reader toolbar) |

```dart
// Host app: add flutter_tts to pubspec and implement NovelTtsEngine
class FlutterTtsEngine implements NovelTtsEngine {
  FlutterTtsEngine() : _tts = FlutterTts();
  final FlutterTts _tts;
  @override
  Future<void> speak(String text) => _tts.speak(text);
  @override
  Future<void> stop() => _tts.stop();
  @override
  void setCompletionHandler(VoidCallback? handler) {
    _tts.setCompletionHandler(handler);
  }
  @override
  void dispose() {}
}

NovelReader(
  ttsEngine: FlutterTtsEngine(),
  // ...
);
```

### Constructor highlights

`source` · `bookId` · `settings` · `encoding` · `initialCfi` · `persistProgress` · `persistSettings` · `trialLimit` · `onTrialLimitReached` · `watermarkText` · `enableInk` · `mediaOverlayCues` · `mediaOverlaySource` · `ttsEngine` · callbacks · `showToolbar` · `rtl`

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

Uses **`printing` 5.15.1** (`pdf` is a transitive dependency): [Printing.raster](https://pub.dev/packages/printing) converts each page to a bitmap. Works on **Linux / Windows / Android / iOS / macOS** (desktop via printing’s bundled pdfium). Page-based features align with `ComicReader` (no novel-only TTS / chapter TOC / text search).

### Implemented

| Feature | Notes |
|---------|-------|
| Sources | `PdfSource.file` / `PdfSource.bytes` / `PdfSource.url` |
| Render | Per-page bitmap; `InteractiveViewer` zoom; `comicFitMode` |
| Navigation | Vertical/horizontal, RTL, double-page; tap toggles toolbar; keys; progress seek; jump |
| Toolbar | Brightness, mode, fit, double-page, bookmarks, thumbs, keep-awake, background |
| Brightness / wake / immersive | `ReaderSettings` + `ReaderImmersive` |
| Watermark / ink | `watermarkText` / `enableInk` |
| Trial | `trialLimit` + swipe-past-end → `onTrialLimitReached` |
| Persistence | `persistProgress` / `persistSettings` |
| Callbacks | `onPageChanged` · `onSettingsChanged` · `onSessionTick` · `onSync` |
| Tuning | `rasterDpi` (default 120) · `readingMode` · `rtl` |

```dart
PdfReader(
  bookId: 'doc_1',
  source: PdfSource.url('https://example.com/doc.pdf'),
  // or PdfSource.file(...) / PdfSource.bytes(...)
  readingMode: ComicReadingMode.horizontal,
  rtl: false,
  trialLimit: ReaderTrialLimit.pages(5, startPage: 0),
  onTrialLimitReached: (event) { /* host UI */ },
  watermarkText: 'CONFIDENTIAL',
  enableInk: true,
  persistSettings: true,
  onSync: (payload) async { /* cloud sync */ },
  rasterDpi: 120,
);
```

---

## Trial (`ReaderTrialLimit`)

All three readers use `trialLimit` for the preview window and `onTrialLimitReached` to report overflow attempts. On comic/novel/PDF, swiping past the trial edge triggers the callback (tap never pages). **The package does not show trial-end UI** — dialogs, snackbars, and overlays are up to the host.

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
| Comic | page | Truncates `PageView`; swipe overscroll / seek / thumb overflow callbacks (tap does not page) |
| Novel | chapter | Truncates body paragraphs; swipe overscroll / chapter / search / toolbar overflow callbacks (tap does not page) |
| PDF | page | Truncates `PageView`; swipe past trial end / seek overflow callbacks (tap does not page) |

Legacy helpers: `trialPageCount` · `clampTrialPage` · `trialLimited` · `atTrialEnd`.

---

## Platform support

| Platform | Comic | Novel (text) | Novel (EPUB) | PDF |
|----------|-------|--------------|--------------|-----|
| Android / iOS | ✓ | ✓ | ✓ | ✓ |
| macOS | ✓ | ✓ | ✓ (`webview_flutter`) | ✓ (`printing` / pdfium) |
| Linux / Windows | ✓ | ✓ | Unsupported with a visible fallback message | ✓ (`printing` / pdfium) |
| Web | ✓ (URL images) | ✓ (asset / url / bytes) | Unsupported with a visible fallback message | pdf.js (network required by default) |

Notes:

- **Linux / Windows**: local `file` paths work; EPUB is not supported by the bundled WebView backend; PDF does not rely on system WebView PDF embed.
- Desktop **TTS / system brightness** may be limited (brightness falls back to overlay).
- **macOS sandbox**: `ComicPages.fromUrls` requires `com.apple.security.network.client` in host entitlements for outbound HTTP/HTTPS; the example app includes this.
- On web, `NovelSource.*(path)` / `ComicPages.fromFiles` throw `UnsupportedError` — use asset / url / bytes.

---

## Shared APIs

### Settings

| API | Role |
|-----|------|
| `ReaderSettings` | Brightness, keep-awake, novel typography/colors/mode, comic fit/double-page/bg, `tapZonesEnabled` (PDF), immersive |
| `ReaderSettingsStore` | ToStore persistence (`lib/src/common/reader_kv.dart`, keys use `isGlobal: true`) |
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
| `TapZoneDetector` / `TapZoneAction` | Legacy helpers; comic / novel / PDF taps toggle toolbar only |
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
| `ComicReader.pageTurnEffect` | Applied to horizontal paging via `PageCurl`; vertical and webtoon modes scroll without curl |
| Comic double-page | Horizontal only; enabling double-page auto-switches from vertical |
| EPUB trial | Chapter-level blocking + callbacks; in-book paging may need host handling at deep jumps |
| TTS | Text path speaks the current paragraph, EPUB the visible page text; long text is read in chunks. Set `NovelReader.ttsLanguage` (engine must implement `NovelTtsLanguageAware`) or rely on the EPUB `dc:language` |
| Auto-scroll | Text and EPUB (EPUB: continuous scroll in vertical mode, timed page turns in horizontal mode) |
| Media overlay → EPUB | Karaoke jumps by paragraph, not CFI |
| Novel bookmark/highlight list UI | Persist yes; no list sheet (comic has bookmark list) |
| Ink | `enableInk`; toolbar undo/clear; saved per book and location (`ReaderInk`) |
| Large PDFs | Page rasterization; high page count / `rasterDpi` increases memory and load time |
| Android PDF | System `PdfRenderer` requires **PDF 1.7+**, unencrypted; older/hand-written PDFs may fail |
| Markdown / HTML URL | No `*Url` factories (file / asset only) |
| Local file paths | May `UnsupportedError` on web — prefer asset / url / bytes |
| `onSync` | Host hook only; no cloud upload inside the package |
| Screenshot protection | Not provided (by design) |
| MOBI/AZW3/FB2/CBR/RAR | Not built in; see [docs/format_feasibility.md](docs/format_feasibility.md) |
| `ChineseTextConverter` | Character-level only, 63 common characters, no phrase conversion |
| Webtoon mode | `ComicReadingMode.webtoon` (`ComicWebtoonView`); the orientation button cycles vertical / horizontal / webtoon |
| Auto-crop | `ReaderSettings.comicAutoCrop` (off by default); trims uniform margins up to 20% per side on readable pages only, cached by `ImageCache` |
| Custom fonts | `NovelReader.customFonts`: `FontLoader` for text, `@font-face` for EPUB. Registering another font under the same family name is ignored for text (Flutter cannot unload fonts) |
| Volume keys | `ReaderSettings.volumeKeyPaging` works where the platform delivers volume keys to Flutter (Android hardware keys while the reader has focus); key repeats are swallowed |
| Web text encodings | Without `charset_converter` on Web, GBK/Big5/Shift_JIS decoding uses the platform `TextDecoder`; verify exotic encodings in your target browsers |
| Bookmark titles | Stored empty and derived at display time (`Page N` / `Paragraph N` in the current language); legacy `Page N` titles are localised on read |
| Sync | `ReaderSyncHub` serializes emissions and swallows host errors (observe with `onError`); the package never merges remote data (`ReaderSyncConflictPolicy` is advisory) |
| UI strings | Toolbar, ink buttons, search and typography panel use `ReaderStrings`. `strings` defaults to `ReaderStrings.auto` (follows the ambient `Locale`). Presets: `zh`, `zhHant`, `en`, `th`, `vi`, `id`, `ms`, `fil`; pick with `ReaderStrings.forLocale(Locale)` / `forLanguageCode('th')` (aliases `in`, `tl`; unknown languages fall back to `en`). Pass the result to `strings:` on `ComicReader` / `NovelReader` / `PdfReader` |
| Trial limits | Enforced client-side only; the host passes full content, so real paywalls must serve only the trial range from the server |

---

## Key & signing security

- `*.jks` and `example/android/key.properties` are not tracked and are ignored by `.gitignore`; never commit real keys, passwords or keystores.
- Without a local signing config, the example app's release build falls back to debug signing, so a fresh clone runs out of the box.
- For local release signing, copy `example/android/key.properties.example` to `example/android/key.properties` and fill in the alias, passwords and `storeFile` (see `example/jks/README.md`).
- The example signing is for local packaging only and **must not** be used for production releases.
- If a key file was ever committed, it remains in git history; if it held real passwords, treat them as leaked and rotate the keys.

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
| PDF | `PdfSource.url` sample; full toolbar / bookmarks / ink / sync / trial demo |

Example **Advanced settings** configure trial count, start page/chapter, and feedback style (dialog / SnackBar / none).

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) / [CHANGELOG_zh.md](CHANGELOG_zh.md).

---

<p align="center">
  <img src="docs/pay.jpg" alt="Support the author" width="240"/>
</p>

<p align="center">If you find this project helpful, please consider supporting me.</p>

## State and compatibility

Provide a stable `bookId` when available. Default IDs now derive from source/content SHA-256. Comic/PDF initial pages, progress and bookmarks use zero-based absolute content pages, independent of spreads. Legacy comic positions with an explicit bookId migrate using the current layout. Old default hashCode IDs cannot be reliably mapped back to books; original keys are retained and can be copied with `ReaderProgressStore.instance.migrate(oldId, newId)` and `ReaderBookmarkStore.instance.migrate(oldId, newId)`.

`NovelTypography.copyWith(fontFamily: null)` restores the system font; omitting the argument preserves the existing font. Legacy tap-zone/trial helpers remain deprecated compatibility APIs. A nonpositive trial maxCount continues to mean unlimited, so hosts must validate the value before constructing `ReaderTrialLimit` (a computed 0 would disable the paywall). Trial limits are enforced on the client only: any full content passed to the reader (image bytes, whole EPUB/PDF) can be extracted, so real paywall protection requires the server to deliver only the trial range.

PDF counts pages with tiny 8 DPI rasters and renders full pages on demand, using a 32 MiB raster cache (at most two concurrent rasterisations) and 24 DPI thumbnails. Page counting still takes time for large documents and happens before the first page is shown; encrypted PDFs show a localised hint. URL sources time out after 60 s and are limited to 300 MiB. `ComicArchive.fromBytesAsync` decodes on a worker isolate; archive limits are 64 MiB compressed, 256 MiB uncompressed images and 5000 pages. Ink is saved per book/location with normalized coordinates, undo and clear. EPUB book scripts and external navigation are disabled; preview restrictions apply to navigation, search and rendered chapter content.
