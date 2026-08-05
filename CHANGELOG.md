## 0.1.0

Initial release of the comic / novel reader package.

### Features

* Comic reader with `extended_image` 10.1.0: vertical / horizontal paging, pinch zoom, neighbor preload, loading / error placeholders
* Novel EPUB reader with offline `epub.js` + `webview_flutter` 4.14.1 (Dart ↔ JS bridge for open, navigation, CFI, theme, font)
* EPUB chapter TOC: `getToc` / `goToChapter`, in-reader chapter picker
* Novel reading direction: vertical scroll or horizontal paging (`NovelReadingMode`)
* Custom novel background / foreground themes (preset chips + `ReaderSettings`)
* Text novel formats: `.txt`, `.md`, `.html` with UTF-8 / GBK decoding and heading-based chapter jump
* Shared brightness control (system brightness with overlay fallback)
* Keep screen on while reading (`wakelock_plus`)
* Novel typography controls: font size, line height, font family
* Shared `ReaderSettings` for comic and novel
* Example app demos for comic and text novel
* Multi-platform targets: Android, iOS, Web, macOS, Windows, Linux
