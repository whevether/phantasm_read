# phantasm_read

Cross-platform Flutter package for comic and novel reading (Dart UI; no custom MethodChannel).

[中文文档](README_zh.md)

## Features

| Area | Implementation |
|------|----------------|
| Comic | `extended_image: 10.1.0` (`ExtendedImageGesturePageView` + gesture zoom) |
| EPUB | Offline `epub.js` + `webview_flutter: 4.14.1` |
| Text | `.txt` / `.md` / `.html` (Dart rendering, UTF-8 / GBK) |
| Reading direction | Comic vertical/horizontal (+ RTL); novel vertical scroll / horizontal paging |
| Chapters | EPUB TOC picker; text heading detection (`第x章` / `Chapter N` / `#`) |
| Theme colors | Novel background / foreground presets via toolbar + `ReaderSettings` |
| Brightness | `screen_brightness`, overlay fallback when unsupported |
| Keep screen on | `wakelock_plus` |
| Novel typography | Font size / line height / font family |

## Quick start

```dart
import 'package:phantasm_read/phantasm_read.dart';

ComicReader(
  pages: ComicPages.fromUrls(imageUrls),
  readingMode: ComicReadingMode.vertical,
  settings: const ReaderSettings(brightness: 0.8, keepScreenOn: true),
);

NovelReader(
  source: NovelSource.text('/path/to/book.txt'),
  settings: const ReaderSettings(
    typography: NovelTypography(fontSize: 18, lineHeight: 1.6),
  ),
);

NovelReader(
  source: NovelSource.epub('/path/to/book.epub'),
);
```

## Platforms

- Comic / text: Android, iOS, Web, macOS, Windows, Linux
- EPUB: Android / iOS first; desktop depends on `webview_flutter` platform support; Web needs a JS interop path (explicit message today)
- Local file pages (`fromFiles` / text paths): not supported on Web — use `fromUrls` / `fromBytes` or a non-Web platform

## Example

```bash
cd example
flutter run
```

## Development notes

Implementation guidance lives in the repo Agent Skill: `.cursor/skills/flutter-reader-plugin/`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) (English) and [CHANGELOG_zh.md](CHANGELOG_zh.md) (Chinese).
