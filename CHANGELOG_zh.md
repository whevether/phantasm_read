## 0.1.0

漫画 / 小说阅读器 package 首个版本。

### 功能点

* 漫画阅读：`extended_image` 10.1.0，支持竖滑 / 横翻、双指缩放、邻页预加载、加载与失败占位
* 小说 EPUB：离线 `epub.js` + `webview_flutter` 4.14.1（Dart ↔ JS 桥：打开、翻页、CFI、主题、字体）
* EPUB 目录选章：`getToc` / `goToChapter`，阅读页内章节列表
* 小说阅读方向：竖向滚动 / 横向翻页（`NovelReadingMode`）
* 自定义小说背景 / 前景色（主题色板 + `ReaderSettings`）
* 文本小说：支持 `.txt` / `.md` / `.html`，编码探测 UTF-8 / GBK，按标题识别章节并跳转
* 亮度调节：优先系统亮度，不支持时半透明遮罩降级
* 阅读不熄屏（`wakelock_plus`）
* 小说字体调节：字号、行高、字体家族
* 漫画与小说共用 `ReaderSettings`
* 示例 App：漫画与文本小说演示
* 多平台：Android、iOS、Web、macOS、Windows、Linux
