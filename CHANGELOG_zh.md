## 0.0.9

试读保护、数据安全与打包
* 试读限制现在覆盖文本搜索（窗口外结果被过滤并计数）、恢复位置、书签/高亮/朗读/媒体叠加字幕和自动滚动；EPUB 边界按“失败即关闭”处理（无法解析的章节边界不会暴露更多内容）。条漫、漫画、PDF 到窗口末尾后只触发一次下一章/付费请求。
* 修复数据丢失：进度/位置缓存并在销毁时保存；笔迹不再互相覆盖；书签写入统一加锁；同步回调（`ReaderSyncHub`）串行执行，宿主回调抛错不再影响阅读器（新增可选 `onError`）。
* 修复 EPUB 内部链接（相对路径、`../`、片段链接；找不到锚点只告警不报错）、多自定义字体、按需计算章节边界与非致命错误；EPUB 字节分块传输；可选 `rtl`；朗读语言取 `NovelReader.ttsLanguage` 或书籍 `dc:language`（引擎实现新增的 `NovelTtsLanguageAware`），长章节分段朗读（`chunkForTts`）。
* 打包：签名文件（`key.properties`、`*.jks`）不再被 Git 跟踪，示例工程在没有 `key.properties` 时回退调试签名（见 `example/android/key.properties.example`），固定依赖改为 `^` 范围，新增 `unorm_dart`，`.pubignore` 排除示例/文档/测试。

新增功能
* 音量键翻页（`ReaderSettings.volumeKeyPaging`，默认关闭）、`ReaderStats`/`ReaderStatsTracker` 及 `ComicReader`/`NovelReader`/`PdfReader` 的 `onStats`、`ReaderSyncConflictPolicy`、`ReaderBookmarkStore.updateHighlightNote`、`ComicReader.onNextChapterRequested`、`loadReaderCustomFont`、`ChineseTextConverter`（单字映射，仅常用字）。
* 东南亚界面预设 `ReaderStrings.th` / `vi` / `id` / `ms` / `fil`，以及 `ReaderStrings.forLocale` / `forLanguageCode`。
* 条漫连续滚动（`ComicReadingMode.webtoon`、`ComicWebtoonView`）、可选漫画自动裁边（`ReaderSettings.comicAutoCrop`、`CroppedImageProvider`）、`NovelReader.customFonts`（文本走 `FontLoader`，EPUB 走 `@font-face`；同一字体族名只取一份）、工具栏/笔迹/对话框文案可本地化。
* 依赖：`material_ui` ^1.11.1、`archive` 4.7.1、`crypto` 3.0.8、`synchronized` 3.6.1+1、`wakelock_plus` 1.8.2；新增回归测试（`test/trial_limit_test.dart` 等）。

文本
* 分页以完整行结束（不再断词）并对大文件分时片执行（`paginateTextAsync`）；编码检测支持 BOM、HTML `<meta charset>` 并对旧编码打分（GB18030、Big5、Shift_JIS、EUC-KR、Windows-874/1258/1252）；Markdown/HTML 标题生成目录，章节检测支持中、英、泰、越、印尼、马来、菲律宾语标题；解码 HTML 实体。
* 搜索使用 Unicode 规范化（NFC，无结果时可忽略变音符号重试），按字素截取摘要，并显示试读窗口外的命中数。

界面、多语言与无障碍
* **行为变更：** `strings` 默认改为 `ReaderStrings.auto`，跟随环境 `Locale`（zh、zh-Hant、en、th、vi、id、ms、fil；其他回退英文）。如需旧行为请显式传入 `ReaderStrings.zh`。
* 新增繁体预设 `ReaderStrings.zhHant` 与约 25 个新字段（提示、搜索/空状态、EPUB/PDF 错误、页码文案），润色马来/印尼/菲律宾/越南语。
* 所有图标按钮加 tooltip，滑块语义（当前值、增减），去除重复语义，工具栏溢出时可滚动，使用方向感知内边距并支持 RTL 双页/EPUB 方向。
* `PageReaderToolbar.currentPage/totalPages` 取代已弃用的 `pageLabel`；PDF 不再提供条漫模式。

统计、性能与健壮性
* `ReaderStatsTracker` 使用单调 `Stopwatch`，切后台暂停，忽略快速滑过的页面（`minDwell`），与 `persistProgress` 无关。
* 条漫：实测高度、`ComicWebtoonController.jumpToIndex`、到头/到尾回调、页数变化时更新；自动裁边只分析缩略图且不再泄漏图片。
* PDF：加密文档给出本地化提示，URL 下载有超时与 300 MB 上限，光栅化最多 2 路并发。设置保存合并写入，书籍字节哈希有缓存，`ReaderBrightness` 吞掉插件异常，所有阅读器都处理音量键重复事件。
* 存储后端由 `shared_preferences` 迁移到 `tostore`（所有键 `isGlobal: true`）；新增 GitHub Actions CI；`ReaderBrightness`/`ReaderWakeLock`/`NovelReader` 的静默异常改为调试日志。
* 导出 `NovelBytesSource`；`ReaderTrialLimit`、`NovelTypography`、`ReaderSettings` 实现 `==`/`hashCode`。

已知限制（未在真机验证）：PDF 仍需先扫描全部页数才显示首页；加密 PDF 的识别依赖平台错误文本；Android 编码别名、超大 EPUB 与读屏体验未在真机测试。

## 0.0.8

* 修复试读越界、绝对页码进度、文本格式和分页、竖向跳转、稳定书籍 ID 与异步阅读生命周期。
* 修复 EPUB 搜索与异步桥接，隔离书籍脚本，约束章节试读窗口，并修正平台支持说明。
* 增加 PDF 有限缓存、CBZ 自然排序与异步解压、串行书签写入、按位置保存和导出笔迹。
* 共享漫画/PDF 控件，保留并弃用旧兼容接口，更新依赖并补充回归测试。
* 保留旧存储键并提供显式迁移；旧漫画页码按当前布局迁移。

## 0.0.7

* 升级依赖：`material_ui` ^1.6.0、`archive` 4.4.0、`printing` 5.15.1、`shared_preferences` 2.5.6、`wakelock_plus` 1.8.1；要求 Flutter >=3.47 / Dart 3.13+
* Android 工具链：AGP 9.4.2、Kotlin 2.4.21、Gradle 9.8.0、NDK 30.0.16248370

## 0.0.6

* 升级依赖：`material_ui` ^1.4.0、`wakelock_plus` 1.8.0、`archive` 4.3.0
* 补全 `homepage` 为 `https://github.com/whevether/phantasm_read`

## 0.0.4

* 升级依赖：`material_ui` ^1.1.0、`wakelock_plus` 1.8.0、
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
