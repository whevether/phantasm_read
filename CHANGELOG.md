## 0.0.3

* Migrate UI imports to standalone `material_ui` (^1.0.1); require Flutter >=3.44 / Dart 3.12+
* Gesture zoom: comic supports pinch + double-tap (`ExtendedImage` 1x–4x); novel pinch adjusts font size (text via `ReaderFontPinchGesture`, EPUB via epub.js); PDF keeps `InteractiveViewer` 0.8x–4x
* Web: skip `screen_brightness` (unsupported) and use overlay dimming; avoid re-applying brightness on font-only setting changes

## 0.0.2

* Comic / novel / PDF: tap toggles toolbar only; trial end via swipe sentinel page
* PDF: comic-aligned toolbar, bookmarks, thumbs, ink, sync, RTL, double-page, immersive, `PdfSource.url`
* PDF FAB safe-area inset; example loads online demo PDF

## 0.0.1
Full feature list: [README.md](README.md).

### Comic

* Sources: `ComicPages.fromFiles` / `fromUrls` / `fromBytes`; CBZ/ZIP via `ComicArchive.fromBytes`
* Vertical / horizontal, RTL, double-page (horizontal; auto-switches from vertical when enabled), fit modes, backgrounds, gesture + double-tap zoom, neighbor precache
* Progress seek, jump dialog, thumbnails, volume / keyboard keys, tap zones
* Bookmark list, trial `ReaderTrialLimit` + `onTrialLimitReached`, watermark, ink, `onSync`, brightness / wakelock / immersive

### Novel

* EPUB (offline epub.js) + txt / md / html; file / asset / url / bytes sources
* Encoding UTF-8 / GBK / GB18030; chapter tree, search, bookmarks, highlights
* Typography, fonts, theme presets; vertical / horizontal (default horizontal)
* Trial by chapter: `ReaderTrialLimit.chapters` + `onTrialLimitReached`; body truncation + overflow callbacks
* TTS: optional `NovelTtsEngine` injection (host wires `flutter_tts`, etc.); auto-scroll (text), media overlay / karaoke, watermark, ink, `onSync`

### PDF

* `PdfReader`: `PdfSource.file` / `bytes`; `pdf` 3.13.0 + `printing` raster; Linux / Windows supported
* Trial `ReaderTrialLimit.pages` + `onTrialLimitReached`

### Shared

* Settings / progress / bookmark stores (`exportJson`), brightness, wakelock, tap zones, progress bar
* `ReaderTrialLimit` / `ReaderTrialLimitEvent` / `ReaderTrialLimitCallback`
* `PageCurl` / `CurlPageView`, `InkAnnotationLayer`, `MediaOverlayPlayer` / `AudiobookController`

### Docs & example

* Detailed bilingual READMEs (trial API + known limitations)
* Example: comic / 12-chapter novel / 5-page PDF; default 3-page/chapter trial; configurable start index and feedback (dialog / SnackBar / none)
