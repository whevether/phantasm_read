<p align="center">
  <img src="docs/logo.jpeg" alt="phantasm_read" width="160"/>
</p>

# phantasm_read

跨平台 Flutter 漫画 / 小说 / PDF 阅读器 package（`0.0.3`）。

[English](README.md)

## 安装

```yaml
dependencies:
  phantasm_read: ^0.0.3
```

许可证：[MIT](LICENSE)

```dart
import 'package:phantasm_read/phantasm_read.dart';
```

## 快速使用

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

## 功能总览

| 模块 | 能力摘要 |
|------|----------|
| 漫画 | 多图源 / CBZ、竖横滑、RTL、缩放、双页、适应、缩略图、书签、试读、水印、手绘、同步回调 |
| 小说 | EPUB + txt/md/html、搜索、嵌套目录、主题排版、TTS、Media Overlay、书签划线、水印、手绘 |
| PDF | `pdf` 3.13.0 + `printing` 光栅化；与漫画对齐的工具栏 / 书签 / 试读 / 手绘 / 同步等 |
| 共用 | 设置 / 进度 / 书签持久化、亮度、不息屏、点击分区、进度条、导出 JSON、`onSync` |

---

## 漫画（`ComicReader`）

基于 `extended_image` **10.1.0**。

### 内容源

| API | 说明 |
|-----|------|
| `ComicPages.fromFiles` | 本地图片路径列表 |
| `ComicPages.fromUrls` | 网络图片 URL 列表 |
| `ComicPages.fromBytes` | 内存图片字节列表 |
| `ComicArchive.fromBytes` | 解析 CBZ/ZIP，按文件名排序提取 jpg/png/gif/webp/bmp |

### 阅读与显示

- 阅读方向：`ComicReadingMode.vertical` / `horizontal`（工具栏可切换）
- 右到左：`rtl`（横向滑动翻页方向对调）
- 双页并排：`ReaderSettings.doublePage`（横向模式）
- 适应模式：`ComicFitMode.contain` / `width` / `height`
- 漫画背景色：黑 / 灰 / 白（`comicBackground`）
- 手势缩放（约 1×–4×），双击在 1× ↔ 2.5× 间切换
- 邻页预加载（含双页第二张）
- 加载中指示；加载失败可重试

### 导航与进度

- 滑动翻页；顶栏进度条拖拽跳页；「跳页」对话框输入页码
- 缩略图网格跳页
- 键盘方向键 / 音量键翻页（RTL 时方向反向）
- 任意点按：仅显隐工具栏（不点按翻页；翻页靠滑动 / 按键 / 工具栏）
- 试读：`trialLimit` + `onTrialLimitReached`（试读边界继续滑动越界时回调宿主；**不内置弹窗/遮罩**，UI 由宿主处理）
- 进度持久化：`persistProgress` → `ReaderProgressStore`
- 回调：`onPageChanged`、`onSessionTick`（约 30s）、`onSync`

### 书签与工具栏

- 当前页书签增删；书签列表（跳转 / 删除）
- 水印：`watermarkText`
- 手绘批注层：`enableInk`
- 可隐藏工具栏：`showToolbar`；沉浸式系统栏：`immersive`
- 工具栏项：页码、进度、亮度、方向、适应、双页、书签、缩略图、不熄屏、背景色、跳页

### 主要构造参数

`pages` · `bookId` · `readingMode` · `settings` · `rtl` · `initialPage` · `persistProgress` · `persistSettings` · `trialLimit` · `onTrialLimitReached` · `watermarkText` · `enableInk` · `pageTurnEffect` · `onPageChanged` · `onSettingsChanged` · `onSessionTick` · `onSync` · `showToolbar`

```dart
ComicReader(
  bookId: 'comic_1',
  pages: ComicPages.fromUrls(urls),
  readingMode: ComicReadingMode.horizontal,
  trialLimit: ReaderTrialLimit.pages(3, startPage: 0),
  onTrialLimitReached: (event) {
    // 弹窗 / SnackBar / 跳转购买页等，由宿主决定
    // event.limit / currentIndex / targetIndex / totalCount / action
  },
  watermarkText: 'user@example.com',
  enableInk: true,
  onSync: (payload) async { /* 上传 progress / bookmarks */ },
);
```

---

## 小说（`NovelReader`）

支持 EPUB 与常见文本格式。

### 内容源（`NovelSource`）

| 格式 | 工厂方法 |
|------|----------|
| EPUB | `epub` / `epubAsset` / `epubUrl` / `epubBytes` |
| TXT | `text` / `textAsset` / `textUrl` / `textBytes` |
| Markdown | `markdown` / `markdownAsset` |
| HTML | `html` / `htmlAsset` |

