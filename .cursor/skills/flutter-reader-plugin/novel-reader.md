# 小说阅读器（EPUB + 文本）

## 书源

```dart
sealed class NovelSource {
  const NovelSource();
  factory NovelSource.epub(String path) = NovelSourceEpub;
  factory NovelSource.text(String path) = NovelSourceText;       // .txt
  factory NovelSource.markdown(String path) = NovelSourceMarkdown; // .md
  factory NovelSource.html(String path) = NovelSourceHtml;       // .html/.htm
}
```

`NovelReader` 按书源分支：`epub` → WebView + epub.js；其余 → Dart 文本阅读器。

---

## EPUB：epub.js + WebView

### 资源（必须离线）

将官方构建产物放入插件 assets（勿运行时 CDN）：

```
assets/epubjs/
  epub.min.js      # https://github.com/futurepress/epub.js
  jszip.min.js     # epub.js 解压依赖
  reader.html      # shell
```

`pubspec.yaml` 注册 `assets/epubjs/`。

### reader.html 职责

1. 引入 JSZip + epub.js  
2. 提供 `window.epubBridge`：`open(bookData|url)`、`next`/`prev`、`display(cfi|href)`、`getToc`、`getLocation`、`setFontSize`、`setTheme`  
3. 通过 `webview_flutter` 的 `JavaScriptChannel`（JS→Dart）与 `runJavaScript` / `runJavaScriptReturningResult`（Dart→JS）双向通信  

最小 open 模式（概念）：

```javascript
// reader.html 内
let book, rendition;
window.epubBridge = {
  async openFromArrayBuffer(buffer) {
    book = ePub(buffer);
    rendition = book.renderTo('viewer', { width: '100%', height: '100%' });
    await rendition.display();
    return true;
  },
  setFontSize(percent) {
    rendition.themes.fontSize(`${percent}%`);
  },
  setTheme(bg, fg) {
    rendition.themes.default({ body: { background: bg, color: fg } });
  },
  // next / prev / location / toc ...
};
// JS → Dart：EpubChannel.postMessage(JSON.stringify({ type, payload }))
```

### Dart 侧

```dart
// 使用 webview_flutter 4.14.1
late final WebViewController controller;

@override
void initState() {
  super.initState();
  controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..addJavaScriptChannel(
      'EpubChannel',
      onMessageReceived: (JavaScriptMessage message) {
        // 处理 onLocationChanged / onReady / onError
      },
    )
    ..setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (url) async {
          // 将 epub 读为 bytes，base64 或 blob URL 交给 JS open
          await controller.runJavaScript('window.epubBridge.openFromArrayBuffer(...)');
        },
      ),
    )
    ..loadFlutterAsset('assets/epubjs/reader.html');
}

// build: WebViewWidget(controller: controller)
```

传书策略：

- **小文件**：base64 注入 `openFromArrayBuffer`  
- **大文件**：写入临时文件后 `loadFile` / `file://`，避免 OOM  

进度用 **CFI**（`rendition.currentLocation()`）持久化；恢复时 `display(cfi)`。

### 字体与主题（小说专用）

经 JS 桥同步 `NovelTypography`：

| Dart | epub.js |
|------|---------|
| `fontSize` | `rendition.themes.fontSize('${n}%')` 或 px |
| `fontFamily` | `rendition.themes.font(family)` / CSS inject |
| `lineHeight` | 注入 body `line-height` |
| 背景/文字色 | `themes.default({ body: {...} })` |

### Web 平台

同一套 `reader.html` + epub.js：用 iframe 或 `dart:js_interop` 调用桥方法，**不要**在 Web 上再依赖移动端 WebView 插件。对外 `EpubViewer` API 与移动端一致。

### Linux / 桌面

`webview_flutter` 平台实现可用则走同一路径；不可用则明确报错或隐藏 EPUB 入口（见 architecture.md），文本小说仍可用。

---

## 文本：txt / md / html

**禁止**用 WebView 渲染纯文本主路径。

### 解码

1. 读 bytes  
2. 优先 UTF-8；失败则用 `charset_converter` 试 GBK/GB18030（中文 txt 常见）  
3. 暴露 `encoding` 覆盖参数  

### 渲染

| 格式 | 处理 |
|------|------|
| `.txt` | 纯文本；可按空行分段 |
| `.md` | 轻量 Markdown → `Text.rich` / 简单 block（勿强绑重型编辑器） |
| `.html` | 用受控 HTML→spans，或剥离标签为纯文本；勿加载外部脚本 |

布局：

- **滚动**：`CustomScrollView` + `SliverList`（长文默认）  
- **仿真翻页**：按视口高度测量分页进 `PageView`（可选增强）  

排版全部来自 `NovelTypography` + 主题色（见 common-controls.md）。

```dart
Text(
  content,
  style: TextStyle(
    fontSize: typography.fontSize,
    height: typography.lineHeight,
    fontFamily: typography.fontFamily,
    color: foreground,
  ),
);
```

---

## 与公共控件

EPUB 与文本页均：

1. 进入：`WakeLock.enable` + 应用亮度  
2. 设置面板：亮度、不熄屏、**字体**（字号/行高/字体）  
3. 离开：恢复亮度 + `WakeLock.disable`  

---

## 检查清单

- [ ] epub.js + JSZip 在 assets，无 CDN  
- [ ] Dart↔JS 桥覆盖 open / 翻页 / CFI / toc / 字体主题  
- [ ] Web 与移动端对外 API 一致  
- [ ] txt/md/html 走 Dart 渲染  
- [ ] 编码探测含 UTF-8 与 GBK  
- [ ] 小说字体可实时生效（含 EPUB themes）  
- [ ] 亮度与不熄屏生命周期成对
