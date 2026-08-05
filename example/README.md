# phantasm_read_example

演示 `phantasm_read` 0.0.1 阅读能力的示例应用。

## 运行

```bash
cd example
flutter pub get
flutter run
```

## 首页入口

| 入口 | 说明 |
|------|------|
| 漫画阅读器 | 5 张网络图；默认试读 3 页；手绘、`onSync` SnackBar、导出书签 |
| 小说阅读器（文本） | 12 章样例 txt；默认试读 3 章；主题 / TTS；导出书签 JSON |
| PDF 阅读器 | 5 页内存样例 PDF；默认试读 3 页 |

## 示例设置

首页或各阅读器 AppBar 的「示例设置」可配置：

- 水印、手绘、高亮、同步、RTL、双页等扩展能力
- **试读**：页/章数、起始页/章（0 起）
- **触顶反馈**：弹窗 / SnackBar / 无（演示 `onTrialLimitReached` 由宿主处理 UI）

试读逻辑见 package 文档 [ReaderTrialLimit](../README_zh.md#试读readertriallimit)。

## 依赖

通过 `path: ../` 引用本地 package，与仓库当前代码一致。
