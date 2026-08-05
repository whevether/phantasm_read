# phantasm_read

跨平台 Flutter 漫画 / 小说阅读器 package（纯 Dart UI，无自研 MethodChannel）。

[English](README.md)

## 功能

| 模块 | 实现 |
|------|------|
| 漫画 | `extended_image: 10.1.0`（`ExtendedImageGesturePageView` + 手势缩放） |
| EPUB | 离线 `epub.js` + `webview_flutter: 4.14.1` |
| 文本 | `.txt` / `.md` / `.html`（Dart 渲染，UTF-8 / GBK） |
| 阅读方向 | 漫画竖滑/横翻（含 RTL）；小说竖滚/横翻 |
| 章节 | EPUB 目录选章；文本按标题识别（`第x章` / `Chapter N` / `#`） |
| 主题色 | 小说背景/前景色板 + `ReaderSettings` |
| 亮度 | `screen_brightness`，不支持时遮罩降级 |
| 不熄屏 | `wakelock_plus` |
| 小说字体 | 字号 / 行高 / 字体家族 |

## 快速使用

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

## 平台说明

- 漫画 / 文本：Android、iOS、Web、macOS、Windows、Linux
- EPUB：优先 Android / iOS；桌面依赖 `webview_flutter` 平台实现；Web 需 JS interop 路径（当前返回明确提示）
- 本地文件页（`fromFiles` / 文本路径）：Web 不支持，请用 `fromUrls` / `fromBytes` 或非 Web 平台

## 示例

```bash
cd example
flutter run
```

## 开发约定

实现细节遵循仓库内 Agent Skill：`.cursor/skills/flutter-reader-plugin/`。

## 修改日志

见 [CHANGELOG_zh.md](CHANGELOG_zh.md)（中文）与 [CHANGELOG.md](CHANGELOG.md)（英文）。
