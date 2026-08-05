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
| 漫画阅读器 | 网络图片页；水印、试读 3 页、手绘、`onSync` SnackBar |
| 小说阅读器（文本） | 写入临时 txt；主题 / TTS；导出书签 JSON；同步回调 |
| PDF 阅读器 | 内存生成的样例 PDF；水印与试读提示 |

## 依赖

通过 `path: ../` 引用本地 package，与仓库当前代码一致。
