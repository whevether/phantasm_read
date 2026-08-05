# phantasm_read

跨平台 Flutter 漫画 / 小说 / PDF 阅读器 package（`0.0.1`）。

[English](README.md)

## 安装

```yaml
dependencies:
  phantasm_read: ^0.0.1
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
| PDF | WebView 打开 PDF、水印、试读遮罩、亮度 / 常亮、进度持久化 |
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
- 右到左：`rtl`（横向翻页方向与点击区对调）
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
- 点击分区：左翻 / 中显隐工具栏 / 右翻（`tapZonesEnabled`）
- 试读：`maxReadablePages` 截断可读页
- 进度持久化：`persistProgress` → `ReaderProgressStore`
- 回调：`onPageChanged`、`onSessionTick`（约 30s）、`onSync`

### 书签与工具栏

- 当前页书签增删；书签列表（跳转 / 删除）
- 水印：`watermarkText`
- 手绘批注层：`enableInk`
- 可隐藏工具栏：`showToolbar`；沉浸式系统栏：`immersive`
- 工具栏项：页码、进度、亮度、方向、适应、双页、书签、缩略图、不熄屏、背景色、跳页

### 主要构造参数

`pages` · `bookId` · `readingMode` · `settings` · `rtl` · `initialPage` · `persistProgress` · `persistSettings` · `maxReadablePages` · `watermarkText` · `enableInk` · `pageTurnEffect` · `onPageChanged` · `onSettingsChanged` · `onSessionTick` · `onSync` · `showToolbar`

```dart
ComicReader(
  bookId: 'comic_1',
  pages: ComicPages.fromUrls(urls),
  readingMode: ComicReadingMode.horizontal,
  rtl: false,
  maxReadablePages: 3,
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
- 顶栏进度条按章节比例跳转
- 键盘 / 音量键翻页；点击分区翻页或调出工具栏
- 水印、手绘：`watermarkText` / `enableInk`

### TTS 与有声

| 能力 | 说明 |
|------|------|
| `FlutterTts` | 朗读**当前文本段落**（工具栏开关） |
| `MediaOverlayCue` + `MediaOverlayPlayer` | 按时间轴高亮段落并跳转；`mediaOverlaySource` + `mediaOverlayCues`；`onKaraokeCue` |
| `AudiobookController` | 独立有声辅助（`playFile` / `playUrl`），未绑进阅读器工具栏 |

### 主要构造参数

`source` · `bookId` · `settings` · `encoding` · `initialCfi` · `persistProgress` · `persistSettings` · `maxReadablePages` · `watermarkText` · `enableInk` · `mediaOverlayCues` · `mediaOverlaySource` · `onSettingsChanged` · `onLocationChanged` · `onChaptersLoaded` · `onChapterChanged` · `onSessionTick` · `onSync` · `onKaraokeCue` · `showToolbar` · `rtl`

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

通过 WebView 加载 `data:application/pdf;base64,…`（**不依赖**原生 pdfium）。

### 已实现

| 能力 | 说明 |
|------|------|
| 数据源 | `PdfSource.file` / `PdfSource.bytes` |
| 显示 | WebView `<embed>` 打开 PDF |
| 亮度 / 常亮 | `ReaderSettings.brightness`、`keepScreenOn` |
| 水印 | `watermarkText` |
| 试读 | `maxReadablePages` 达上限后全屏「试读结束」遮罩 |
| 进度 | `persistProgress` 保存 `pageIndex` |
| 工具栏 | 简易状态栏 + 顶栏进度条（按试读页数估算） |
| 回调 | `onPageChanged`（初始化时由宿主侧触发） |

```dart
PdfReader(
  bookId: 'doc_1',
  source: PdfSource.file('/path/to/doc.pdf'),
  maxReadablePages: 5,
  watermarkText: 'CONFIDENTIAL',
);
```

---

## 共用能力

### 设置

| API | 说明 |
|-----|------|
| `ReaderSettings` | 亮度、不熄屏、小说排版、前/背景色、小说方向、漫画适应/双页/背景、点击区、沉浸式 |
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
| `TapZoneDetector` / `TapZoneAction` | 左翻 / 中工具栏 / 右翻（含 RTL） |
| `ReaderProgressBar` | 顶栏进度条 |
| `ReaderWatermark` | 水印叠加 |
| `clampTrialPage` / `trialPageCount` | 试读页数辅助 |
| `InkAnnotationLayer` / `InkStroke` | 手绘、undo/clear、JSON 序列化 |
| `PageCurl` / `CurlPageView` / `PageTurnEffect` | 仿真翻页组件（可单独使用） |
| `MediaOverlayPlayer` / `AudiobookController` | 有声与卡拉 OK |

---

## 已知限制

| 项 | 现状 |
|----|------|
| `ComicReader.pageTurnEffect` | 参数已声明；漫画主路径仍为 `ExtendedImageGesturePageView`，需自行使用 `CurlPageView` |
| `NovelReader.maxReadablePages` | 字段已暴露；小说正文路径尚未截断（漫画 / PDF 已生效） |
| EPUB TTS | 文本路径可读当前段；EPUB 侧不朗读正文 |
| 自动滚屏 | 仅文本路径；EPUB 无效 |
| Media Overlay → EPUB | karaoke 按段落跳转，不跟 CFI |
| 小说书签 / 高亮列表 UI | 可增删入库；无独立列表页（漫画有书签列表） |
| 墨迹批注 | `enableInk` 可画；工具栏无撤销/清空入口；默认不持久化 |
| PDF 页导航 | 依赖系统 WebView PDF；无可靠翻页 / 页码同步；`percentage` 恒为 0 |
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
| 漫画阅读器 | 网络图、水印、试读 3 页、手绘、`onSync` SnackBar、导出书签 |
| 小说阅读器（文本） | 临时 txt、主题 / TTS、水印、手绘、导出 JSON、同步 |
| PDF 阅读器 | 内存样例 PDF、水印、试读提示 |

---

## 修改日志

见 [CHANGELOG_zh.md](CHANGELOG_zh.md) / [CHANGELOG.md](CHANGELOG.md)。
