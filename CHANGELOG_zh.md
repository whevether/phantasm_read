## 0.0.1
完整功能清单见 [README_zh.md](README_zh.md)。

### 漫画

* 多图源：`ComicPages.fromFiles` / `fromUrls` / `fromBytes`；CBZ/ZIP：`ComicArchive.fromBytes`
* 竖 / 横滑、RTL、双页、适应模式、背景色、手势缩放与双击缩放、邻页预加载
* 进度条跳页、跳页对话框、缩略图、音量键 / 键盘、点击分区
* 书签列表、试读 `maxReadablePages`、水印、手绘、`onSync`、亮度 / 不息屏 / 沉浸式

### 小说

* EPUB（离线 epub.js）+ txt / md / html；多数据源（file / asset / url / bytes）
* 编码 UTF-8 / GBK / GB18030；章节树、搜索、书签、划线
* 字号 / 行距 / 边距 / 字距 / 对齐 / 字体 / 主题预设；竖读 / 横读
* TTS（文本）、自动滚屏（文本）、Media Overlay / 卡拉 OK、水印、手绘、`onSync`

### PDF

* `PdfReader`：`PdfSource.file` / `bytes`；`pdf` 3.13.0 + `printing` 光栅化；Linux / Windows 可用

### 共用

* `ReaderSettings` / Store、进度 / 书签 Store（含 `exportJson`）、亮度、不息屏、点击分区、进度条
* `PageCurl` / `CurlPageView`、`InkAnnotationLayer`、`MediaOverlayPlayer` / `AudiobookController`

### 文档与示例

* 中英文详细 README（含已知限制）
* 示例：漫画 / 小说文本 / 内存 PDF