底层还可直接用 `NovelBytesSource.file` / `asset` / `url` / `bytes`。

### EPUB（离线 epub.js + WebView）

- 内嵌 `assets/epubjs/`，无需外网加载脚本
- 流式：分页 `paginated` / 滚动 `scrolled`（随 `NovelReadingMode`）
- `EpubViewerController`：章节、翻页、搜索、当前 CFI
- 字号 / 行高 / 字体 / 主题色经 JS 桥同步到 epub.js
- 恢复位置：`initialCfi`；回调 `onLocationChanged`（CFI）
- 目录树：`onChaptersLoaded` / `onChapterChanged`

### 文本（txt / md / html）

- 编码：默认 UTF-8，失败回退 GBK / GB18030；也可指定 `encoding`
- HTML 去标签；Markdown 轻量剥格式
- 竖读：`CustomScrollView` + 可选中文本
- 横读：段落分页 + `PageView`（支持 `rtl`）
- 章节启发式识别：`第×章` / `Chapter N` / `# 标题`
- 全文搜索：`searchParagraphs` → `NovelSearchHit`
- API：`jumpToParagraph` / `nextPage` / `prevPage`

### 导航、排版与工具栏

- 上一 / 下一章、上一 / 下一页、章节树、全文搜索
- 书签（CFI 或段落索引）、高亮（段落摘录入库；文本路径有黄底）
- 字号 / 行距 / 边距 / 字距 / 左齐↔两端对齐
- 字体芯片：`NovelFontOption.defaults`（系统 / Serif / Sans / Mono）
- 主题预设：`NovelThemePreset.defaults`（Cream / White / Sepia / Green / Dark / AMOLED）
- 竖读 ↔ 横读切换、亮度、不熄屏
- 自动滚屏（**文本路径**）、TTS、Media Overlay 播放 / 暂停
- 顶栏进度条按章节比例跳转（试读时按可读章节范围）
- 键盘 / 音量键翻页；任意点按只显隐工具栏（翻页靠滑动 / 工具栏）
- 试读：`trialLimit`（按**章**计数）+ `onTrialLimitReached`；正文截断；滑动越界 / 目录 / 搜索 / 工具栏翻章越界时回调宿主
- 水印、手绘：`watermarkText` / `enableInk`

### TTS 与有声

| 能力 | 说明 |
|------|------|
| `NovelTtsEngine` | 可选注入；朗读**当前文本段落**（工具栏开关）。移动端可在宿主 App 中接入 `flutter_tts` 等实现；未注入时不显示朗读按钮，macOS 桌面构建无需该原生插件 |
| `MediaOverlayCue` + `MediaOverlayPlayer` | 按时间轴高亮段落并跳转；`mediaOverlaySource` + `mediaOverlayCues`；`onKaraokeCue` |
| `AudiobookController` | 独立有声辅助（`playFile` / `playUrl`），未绑进阅读器工具栏 |

