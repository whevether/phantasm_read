# 阅读器依赖更新与代码审查

核查日期：2026 年 10 月 17 日。

用户已授权全部修复。A01–A26 与 R01–R06 均已落实到代码；以下原始问题说明保留作追踪，实际改动见下表。审查覆盖 lib、示例 Dart 代码、EPUB HTML/JS 桥、构建配置、现有测试和平台说明。静态代码确认不等于已经完成全部平台真机验证。

## 依赖结果

| 依赖 | 原配置/资源 | 本次结果 |
|---|---|---|
| material_ui（主包和 example） | ^1.6.0 | ^1.7.0，实际解析 1.7.0 |
| archive | 4.4.0 | 4.5.2 |
| JSZip（内嵌文件） | 3.10.1 | 3.10.2，校验 npm 发布包 SHA-512 后提取 |
| Gradle | 9.8.0 | 9.8.1，使用官方发布地址并写入 SHA-256 |
| Android Gradle Plugin | 9.4.2 | 9.4.1；原 9.4.2 的官方 POM 返回 404，官方元数据最新稳定版为 9.4.1 |
| Kotlin Gradle Plugin | 2.4.21 | 已是最新稳定版 |
| EPUB.js | 已为 0.3.93 | 与 npm 最新发布包的 dist/epub.min.js 逐字节一致，无须替换 |
| extended_image | 10.1.0 | 已是最新稳定版 |
| webview_flutter | 4.14.1 | 已是最新稳定版 |
| screen_brightness | 2.1.11 | 已是最新稳定版 |
| wakelock_plus | 1.8.1 | 已是最新稳定版 |
| charset_converter | 2.5.1 | 已是最新稳定版 |
| shared_preferences | 2.5.6 | 已是最新稳定版 |
| http | 1.6.0 | 已是最新稳定版 |
| path_provider | ^2.1.6 | 实际解析 2.1.6，已是最新稳定版 |
| audioplayers | 6.8.1 | 已是最新稳定版 |
| pdf | 3.13.1 | 删除未使用的直接声明，由 printing 间接依赖 |
| printing | 5.15.1 | 已是最新稳定版 |
| flutter_lints | 6.0.0 / ^6.0.0 | 已是最新稳定版 |

Flutter/Dart SDK 不是本仓库管理的第三方包。本机验证使用 Flutter 3.47.7 / Dart 3.13.5，未修改全局 SDK 安装或仓库最低版本要求。flutter、flutter_test、integration_test 随 SDK 提供。

主包和 example 均执行依赖升级；可解析的间接依赖已经更新。仍有三项不能在当前正常约束下升至最新版：

| 间接依赖 | 当前 → 最新 | 限制来源 |
|---|---|---|
| material_color_utilities | 0.13.0 → 0.13.1 | Flutter SDK 精确锁定 0.13.0 |
| test_api | 0.7.12 → 0.7.15 | flutter_test 精确锁定 0.7.12 |
| qr | 3.0.2 → 4.0.0 | pdf → barcode 2.2.9 → qr ^3.0.0 |

未用 dependency_overrides 绕过上游约束。根包和 example 的 pubspec.lock 均被现有 .gitignore 忽略，本次解析结果保留在本机但不强行加入版本库。macOS 的 Podfile.lock 仅列 FlutterMacOS，不能据此宣称所有原生插件的 CocoaPods 解析已验证。

