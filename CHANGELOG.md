## 0.0.9

Trial protection, data safety and packaging
* Trial limits are now enforced in text search (results outside the window are filtered and counted), restored positions, bookmarks/highlights/TTS/media-overlay cues and auto-scroll; EPUB boundaries fail closed (an unresolvable chapter edge never exposes more content). Webtoon, comic and PDF stop at the window and request the next chapter or paywall exactly once.
* Fix data loss: progress/location is cached and saved on dispose; ink strokes no longer overwrite each other; bookmark writes serialize through one lock; sync callbacks (`ReaderSyncHub`) are serialized and a throwing host callback can no longer break a reader (new optional `onError`).
* Fix EPUB internal links (relative/`../`/fragment links, missing anchors report a warning instead of an error), multiple custom fonts, per-chapter boundary resolution on demand and non-fatal errors; EPUB bytes are uploaded in chunks; optional `rtl`; TTS language follows `NovelReader.ttsLanguage` or the book's `dc:language` (engines implement the new `NovelTtsLanguageAware`) and long chapters are read in chunks (`chunkForTts`).
* Packaging: signing files (`key.properties`, `*.jks`) are no longer tracked, the example falls back to debug signing without `key.properties` (see `example/android/key.properties.example`), pinned dependencies became `^` ranges, `unorm_dart` was added and `.pubignore` keeps examples/docs/tests out of the package.

New features
* Volume-key paging (`ReaderSettings.volumeKeyPaging`, off by default), `ReaderStats`/`ReaderStatsTracker` with `onStats` on `ComicReader`, `NovelReader` and `PdfReader`, `ReaderSyncConflictPolicy`, `ReaderBookmarkStore.updateHighlightNote`, `ComicReader.onNextChapterRequested`, `loadReaderCustomFont` and `ChineseTextConverter` (character-level, common characters only).
* Southeast Asian UI presets `ReaderStrings.th` / `vi` / `id` / `ms` / `fil` with `ReaderStrings.forLocale` / `forLanguageCode`.
* Webtoon continuous scroll (`ComicReadingMode.webtoon`, `ComicWebtoonView`), opt-in comic auto-crop (`ReaderSettings.comicAutoCrop`, `CroppedImageProvider`), `NovelReader.customFonts` (text via `FontLoader`, EPUB via `@font-face`; one font per family name), localisable toolbar/ink/dialog strings.
* Dependencies: `material_ui` ^1.11.1, `archive` 4.7.1, `crypto` 3.0.8, `synchronized` 3.6.1+1, `wakelock_plus` 1.8.2; new regression tests (`test/trial_limit_test.dart`, ...).

Text
* Pagination ends pages on complete lines (no mid-word cuts) and runs in time slices for large books (`paginateTextAsync`); encoding detection sniffs BOM, HTML `<meta charset>` and scores legacy encodings (GB18030, Big5, Shift_JIS, EUC-KR, Windows-874/1258/1252); markdown/HTML headings become chapters, chapter detection understands Chinese, English, Thai, Vietnamese, Indonesian, Malay and Filipino headings; HTML entities are decoded.
* Search is Unicode-normalised (NFC, optional diacritic-insensitive retry), grapheme-safe excerpts, shows how many hits lie outside the trial window.

UI, i18n and accessibility
* **Behaviour change:** `strings` now defaults to `ReaderStrings.auto`, which follows the ambient `Locale` (zh, zh-Hant, en, th, vi, id, ms, fil; others fall back to English). Pass `ReaderStrings.zh` to keep the old default.
* New `ReaderStrings.zhHant` preset and about 25 new fields (tooltips, search/empty states, EPUB/PDF errors, page labels); translation polish for ms/id/fil/vi.
* Tooltips for all icon buttons, slider semantics (value, increase/decrease), duplicate semantics removed, toolbar scrolls instead of overflowing, directional paddings and RTL double-page/EPUB direction.
* `PageReaderToolbar.currentPage/totalPages` replace the deprecated `pageLabel`; PDF no longer offers webtoon mode.

Stats, performance and robustness
* `ReaderStatsTracker` uses a monotonic `Stopwatch`, pauses in the background, ignores fly-by pages (`minDwell`), counts independent of `persistProgress`.
* Webtoon: measured heights, `ComicWebtoonController.jumpToIndex`, end/start callbacks, page changes when the count changes; auto-crop analyses a thumbnail and no longer leaks images.
* PDF: encrypted documents show a localised hint, URL downloads have a timeout and 300 MB cap, rasterisation is limited to two concurrent jobs. Settings saves are coalesced, book-byte identity hashes are cached, `ReaderBrightness` swallows plugin errors, volume-key repeats are handled in all readers.
* Export `NovelBytesSource`; `ReaderTrialLimit`, `NovelTypography` and `ReaderSettings` implement `==`/`hashCode`.

Known limitations (not verified on real devices): PDF page counting still scans the whole document before the first page is shown; encrypted-PDF detection depends on the platform's error text; Android encoding aliases, very large EPUBs and screen-reader behaviour were not tested on hardware.

## 0.0.8

* Fix trial boundaries, absolute progress, text decoding/pagination, vertical navigation, stable book IDs and asynchronous reader lifecycle.
* Repair EPUB search and async bridge, isolate book scripts, enforce chapter preview windows and correct platform support documentation.
* Add bounded PDF rasters, natural CBZ ordering and async decoding, serialized bookmark writes, and per-location ink persistence/export.
* Share comic/PDF controls, retain deprecated compatibility APIs, update dependencies and add regression coverage.
* Preserve old storage keys and provide explicit migration helpers; legacy comic positions migrate using the current layout.

## 0.0.7

* Bump dependencies: `material_ui` ^1.6.0、`archive` 4.4.0、`printing` 5.15.1、`shared_preferences` 2.5.6、`wakelock_plus` 1.8.1; require Flutter >=3.47 / Dart 3.13+
* Android toolchain: AGP 9.4.2、Kotlin 2.4.21、Gradle 9.8.0、NDK 30.0.16248370

## 0.0.6

* Bump dependencies: `material_ui` ^1.4.0、`wakelock_plus` 1.8.0、`archive` 4.3.0
* Fix `homepage` to `https://github.com/whevether/phantasm_read`

## 0.0.4

* Bump dependencies: `material_ui` ^1.1.0, `wakelock_plus` 1.8.0,
* Fix `homepage` to `https://github.com/whevether/phantasm_read`

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
