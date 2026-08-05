# 公共控件：亮度、字体、不熄屏

漫画与小说共用亮度、不熄屏；**字体仅小说**（含 EPUB 与文本）。

## ReaderSettings

```dart
class ReaderSettings {
  const ReaderSettings({
    this.brightness = 0.8,       // 0.0–1.0
    this.keepScreenOn = true,
    this.typography = const NovelTypography(),
  });

  final double brightness;
  final bool keepScreenOn;
  final NovelTypography typography;

  ReaderSettings copyWith({...});
}

class NovelTypography {
  const NovelTypography({
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.fontFamily,
  });

  final double fontSize;
  final double lineHeight;
  final String? fontFamily;
}
```

变更通过 `ValueNotifier` / 回调通知阅读页，避免整树无脑 rebuild。

---

## 亮度：ReaderBrightness

依赖：`screen_brightness`。

### 策略

1. **优先系统亮度**：`ScreenBrightness().setScreenBrightness(value)`  
2. **失败或不支持**（Web、部分 Linux/桌面）：`BrightnessMode.overlay` —— 在阅读内容上叠 `IgnorePointer` 包裹的黑色 `Opacity`（`opacity: 1 - brightness`）  
3. **进入阅读前**保存 `current`；**离开/dispose** 调用 `resetScreenBrightness()`（仅当曾成功设置系统亮度时）

```dart
enum BrightnessMode { system, overlay }

class ReaderBrightness {
  double? _saved;
  BrightnessMode mode = BrightnessMode.system;

  Future<void> apply(double value) async {
    final v = value.clamp(0.0, 1.0);
    try {
      _saved ??= await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(v);
      mode = BrightnessMode.system;
    } catch (_) {
      mode = BrightnessMode.overlay;
      // UI 层根据 mode + value 画遮罩
    }
  }

  Future<void> restore() async {
    if (mode == BrightnessMode.system) {
      try {
        await ScreenBrightness().resetScreenBrightness();
      } catch (_) {}
    }
    _saved = null;
  }
}
```

遮罩示例：

```dart
if (brightness.mode == BrightnessMode.overlay)
  Positioned.fill(
    child: IgnorePointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 1.0 - settings.brightness),
      ),
    ),
  ),
```

漫画与小说都走同一套；EPUB WebView 上遮罩盖在 WebView **之上**。

---

## 不熄屏：ReaderWakeLock

依赖：`wakelock_plus`。

```dart
class ReaderWakeLock {
  static Future<void> enable() => WakelockPlus.enable();
  static Future<void> disable() => WakelockPlus.disable();
}
```

规则：

| 时机 | 动作 |
|------|------|
| 阅读页 `initState` / route 进入且 `keepScreenOn == true` | `enable()` |
| `keepScreenOn` 被用户关掉 | `disable()` |
| `dispose` / route 弹出 | **必须** `disable()` |
| App 进后台 | 建议 `disable()`；回前台且仍在阅读再 `enable()` |

禁止只 enable 不 disable。Web 上无效时 catch 后忽略，不抛给用户。

---

## 小说字体：NovelTypography

仅 `NovelReader`（文本 + EPUB）响应。

| 参数 | 文本路径 | EPUB 路径 |
|------|----------|-----------|
| `fontSize` | `TextStyle.fontSize` | `epubBridge.setFontSize` |
| `lineHeight` | `TextStyle.height` | 注入 CSS `line-height` |
| `fontFamily` | `TextStyle.fontFamily` | `themes.font` / CSS |

设置面板提供滑条/步进器；变更立即生效，并写入宿主持久化（由 App 负责，插件可提供当前值快照）。

漫画页不展示字体控件。

---

## 阅读页生命周期模板

```dart
class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
  final _brightness = ReaderBrightness();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterReading();
  }

  Future<void> _enterReading() async {
    await _brightness.apply(widget.settings.brightness);
    if (widget.settings.keepScreenOn) await ReaderWakeLock.enable();
  }

  Future<void> _leaveReading() async {
    await _brightness.restore();
    await ReaderWakeLock.disable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ReaderWakeLock.disable();
    } else if (state == AppLifecycleState.resumed &&
        widget.settings.keepScreenOn) {
      ReaderWakeLock.enable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _leaveReading(); // 异步 fire-and-forget 可接受；关键路径尽量 awaited 的 wrapper
    super.dispose();
  }
}
```

---

## 检查清单

- [ ] 亮度：系统优先，失败转遮罩  
- [ ] 离开阅读恢复系统亮度  
- [ ] wakelock 进入/离开/后台成对  
- [ ] 小说字体三参数可调且 EPUB/文本均生效  
- [ ] 漫画无字体 UI；亮度与不熄屏两边齐全
