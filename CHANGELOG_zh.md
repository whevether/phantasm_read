## 0.0.4

* 升级依赖：`material_ui` ^1.1.0、`wakelock_plus` 1.8.0、`archive` 4.2.0（含 override）
* 补全 `homepage` 为 `https://github.com/whevether/phantasm_read`

## 0.0.3

* UI 迁至独立 `material_ui`（^1.0.1）；要求 Flutter >=3.44 / Dart 3.12+
* 手势缩放：漫画支持 pinch + 双击（`ExtendedImage` 1x–4x）；小说 pinch 调节字号（文本 `ReaderFontPinchGesture`、EPUB epub.js）；PDF 保持 `InteractiveViewer` 0.8x–4x
* Web：跳过不支持的 `screen_brightness`，改用遮罩调光；仅改字体时不再重复 apply 亮度

## 0.0.2

* 漫画 / 小说 / PDF：点按只开关工具栏；试读触顶靠滑动哨兵页
* PDF：对齐漫画工具栏、书签、缩略图、手绘、同步、RTL、双页、全屏、`PdfSource.url`
* PDF FAB 避开虚拟导航栏；示例改为在线 PDF

## 0.0.1
完整功能清单见 [README_zh.md](README_zh.md)。

### 漫画

* 多图源：`ComicPages.fromFiles` / `fromUrls` / `fromBytes`；CBZ/ZIP：`ComicArchive.fromBytes`
* 竖 / 横滑、RTL、双页（横向；开启时自动切横向）、适应模式、背景色、手势缩放与双击缩放、邻页预加载
* 进度条跳页、跳页对话框、缩略图、音量键 / 键盘、点击分区
* 书签列表、试读 `ReaderTrialLimit` + `onTrialLimitReached`、水印、手绘、`onSync`、亮度 / 不息屏 / 沉浸式

### 小说

* EPUB（离线 epub.js）+ txt / md / html；多数据源（file / asset / url / bytes）
* 编码 UTF-8 / GBK / GB18030；章节树、搜索、书签、划线
* 字号 / 行距 / 边距 / 字距 / 对齐 / 字体 / 主题预设；竖读 / 横读（默认横向）
* 试读按章：`ReaderTrialLimit.chapters` + `onTrialLimitReached`；正文截断与越界回调
* TTS：`NovelTtsEngine` 可选注入（宿主接入 `flutter_tts` 等）；自动滚屏（文本）、Media Overlay / 卡拉 OK、水印、手绘、`onSync`

### PDF

* `PdfReader`：`PdfSource.file` / `bytes`；`pdf` 3.13.0 + `printing` 光栅化；Linux / Windows 可用
* 试读 `ReaderTrialLimit.pages` + `onTrialLimitReached`

### 共用

* `ReaderSettings` / Store、进度 / 书签 Store（含 `exportJson`）、亮度、不息屏、点击分区、进度条
* `ReaderTrialLimit` / `ReaderTrialLimitEvent` / `ReaderTrialLimitCallback`
* `PageCurl` / `CurlPageView`、`InkAnnotationLayer`、`MediaOverlayPlayer` / `AudiobookController`

### 文档与示例

* 中英文详细 README（含试读 API 与已知限制）
* 示例：漫画 / 12 章小说 / 5 页 PDF；默认试读 3 页/章；可配置起始页/章与触顶反馈（弹窗 / SnackBar / 无）