版本核对来源：[pub.dev 注册表](https://pub.dev)、[EPUB.js 注册表](https://registry.npmjs.org/epubjs/latest)、[JSZip 注册表](https://registry.npmjs.org/jszip/latest)、[Gradle 当前版本](https://services.gradle.org/versions/current)、[Google AGP 元数据](https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/maven-metadata.xml)、[Kotlin Maven 元数据](https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/kotlin-gradle-plugin/maven-metadata.xml)。

## 验证记录

- `flutter analyze --no-pub`：通过，No issues found。
- `flutter test --no-pub`：现有 8 项测试通过。
- `flutter build web --no-pub`（example）：成功；Wasm dry run 成功。构建提示 CupertinoIcons 字体未包含，未因此自动添加新依赖。
- Node：JSZip 3.10.2 压缩/解压往返验证通过；reader.html 内联脚本语法检查通过。
- 9 项临时复现测试全部通过，包括漫画双页试读越界、竖向文本远距离跳转无滚动、Markdown/HTML 文本损坏、长段落分页、默认字体重置、书签并发覆盖、压缩包排序和试读夹取越界。
- 临时复现测试位于 `/tmp/phantasm_audit_test.dart`，其断言描述当前缺陷行为，测试通过代表成功复现问题，不代表问题已修复。未将这些临时测试加入项目常规测试。
- `getLocation` 的 JS 表达式另经 Node 脚本解析，复现语法错误。
- `flutter build apk --debug --no-pub`（example）：成功，耗时约 402 秒，产物为 `example/build/app/outputs/flutter-apk/app-debug.apk`（约 97MB）。Gradle 使用 9.8.1，构建仅出现上游插件 Java 8 源/目标版本过时警告。
- Web/Android 构建通过只验证编译打包，未进行各阅读格式的全平台真机交互验证；iOS/macOS/Windows/Linux 原生构建未运行。

## 修复落实情况

| 编号 | 已实施改动 |
|---|---|
| A01、A06、A21 | ReaderPageWindow 统一绝对页号、双页及试读换算；图片、预缓存和缩略图限制在可读范围；空窗口及越界安全处理。旧漫画位置增加版本标记与迁移。 |
| A02、A03 | Markdown 使用捕获组回调；HTML 保留块边界；按真实宽高、文本缩放与方向分页，长段落按 grapheme 拆分并保留 UTF-16 原文偏移；TextPainter 成对释放。 |
| A04、A19 | PDF 先以 8 DPI 计数，再恢复绝对页号；高分辨率按需渲染，32 MiB 像素缓存和 24 DPI 缩略图。CBZ 自然排序、大小/页数限制及后台 isolate 解压入口。PDF 计数仍需扫描全书，但不再预存整本高分辨率像素。 |
| A05 | 来源/内容 SHA-256 稳定默认 ID，区分不同内存书籍；已知旧键可显式迁移且保留原数据。无法可靠反推旧 hashCode ID，未猜测归属。 |
| A07、A25、R01 | ReaderSession 串行管理全局显示效果、恢复下层阅读会话；加载代次检查、退出取消、外部设置统一应用、控制器帧后释放。 |
| A08、A09、A12 | EPUB 使用 spine section 搜索；JavaScriptChannel 请求 ID、Completer、超时及取消；打开状态与加载代次阻止重复打开；校验消息及主资源错误。 |
| A10、A13 | EPUB 章节 CFI 边界同时约束导航、搜索、恢复位置及渲染内容；同一 spine 内用锚点裁剪。禁用书籍脚本、外部导航及弹窗；真实 relocated 同步章节和百分比。 |
| A11 | 明确 Android/iOS/macOS EPUB 后端；Windows/Linux/Web 显示可见提示；双语 README 修正矩阵。未声称新增原先不存在的桌面/Web 后端。 |
| A14、A15、A26 | 竖向文本使用测量前缀偏移定位懒列表；滚动更新位置；横向保存段落内偏移，重排保留位置；按字符位置算进度；源/编码/DPI/阅读模式变化重新绑定，并忽略过期加载。 |
| A16、A17 | 显式 null 重置字体；EPUB 同步字距、页边距和对齐；自动阅读串行执行；EPUB TTS 获取实际可见正文。 |
| A18 | ReaderInkStore 按书籍和页/CFI/段落内偏移保存归一化笔迹，提供 JSON 导出，界面提供撤销/清空。 |
| A20、A23、A24 | 书签/高亮读改写串行化、唯一记录 ID；音频监听只注册一次并取消、重载/停止清空 cue；压缩包自然数字排序。 |
| A22、R02、R05 | 目录扁平化为单一懒列表；漫画/PDF 共享工具栏与页号逻辑；统一 PDF ImageProvider 路径；移除未使用数据字段、空 copyWith 和重复实现。 |
| R03、R04、R06 | 旧 tap-zone/trial helper 标记弃用；删除 pdf 与示例 path_provider 的冗余直接声明；实现漫画翻页效果；释放弹层输入控制器；修正文档与示例版本，添加 Cupertino 图标字体。 |

新增的运行依赖 `crypto 3.0.7`、`characters 1.4.1`、`synchronized 3.5.0` 都是原先已解析的间接依赖，现因直接使用而显式声明。示例增加已核实最新版 `cupertino_icons 2.0.0`。

修复后验证结果以最后的最终验证记录为准；前面的验证记录保留了升级阶段的基线。

## 原始问题说明

P1 表示直接影响正文、进度、试读、稳定性或主要功能；P2 表示条件性错误、性能或功能完整性；R 表示冗余/结构建议。

### A01 · P1 · 漫画双页显示试读范围外的下一张图

位置：[comic_reader.dart](../lib/src/comic/comic_reader.dart)。

`_buildPage` 只检查 `raw + 1 < pages.length`，未检查第二张图片是否仍在试读窗口。例如允许前 3 页、开启双页，第二屏会同时显示第 3、4 页。PDF 对应代码已经有 `secondOk` 校验，漫画没有。临时组件测试确认允许前 3 页、第二屏中仍构建了第 4 页图片。建议对第二页、预缓存和缩略图统一应用试读范围。缩略图目前还会直接展示整个文档，若产品要求不可预览试读范围外内容，也应同时过滤。

### A02 · P1 · Markdown 格式处理损坏正文；HTML 丢失段落边界

位置：[text_decoder.dart](../lib/src/novel/text/text_decoder.dart)、[text_decoder.dart](../lib/src/novel/text/text_decoder.dart)。

Dart `replaceAll` 不会把替换字符串 `$1` 当捕获组展开，`**hello**` 实际变成字面量 `$1`，单星号和行内代码同样受影响。`<p>one</p><p>two</p>` 被变为 `onetwo`。以上均已临时测试复现。建议用 `replaceAllMapped` 保留捕获内容，并正确转换块级标签/换行，或采用对应格式解析器。

### A03 · P1 · 文本分页可裁掉正文

位置：[text_paginator.dart](../lib/src/novel/text/text_paginator.dart)、[text_reader.dart](../lib/src/novel/text/text_reader.dart)、[text_reader.dart](../lib/src/novel/text/text_reader.dart)。

超长段落被完整塞在一页，渲染页的 ListView 又禁止滚动，超过屏幕部分无法正常阅读。临时测试确认超过页面高度的长段落仍只生成 1 页。分页测量还使用 margin×2，而渲染使用不同底边距和额外内边距，临界页也可能多排文字。建议按实际约束、文本缩放、文字方向和排版参数测量，并把长段落按文字位置拆页；同时 dispose TextPainter。

### A04 · P1 · PDF 恢复进度必然被映射为 0

位置：[pdf_reader.dart](../lib/src/pdf/pdf_reader.dart)。

`_bootstrap` 读取进度后立即调用 `_logicalIndexForContent`，此时 `_pages` 还是空列表，`_itemCount == 0`，该函数返回 0。之后才加载并光栅化 PDF。即使传入固定 bookId，保存过的后续页也恢复成首页。建议先保留绝对页码，在获取页数后再映射和夹取。

### A05 · P1 · 默认书籍标识导致丢进度或串书

位置：[comic_reader.dart](../lib/src/comic/comic_reader.dart)、[pdf_reader.dart](../lib/src/pdf/pdf_reader.dart)、[novel_reader.dart](../lib/src/novel/novel_reader.dart)、[novel_bytes_source.dart](../lib/src/novel/novel_bytes_source.dart)。

漫画/PDF 默认 ID 使用对象 hashCode，重建 source/pages 对象后可能变，无法可靠跨实例或跨会话恢复。小说内存源默认 displayName 都是 `book`，不同内容会得到相同 ID，书签/高亮/进度可串书。建议使用调用方稳定业务 ID，或规范路径/URL/内容摘要，同时设计旧数据迁移。

### A06 · P1 · 漫画保存逻辑屏号，切换双页/试读后恢复错误

位置：[comic_reader.dart](../lib/src/comic/comic_reader.dart)、[comic_reader.dart](../lib/src/comic/comic_reader.dart)、[comic_reader.dart](../lib/src/comic/comic_reader.dart)。

进度和书签存 `_currentPage`，这是 PageView 逻辑屏号；对外回调却使用原始内容页号。双页和非零试读起点下，两种编号不一致，切换布局后可能定位到另一页。无试读的 `_goToPage` 还按原图总数夹取，双页时可得到超出实际屏数的索引。建议全部持久化绝对页号，在视图层统一转换。

### A07 · P1 · 阅读页退出后，异步初始化仍可能创建资源

位置：[comic_reader.dart](../lib/src/comic/comic_reader.dart)、[novel_reader.dart](../lib/src/novel/novel_reader.dart)、[pdf_reader.dart](../lib/src/pdf/pdf_reader.dart)、[reader_brightness.dart](../lib/src/common/reader_brightness.dart)。

异步加载后只有局部 setState 有 mounted 检查，后续仍可能进入沉浸模式、设置亮度、开启 wakelock、创建 timer/controller/audio。快速返回时，dispose 已经执行，异步 apply 还可能 notify 已 dispose 的 ChangeNotifier，或者让资源在退出后重新开启。建议引入加载代次/取消标记，在每次 await 后校验，并有序管理资源获得与释放。多阅读页叠加时还需要处理全局 wakelock/沉浸模式的所有权。

### A08 · P1 · EPUB 搜索调用了不存在的 Book.search

位置：[reader.html](../assets/epubjs/reader.html)。

已核对当前内嵌版本对应的 EPUB.js 0.3.93 官方源码：Book 没有 `search` 方法，Section 有 `find/search`。`book.search(query)` 抛错后被 catch 转成 `'[]'`，外部看到的只是一直无结果。建议遍历 spine section，加载后搜索、汇总 CFI，再释放章节资源，同时向界面报告实际错误。

### A09 · P1 · EPUB 异步返回桥接不可靠，当前位置脚本有语法错误

位置：[epub_bridge.dart](../lib/src/novel/epub/epub_bridge.dart)、[epub_bridge.dart](../lib/src/novel/epub/epub_bridge.dart)、[epub_bridge.dart](../lib/src/novel/epub/epub_bridge.dart)。

JS 的 getToc/search 是 async，Dart 却直接 `runJavaScriptReturningResult` 取得 Promise；Android 实现直接使用 evaluateJavascript，没有在这里等待 Promise 完成。`JSON.stringify(await window.epubBridge.getLocation())` 又把 await 放进普通脚本表达式中，Node 脚本解析已复现 SyntaxError。建议用 JavaScriptChannel 回传带 requestId 的成功/失败结果，Dart 使用 Completer+超时匹配，并在两端验证。

### A10 · P1 · EPUB 试读不能约束实际手势和章节位置

位置：[novel_reader.dart](../lib/src/novel/novel_reader.dart)、[novel_reader.dart](../lib/src/novel/novel_reader.dart)、[reader.html](../assets/epubjs/reader.html)。

EPUB relocated 只向上回传 CFI，未更新实际 `_chapterIndex`；试读判断主要拦截 Dart `_page/_goChapter`，无法完整约束 iframe 内的滑动、滚动、链接或恢复位置。并且当前逻辑会把“处于最后允许章节”直接等同“不能再翻一页”，可能反过来阻止该章节内部继续阅读。建议按实际 spine/CFI 窗口约束渲染与导航，并同步当前位置。

### A11 · P1 · 宣称支持的部分 EPUB 平台没有后端

位置：[epub_viewer.dart](../lib/src/novel/epub/epub_viewer.dart)、[README_zh.md](../README_zh.md)。

当前解析的 webview_flutter 4.14.1 在 pubspec 中只声明 Android/iOS/macOS。Windows/Linux/Web 没有提供对应实现，而代码在没有平台能力判断时直接构造 WebViewController，且构造在 loadFlutterAsset 的 try 之外。README 宣称 Windows/Linux EPUB 可用与实际依赖不符。建议明确支持矩阵和可见降级，或选择并验证对应实现。

### A12 · P2 · EPUB 可以重复打开；JS 消息和加载错误处理不完整

位置：[epub_viewer.dart](../lib/src/novel/epub/epub_viewer.dart)、[epub_viewer.dart](../lib/src/novel/epub/epub_viewer.dart)、[epub_viewer.dart](../lib/src/novel/epub/epub_viewer.dart)、[epub_bridge.dart](../lib/src/novel/epub/epub_bridge.dart)。

shellReady 和 onPageFinished 都触发打开，但 `_bookOpened` 要等异步 ready 消息才设 true，中间没有 opening 标记。多次打开可相互销毁 book/rendition。消息 JSON 直接解码/强转，异常格式会抛出；资源错误也未区分主文档与可忽略子资源。建议请求代次、opening 状态、消息校验和主资源错误分级。

### A13 · P2 · 默认允许 EPUB 内容执行脚本

位置：[reader.html](../assets/epubjs/reader.html)、[epub_viewer.dart](../lib/src/novel/epub/epub_viewer.dart)。

渲染选项明确 `allowScriptedContent: true`，WebView 又开启 unrestricted JavaScript，导航没有白名单。导入非可信书籍时，书籍脚本可在阅读容器中执行。建议把书籍脚本能力默认关闭，确需交互书籍时显式开启，并限制导航及桥接消息。此项为代码配置确认，未进行利用测试。

### A14 · P1 · 竖向文本跳转与进度记录脱离实际可视位置

位置：[text_reader.dart](../lib/src/novel/text/text_reader.dart)、[text_reader.dart](../lib/src/novel/text/text_reader.dart)。

SliverList 懒构建使远处段落的 GlobalKey.currentContext 为 null，jumpToParagraph 只改逻辑位置、触发保存，然后没有实际滚动。临时组件测试已确认跳到第 151 段时 scroll offset 没变。普通手势滚动也没有更新当前段落，只有点击段落才记录；initialParagraph 仅赋给变量，不负责竖向初始滚动。建议按索引定位，并根据可见范围更新进度，正确恢复滚动锚点。

### A15 · P2 · 切换书籍或参数后仍可能展示旧内容

位置：[novel_reader.dart](../lib/src/novel/novel_reader.dart)、[pdf_reader.dart](../lib/src/pdf/pdf_reader.dart)、[comic_reader.dart](../lib/src/comic/comic_reader.dart)、[text_reader.dart](../lib/src/novel/text/text_reader.dart)。

NovelReader 的 didUpdateWidget 只同步 settings，PDF 没有处理 source/rasterDpi 变化，漫画没有完整处理 pages/readingMode/trialLimit 变化。TextReader 并发 _load 又缺少代次标记，旧请求可写入新状态。建议定义清晰的更新合同，源变化时取消旧任务、清理进度/书签/章节、重新加载，或明确要求调用者更换 key。

### A16 · P2 · 字体无法恢复系统默认；EPUB 部分排版选项无效

位置：[novel_typography.dart](../lib/src/common/novel_typography.dart)、[epub_bridge.dart](../lib/src/novel/epub/epub_bridge.dart)、[epub_viewer.dart](../lib/src/novel/epub/epub_viewer.dart)。

`copyWith(fontFamily: null)` 用 `??` 保留旧字体，已临时测试复现。EPUB bridge 又直接忽略 null/空字体，无法重置；textAlign/letterSpacing/pageMargin 虽出现在共享设置和工具栏中，但未传递到 EPUB。建议增加显式清空语义并补全实际支持的主题样式，或按格式隐藏不支持的选项。

### A17 · P2 · 自动阅读与 TTS 存在占位/时序问题

位置：[novel_reader.dart](../lib/src/novel/novel_reader.dart)、[novel_reader.dart](../lib/src/novel/novel_reader.dart)。

自动阅读每 40ms 调用一个 200–250ms 的翻页/跳段动画且不等待，会重叠；EPUB 分支直接 return，界面仍显示已开启。EPUB TTS 读的是固定英文占位句，未取书籍正文。建议使用可控滚动速度或串行翻页，真正读取当前章节文本，并正确维护失败、完成与停止状态。

### A18 · P2 · 手绘跨页串图，缺乏书籍/页级保存接口

位置：[ink_annotation.dart](../lib/src/common/ink_annotation.dart)、[comic_reader.dart](../lib/src/comic/comic_reader.dart)、[pdf_reader.dart](../lib/src/pdf/pdf_reader.dart)、[novel_reader.dart](../lib/src/novel/novel_reader.dart)。

三个阅读器都直接使用同一个 InkAnnotationLayer 状态，切页时没有页级 key/切换存储，也不接 onChanged。笔迹可以盖在下一页，退出丢失，而且只存屏幕坐标，布局变化后位置不稳定。建议按 bookId+内容锚点保存归一化笔迹，明确编辑/阅读模式，并提供导出、撤销和清空入口。

### A19 · P2 · PDF/压缩漫画整本展开造成启动慢和高内存占用

位置：[pdf_reader.dart](../lib/src/pdf/pdf_reader.dart)、[pdf_reader.dart](../lib/src/pdf/pdf_reader.dart)、[comic_archive.dart](../lib/src/comic/comic_archive.dart)。

PDF 先把整本文档所有页面光栅化并保存在 `_pages`，然后才结束 loading；页面/缩略图另解码 ui.Image。CBZ 同步在调用 isolate 中解压全部图片并再次复制内容，没有解压大小/页数边界。建议按需渲染、限量 LRU、降低缩略图分辨率，并把重解析移到 isolate。数量级示例：约 1000×1400 的 RGBA 页仅原始像素就约 5.6MB/页，100 页约 560MB，不含额外副本；这不是实机内存测量值。

### A20 · P2 · 书签/高亮并发写入会丢数据

位置：[reader_bookmark.dart](../lib/src/common/reader_bookmark.dart)、[reader_bookmark.dart](../lib/src/common/reader_bookmark.dart)。

读列表、追加、整表写回不是原子操作。临时测试并发添加两条不同书签，最终仅保留一条。建议以 bookId 为粒度串行化写入，或采用有事务的存储，同时避免毫秒时间戳 ID 冲突。

### A21 · P2 · 试读和空列表边界缺少输入校验

位置：[reader_trial_limit.dart](../lib/src/common/reader_trial_limit.dart)、[reader_trial_limit.dart](../lib/src/common/reader_trial_limit.dart)、[comic_reader.dart](../lib/src/comic/comic_reader.dart)、[text_reader.dart](../lib/src/novel/text/text_reader.dart)。

startIndex 超过总数时 maxReadableIndex 返回越界起点，clampIndex 也可返回越界值：临时测试 `pages(2,startPage:20).clampIndex(100,10)` 返回 20。漫画空内容但已有进度会调用 clamp(0,-1)。文本 min/max 次序不合法时 sublist 可失败。建议集中校验非负值、空窗口与上下界，并明确 maxCount<=0 是不限量还是禁止阅读，保持各阅读器一致。

### A22 · P2 · 嵌套 EPUB 目录可能出现无高度约束的 ListView

位置：[novel_reader.dart](../lib/src/novel/novel_reader.dart)。

_ChapterTree 递归地把一个默认 ListView 放入另一个 ListView 的 children，没有 shrinkWrap 或有限高度。带子章节的目录在目录桥修复后可触发 viewport 约束异常。建议扁平化带 depth 的目录数据，用单一懒列表绘制。

### A23 · P2 · 音频重复 load 会叠加订阅

位置：[media_overlay.dart](../lib/src/audio/media_overlay.dart)。

每次 load 都添加 position/complete 监听，未保存/取消 StreamSubscription；切换音源可重复触发回调，且 `_active` 没随 load/stop 清空。建议每个 player 生命周期只建立一次监听或在重载前取消，显式重置 cue；cue 查找可按需要从线性扫描改为二分或游标。

### A24 · P2 · 漫画压缩包页序按字典序排列

位置：[comic_archive.dart](../lib/src/comic/comic_archive.dart)。

`1.png,2.png,10.png` 实际排序为 `1,10,2`，已临时测试复现。建议自然数排序并明确目录排序规则，补充压缩包页序回归测试。

### A25 · P2 · 外部设置同步、解码完成和图像任务缺少一致状态管理

位置：[novel_reader.dart](../lib/src/novel/novel_reader.dart)、[comic_reader.dart](../lib/src/comic/comic_reader.dart)、[pdf_reader.dart](../lib/src/pdf/pdf_reader.dart)、[text_reader.dart](../lib/src/novel/text/text_reader.dart)。

NovelReader 外部 settings 更新仅应用亮度，不同步 keepScreenOn/immersive；漫画也未完整同步 immersive。PDF 异步 toImage 无请求代次，旧 raster 完成可能覆盖新图像。TextReader 在布局阶段立即 dispose 旧 PageController，再由子树更新绑定，易产生控制器/监听器生命周期冲突，需要通过重排组件测试确认具体触发。建议统一设置应用入口、任务代次及帧后控制器释放。

### A26 · P2 · 进度百分比与回调语义不一致

位置：[novel_reader.dart](../lib/src/novel/novel_reader.dart)、[novel_reader.dart](../lib/src/novel/novel_reader.dart)、[novel_reader.dart](../lib/src/novel/novel_reader.dart)。

小说有章节时按章节编号粗略估算，没有章节时 UI 使用 `(paragraphIndex+1)/100`，存储却为 0；EPUB 没同步实际章节。翻到文本新章节也未调用对外 onChapterChanged。建议定义格式一致的绝对进度、试读相对进度和回调时机，优先使用 EPUB location、文本偏移/段落总数。

## 原始冗余与可维护性建议

| 编号 | 位置 | 发现与建议 | 注意事项 |
|---|---|---|---|
| R01 | reader_lifecycle.dart:8；三种 reader 的 _enterReading/_leaveReading/_bootstrap | ReaderLifecycleMixin 没有任何使用点，三份 reader 却重复实现相同生命周期。建议统一到经过取消/所有权设计的会话控制器，再移除旧实现。 | 不宜直接套现有 mixin，它本身没有解决 A07。 |
| R02 | comic_reader.dart 的 _ComicToolbar；pdf_reader.dart 的 _PdfToolbar；example_settings_sheet.dart | 漫画/PDF 工具栏、设置应用、书签列表、页码转换和 trial sentinel 有较多重复。建议先共享页号/试读纯逻辑，再提取可配置控件。 | 保留图片缩放与 PDF 光栅化差异，避免过度抽象。 |
| R03 | tap_zones.dart:18；reader_settings.dart:32；reader_trial_limit.dart:120 | TapZoneDetector 无内部调用，tapZonesEnabled 已标为 legacy；四个 trial legacy helper 与 ReaderTrialLimit 重复。 | 都属于导出 API/持久化字段，先 @Deprecated 和兼容迁移，不能直接删。 |
| R04 | pubspec.yaml 的 pdf；example/pubspec.yaml 的 path_provider | lib 没直接 import package:pdf，example/lib 没 import path_provider。两项都是直接依赖冗余候选。 | pdf 仍由 printing 间接使用，删直接声明不会删掉实际 PDF 能力，也未必减少包体。 |
| R05 | pdf_reader.dart:979 与 :1048；text_reader.dart:546；comic_reader.dart:223 | 页面/缩略图两份 ui.Image 解码及释放逻辑重复；_TextBook.chapters 生成后未被消费者读取；saved.copyWith() 没参数等同多建对象。 | 可共享图像解码控制器、简化数据结构；先修复 A25 的异步竞态。 |
| R06 | comic_reader.dart:42；novel_reader.dart:499；README_zh.md:235；example/lib/main.dart:64 | 漫画 pageTurnEffect 暴露但从未使用；搜索 TextEditingController 未 dispose；README 的 pdf/printing 版本及示例“0.0.3 演示”已过时；Web 构建还有 CupertinoIcons 字体提示。 | pageTurnEffect 应实现或先弃用，不应作为“死代码”直接删除公开参数；控制器应按弹层生命周期释放。 |

## 原始优先级分组

1. 正文、试读和数据正确性：A01–A06、A08–A11、A14、A20–A21。
2. 生命周期和性能：A07、A12、A15、A19、A23、A25。
3. 功能完整性：A13、A16–A18、A22、A24、A26。
4. 在对应问题修复并验证后，再选择 R01–R06 重构或清理。

全部修复已获用户授权；未提交或推送 Git。公开旧 API 保留弃用标记，避免直接删除造成兼容性破坏。

## 最终验证记录

- `flutter analyze --no-pub`：No issues found；`dart analyze` 同样通过。
- `flutter test --no-pub`：33 项全部通过，包含原有 8 项及新增 25 项回归测试。
- 真实 EPUB 浏览器测试：压缩包解析、嵌套目录与章节位置、spine 搜索、异步回复、脚本隔离、章节和锚点试读裁剪、阅读流切换与字体重置通过。运行方式见 [浏览器测试说明](../test/js/README.md)。
- `flutter build web --no-pub`：成功，Wasm dry run 成功，Cupertino 字体已打包，原缺失字体警告消除。
- `flutter build apk --debug --no-pub`：成功，产物为 `example/build/app/outputs/flutter-apk/app-debug.apk`。
- `git diff --check`：通过。

打印和音频在 Dart 单元测试中使用平台替身；EPUB 浏览器测试使用真实 EPUB.js 和临时 Chrome 上下文。以上不代表已完成所有平台真机验证。EPUB 官方后端仍限 Android/iOS/macOS，其余平台显示明确提示。
