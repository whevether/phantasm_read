---
name: flutter-reader-plugin
description: >-
  开发跨平台 Flutter 漫画/小说阅读器插件。漫画使用 extended_image 10.1.0；
  小说支持 epub（epub.js + WebView）及 txt/md/html 等文本格式；统一亮度、
  小说字体与不熄屏。在用户提到漫画阅读器、小说阅读器、epub、extended_image、
  Flutter reader plugin、阅读亮度或 wakelock 时使用。
---

# Flutter 漫画/小说阅读器插件

指导开发跨平台 Flutter 阅读器插件（漫画 + 小说），不是实现业务 App UI。

## 何时使用

- 新建或改造 Flutter 漫画/小说阅读器插件
- 接入 `extended_image`、epub.js、亮度、字体、不熄屏
- 排查多平台（Android / iOS / Web / 桌面）阅读能力差异

## 强制技术选型

| 能力 | 选型 | 禁止 |
|------|------|------|
| 漫画 | `extended_image: 10.1.0`，`ExtendedImageGesturePageView` + `ExtendedImageMode.gesture` | 其他图片库替代漫画主路径 |
| EPUB | [epub.js](https://github.com/futurepress/epub.js) + `webview_flutter: 4.14.1`，JS 打进 assets | CDN 加载 epub.js；纯 Dart EPUB 渲染作为主路径 |
| 文本小说 | Dart 解析 + `CustomScrollView` / `PageView` | 用 WebView 渲染纯文本 |
| 亮度 | `screen_brightness`；不支持时半透明黑遮罩 | 各平台各自发明 API |
| 不熄屏 | `wakelock_plus`，进入开、退出/dispose 关 | 忘记成对释放 |

## 工作流

复制并跟踪：

```
Task Progress:
- [ ] 1. 判定任务类型
- [ ] 2. 对齐架构与依赖
- [ ] 3. 实现目标模块
- [ ] 4. 接入公共控件（亮度 / 不熄屏 / 小说字体）
- [ ] 5. 按平台矩阵自检
```

### 1. 判定任务类型

| 类型 | 去做 |
|------|------|
| 新建包 | `flutter create --template=package`，再按 [architecture.md](architecture.md) 搭目录与对外 API |
| 加漫画 | 读 [comic-reader.md](comic-reader.md) |
| 加小说（EPUB/文本） | 读 [novel-reader.md](novel-reader.md) |
| 公共控件 | 读 [common-controls.md](common-controls.md) |
| 平台兼容 | 对照 [architecture.md](architecture.md) 平台矩阵 |

### 2. 对齐架构与依赖

1. 包结构与对外 API：`ComicReader` / `NovelReader` / `ReaderSettings`
2. `pubspec.yaml` 锁定依赖版本（见 architecture.md）
3. EPUB 资源：`assets/epubjs/` 内嵌 `epub.min.js` + JSZip，禁止运行时拉 CDN

### 3. 实现目标模块

- **漫画**：页列表（路径 / URL / bytes）→ `ExtendedImageGesturePageView` → 预加载邻页 → 占位与失败态
- **EPUB**：本地 HTML shell + `webview_flutter` → Dart↔JS 桥（章节、CFI、字体、主题）
- **文本**：编码探测 → 排版参数 → 滚动或分页

### 4. 接入公共控件

每个阅读页必须：

1. `initState` / 进入：`ReaderWakeLock.enable()`；保存当前亮度
2. 用户调亮度：优先系统亮度，失败则遮罩
3. 小说：暴露 `NovelTypography`（字号 / 行高 / 字体）
4. `dispose` / 离开：恢复亮度，`ReaderWakeLock.disable()`

### 5. 平台自检

按 architecture.md 矩阵勾选：漫画、文本、EPUB、亮度、不熄屏。Linux EPUB / Web 亮度等降级路径必须有明确 fallback，不能静默失败。

## 对外 API 约定

```dart
// 漫画
ComicReader(
  pages: ComicPages.fromUrls(urls), // 或 fromFiles / fromBytes
  readingMode: ComicReadingMode.vertical, // 或 horizontal
  settings: readerSettings,
);

// 小说
NovelReader(
  source: NovelSource.epub(filePath), // 或 .text / .markdown / .html
  settings: readerSettings,
);

// 共享设置
ReaderSettings(
  brightness: 0.8,      // 0.0–1.0
  keepScreenOn: true,
  typography: NovelTypography(fontSize: 18, lineHeight: 1.6),
);
```

漫画与小说共用 `ReaderSettings` 的亮度与不熄屏；`typography` 仅小说生效。

## 实现原则

- 插件优先：能力放在 package，示例 App 只做演示
- 生命周期成对：亮度恢复、wakelock 关闭不可漏
- 离线优先：epub.js 与阅读资源可离线工作
- 术语统一：漫画 / 小说 / EPUB / 亮度 / 不熄屏

## 详细参考

- [architecture.md](architecture.md) — 模块划分、依赖、平台矩阵
- [comic-reader.md](comic-reader.md) — extended_image 漫画实现
- [novel-reader.md](novel-reader.md) — epub.js 与文本格式
- [common-controls.md](common-controls.md) — 亮度、字体、不熄屏