```dart
// 宿主 App：pubspec 添加 flutter_tts，并实现 NovelTtsEngine
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

### 主要构造参数

`source` · `bookId` · `settings` · `encoding` · `initialCfi` · `persistProgress` · `persistSettings` · `trialLimit` · `onTrialLimitReached` · `watermarkText` · `enableInk` · `mediaOverlayCues` · `mediaOverlaySource` · `ttsEngine` · `onSettingsChanged` · `onLocationChanged` · `onChaptersLoaded` · `onChapterChanged` · `onSessionTick` · `onSync` · `onKaraokeCue` · `showToolbar` · `rtl`

```dart
NovelReader(
  bookId: 'novel_1',
  source: NovelSource.epub('/path/to/book.epub'),
  trialLimit: ReaderTrialLimit.chapters(3, startChapter: 0),
  onTrialLimitReached: (event) { /* 宿主自定义 UI */ },
  watermarkText: 'trial',
  enableInk: true,
  mediaOverlaySource: UrlSource('https://example.com/narration.mp3'),
  mediaOverlayCues: const [
    MediaOverlayCue(startMs: 0, endMs: 2000, paragraphIndex: 0),
  ],
  onKaraokeCue: (cue) {},
  onSync: (payload) async {},
);
```

导出书签 / 划线：

```dart
final json = await ReaderBookmarkStore.instance.exportJson('novel_1');
```

---

## PDF（`PdfReader`）

基于 **`pdf` 3.13.0** + **`printing` 5.15.0**：通过 [Printing.raster](https://pub.dev/packages/printing) 将 PDF 页光栅化为位图，在 **Linux / Windows / Android / iOS / macOS** 上可用（桌面端由 printing 内置 pdfium 支持）。页式能力与漫画阅读器对齐（不含小说专属的 TTS / 章目录 / 正文搜索）。

### 已实现

| 能力 | 说明 |
|------|------|
| 数据源 | `PdfSource.file` / `PdfSource.bytes` / `PdfSource.url` |
| 渲染 | `Printing.raster` 逐页位图；`InteractiveViewer` 缩放；`comicFitMode` 适应 |
| 导航 | 竖/横滑动、RTL、双页、点按只开关工具栏、方向键 / 音量键、顶栏进度条、跳页 |
| 工具栏 | 亮度、方向、适应、双页、书签、书签列表、缩略图、不熄屏、背景色 |
| 亮度 / 常亮 / 沉浸式 | `ReaderSettings` + `ReaderImmersive` |
| 水印 / 手绘 | `watermarkText` / `enableInk` |
| 试读 | `trialLimit` + 滑动越过末页回调 `onTrialLimitReached` |
| 持久化 | `persistProgress` / `persistSettings` |
| 回调 | `onPageChanged` · `onSettingsChanged` · `onSessionTick` · `onSync` |
| 参数 | `rasterDpi`（默认 120）· `readingMode` · `rtl` |

```dart
PdfReader(
  bookId: 'doc_1',
  source: PdfSource.url('https://example.com/doc.pdf'),
  // 或 PdfSource.file(...) / PdfSource.bytes(...)
  readingMode: ComicReadingMode.horizontal,
  rtl: false,
  trialLimit: ReaderTrialLimit.pages(5, startPage: 0),
  onTrialLimitReached: (event) { /* 宿主自定义 UI */ },
  watermarkText: 'CONFIDENTIAL',
  enableInk: true,
  persistSettings: true,
  onSync: (payload) async { /* 云同步 */ },
  rasterDpi: 120,
);
```

---

## 试读（`ReaderTrialLimit`）

三端统一用 `trialLimit` 描述试读窗口，用 `onTrialLimitReached` 把越界事件交给宿主。漫画/小说/PDF 在试读边界继续滑动越界时触发回调（点按不翻页）。**包内不展示试读结束 UI**（弹窗、SnackBar、遮罩等由集成方实现）。

### 配置

| 字段 | 说明 |
|------|------|
| `maxCount` | 可读页数（漫画/PDF）或章数（小说） |
| `startIndex` | 起始页 / 章（0 起） |
| `unit` | `ReaderTrialUnit.page` 或 `.chapter` |

工厂方法：

```dart
ReaderTrialLimit.pages(3, startPage: 0);      // 漫画 / PDF
ReaderTrialLimit.chapters(3, startChapter: 0); // 小说
```

### 回调 `ReaderTrialLimitEvent`

| 字段 | 说明 |
|------|------|
| `limit` | 当前试读配置 |
| `currentIndex` | 当前页 / 章索引 |
| `targetIndex` | 用户试图前往的页 / 章 |
| `totalCount` | 总页数 / 章数 |
| `action` | `next` · `seek` · `chapterSelect` · `search` |

### 行为摘要

| 模块 | 试读单位 | 插件行为 |
|------|----------|----------|
| 漫画 | 页 | 截断 `PageView`；滑动越界 / 跳页 / 缩略图越界时回调（点按不翻页） |
| 小说 | 章 | 截断正文段落；滑动越界 / 目录 / 搜索 / 工具栏翻章越界时回调（点按不翻页） |
| PDF | 页 | 截断 `PageView`；滑动越过试读末页 / 跳页越界时回调（点按不翻页） |

辅助函数（兼容旧写法）：`trialPageCount` · `clampTrialPage` · `trialLimited` · `atTrialEnd`。

---

## 平台支持

| 平台 | 漫画 | 小说（文本） | 小说（EPUB） | PDF |
|------|------|-------------|-------------|-----|
| Android / iOS | ✓ | ✓ | ✓ | ✓ |
| Linux / Windows / macOS | ✓ | ✓ | ✓（`webview_flutter`） | ✓（`printing` / pdfium） |
| Web | ✓（URL 图源） | ✓（asset / url / bytes） | 需 WebView + 资源加载 | 需配置 pdf.js |

说明：

- **Linux / Windows**：本地 `file` 路径可用；EPUB 走 WebView；PDF 不依赖系统 WebView 内嵌 PDF。
- 桌面端 **TTS / 系统亮度** 可能降级或不可用（亮度会回退遮罩层）。
- **macOS 沙盒**：使用 `ComicPages.fromUrls` 加载网络漫画时，宿主 App 需在 entitlements 中启用 `com.apple.security.network.client`（出站 HTTP/HTTPS）；示例工程已配置。
- Web 上 `NovelSource.*(path)` / `ComicPages.fromFiles` 会 `UnsupportedError`，请用 asset / url / bytes。


## 共用能力

### 设置

| API | 说明 |
|-----|------|
| `ReaderSettings` | 亮度、不熄屏、小说排版、前/背景色、小说方向、漫画适应/双页/背景、`tapZonesEnabled`（PDF）、沉浸式 |
| `ReaderSettingsStore` | SharedPreferences 全局持久化（`persistSettings`） |
| `NovelTypography` | 字号、行高、字体、字距、对齐、页边距 |
| `NovelThemePreset` / `NovelFontOption` | 主题与字体预设 |

### 进度 / 书签 / 同步

| API | 说明 |
|-----|------|
| `ReaderProgress` + `ReaderProgressStore` | 页码 / CFI / 段落 / 百分比 |
| `ReaderBookmark` / `ReaderHighlight` + `ReaderBookmarkStore` | 书签、划线、`exportJson` |
| `ReaderSyncHub` / `ReaderSyncPayload` / `onSync` | 本地变更后回调宿主（包内无上传实现） |

### 显示与交互

| API | 说明 |
|-----|------|
| `ReaderBrightness` / `BrightnessOverlay` | 系统亮度；失败时用遮罩降亮度 |
| `ReaderWakeLock` | `wakelock_plus` 不息屏 |
| `ReaderImmersive` | 沉浸式系统栏 |
| `TapZoneDetector` / `TapZoneAction` | 兼容辅助；漫画 / 小说 / PDF 点按一律只开关工具栏 |
| `ReaderProgressBar` | 顶栏进度条 |
| `ReaderWatermark` | 水印叠加 |
| `ReaderTrialLimit` / `ReaderTrialLimitEvent` / `onTrialLimitReached` | 试读窗口与越界回调 |
| `trialPageCount` / `clampTrialPage` / `trialLimited` / `atTrialEnd` | 试读辅助（基于 `ReaderTrialLimit.pages`） |
| `InkAnnotationLayer` / `InkStroke` | 手绘、undo/clear、JSON 序列化 |
| `PageCurl` / `CurlPageView` / `PageTurnEffect` | 仿真翻页组件（可单独使用） |
| `MediaOverlayPlayer` / `AudiobookController` | 有声与卡拉 OK |

---

## 已知限制

| 项 | 现状 |
|----|------|
| `ComicReader.pageTurnEffect` | 参数已声明；漫画主路径仍为 `ExtendedImageGesturePageView`，需自行使用 `CurlPageView` |
| 漫画双页 | 仅横向生效；开启双页时若当前为竖向会自动切横向 |
| EPUB 试读 | 章级拦截与回调；EPUB 内连续翻页越界依赖章节边界，深度跳转可能需宿主配合 |
| EPUB TTS | 文本路径可读当前段；EPUB 侧不朗读正文 |
| 自动滚屏 | 仅文本路径；EPUB 无效 |
| Media Overlay → EPUB | karaoke 按段落跳转，不跟 CFI |
| 小说书签 / 高亮列表 UI | 可增删入库；无独立列表页（漫画有书签列表） |
| 墨迹批注 | `enableInk` 可画；工具栏无撤销/清空入口；默认不持久化 |
| PDF 大文件 | 逐页光栅化，页数多 / `rasterDpi` 高时内存与耗时增加 |
| Android PDF | 系统 `PdfRenderer` 需 **PDF 1.7+**、未加密；低版本或手写 PDF 可能无法渲染 |
| Markdown / HTML URL | 无 `*Url` 工厂（仅 file / asset） |
| 本地文件路径 | Web 等平台上 file 源可能 `UnsupportedError`，请用 asset / url / bytes |
| `onSync` | 仅为宿主钩子，包内不实现云上传 |

---

## 示例应用

```bash
cd example
flutter pub get
flutter run
```

| 入口 | 演示内容 |
|------|----------|
| 漫画阅读器 | 网络图、试读 3 页（默认弹窗反馈）、手绘、`onSync` SnackBar、导出书签 |
| 小说阅读器（文本） | 12 章样例、试读 3 章、主题 / TTS、导出 JSON、同步 |
| PDF 阅读器 | `PdfSource.url` 在线样例；完整工具栏 / 书签 / 手绘 / 同步 / 试读演示 |

示例「高级设置」可配置试读页/章数、起始页/章，以及触顶反馈方式（弹窗 / SnackBar / 无）。

---

## 修改日志

见 [CHANGELOG_zh.md](CHANGELOG_zh.md) / [CHANGELOG.md](CHANGELOG.md)。

---

<p align="center">
  <img src="docs/pay.jpg" alt="支持作者" width="240"/>
</p>

<p align="center">如果觉得这个项目对你有帮助，欢迎支持我。</p>
