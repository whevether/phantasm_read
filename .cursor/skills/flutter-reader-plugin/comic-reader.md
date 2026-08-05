# 漫画阅读器（extended_image 10.1.0）

## 依赖

```yaml
dependencies:
  extended_image: 10.1.0
```

主路径必须用 `ExtendedImageGesturePageView` + `ExtendedImageMode.gesture`。禁止用 `photo_view` / `InteractiveViewer` 替代漫画主阅读器。

## 页源

统一封装，避免 Widget 内散落三种加载逻辑：

```dart
sealed class ComicPages {
  const ComicPages();
  factory ComicPages.fromFiles(List<String> paths) = ComicPagesFiles;
  factory ComicPages.fromUrls(List<String> urls) = ComicPagesUrls;
  factory ComicPages.fromBytes(List<Uint8List> bytes) = ComicPagesBytes;

  int get length;
}

enum ComicReadingMode { vertical, horizontal }
```

- **竖滑**：`scrollDirection: Axis.vertical`
- **横翻**：`Axis.horizontal`，可配日漫从右到左（`reverse: true`）

## 核心 Widget 模式

```dart
ExtendedImageGesturePageView.builder(
  itemCount: pages.length,
  controller: pageController,
  scrollDirection: mode == ComicReadingMode.vertical
      ? Axis.vertical
      : Axis.horizontal,
  reverse: rtl,
  itemBuilder: (context, index) {
    return ExtendedImage(
      image: resolveImageProvider(pages, index), // File / Network / Memory
      mode: ExtendedImageMode.gesture,
      fit: BoxFit.contain,
      initGestureConfigHandler: (state) => GestureConfig(
        minScale: 1.0,
        maxScale: 4.0,
        animationMinScale: 0.8,
        animationMaxScale: 4.5,
        inPageView: true,
      ),
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return const Center(child: CircularProgressIndicator());
          case LoadState.failed:
            return Center(
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: state.reLoadImage,
              ),
            );
          case LoadState.completed:
            return null; // 使用默认完成态
        }
      },
    );
  },
);
```

要点：

- `inPageView: true`：缩放与翻页手势共存
- `loadStateChanged`：加载 / 失败占位必做
- `BoxFit.contain`：默认完整显示一页，避免裁切对话框

## 预加载邻页

在 `onPageChanged` 中预热 `index ± 1` 的 `ImageProvider`（`precacheImage`），大图注意内存：同时缓存页数建议 ≤ 3（当前 + 两侧）。

网络图使用 `ExtendedNetworkImageProvider`（随 `extended_image` 提供），享受磁盘缓存；本地文件用 `ExtendedFileImageProvider` / `FileImage`。

## 与公共控件集成

用一层 wrapper，勿在 `itemBuilder` 里重复开关 wakelock：

```dart
class ComicReader extends StatefulWidget {
  final ComicPages pages;
  final ComicReadingMode readingMode;
  final ReaderSettings settings;
  // ...
}

// State:
// initState  → WakeLock.enable；Brightness.apply(settings.brightness)
// build      → Stack: PageView + 可选亮度遮罩 + 可选设置条
// dispose    → Brightness.restore；WakeLock.disable
```

亮度、不熄屏细节见 [common-controls.md](common-controls.md)。

## 手势与 UI 约定

| 交互 | 行为 |
|------|------|
| 单击中部 | 切换工具栏显隐 |
| 边缘点击 / 滑页 | 上一页 / 下一页（与 `PageView` 一致） |
| 双指捏合 | 缩放（gesture mode） |
| 缩放中滑页 | 由 `inPageView: true` 处理，勿自定义抢手势 |

工具栏可含：页码、亮度滑条、竖/横切换、不熄屏开关。字体控件不出现在漫画页。

## 检查清单

- [ ] `extended_image: 10.1.0`
- [ ] `ExtendedImageMode.gesture` + `GestureConfig(inPageView: true)`
- [ ] 支持 files / urls / bytes 三种页源
- [ ] 竖滑与横翻
- [ ] loading / failed 占位
- [ ] 邻页预加载有界
- [ ] 进入/离开成对处理亮度与不熄屏
