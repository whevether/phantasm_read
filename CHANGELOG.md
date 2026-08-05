## 0.0.1
Full feature list: [README.md](README.md).

### Comic

* Sources: `ComicPages.fromFiles` / `fromUrls` / `fromBytes`; CBZ/ZIP via `ComicArchive.fromBytes`
* Vertical / horizontal, RTL, double-page, fit modes, backgrounds, gesture + double-tap zoom, neighbor precache
* Progress seek, jump dialog, thumbnails, volume / keyboard keys, tap zones
* Bookmark list, trial `maxReadablePages`, watermark, ink, `onSync`, brightness / wakelock / immersive

### Novel

* EPUB (offline epub.js) + txt / md / html; file / asset / url / bytes sources
* Encoding UTF-8 / GBK / GB18030; chapter tree, search, bookmarks, highlights
* Typography, fonts, theme presets; vertical / horizontal modes
* TTS (text), auto-scroll (text), media overlay / karaoke, watermark, ink, `onSync`

### PDF

* `PdfReader`: `PdfSource.file` / `bytes`; `pdf` 3.13.0 + `printing` raster; Linux / Windows supported

### Shared

* Settings / progress / bookmark stores (`exportJson`), brightness, wakelock, tap zones, progress bar
* `PageCurl` / `CurlPageView`, `InkAnnotationLayer`, `MediaOverlayPlayer` / `AudiobookController`

### Docs & example

* Detailed bilingual READMEs (including known limitations)
* Example: comic / novel text / in-memory PDF
