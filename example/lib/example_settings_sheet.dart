import 'package:flutter/material.dart';
import 'package:phantasm_read/phantasm_read.dart';

import 'example_options.dart';

Future<void> showExampleSettingsSheet(
  BuildContext context,
  ExampleReaderOptions options,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final bottom = MediaQuery.viewPaddingOf(ctx).bottom;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.48,
        minChildSize: 0.32,
        maxChildSize: 0.72,
        builder: (context, scrollController) {
          return AnimatedBuilder(
            animation: options,
            builder: (context, _) {
              return ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom),
                children: [
                  const Text(
                    '示例高级设置',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '常用功能默认开启；以下开关控制扩展能力。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 20),
                  _section('漫画'),
                  SwitchListTile(
                    dense: true,
                    title: const Text('水印'),
                    value: options.comicWatermark,
                    onChanged: options.setComicWatermark,
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('手绘 / 笔记层'),
                    value: options.comicInk,
                    onChanged: options.setComicInk,
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('试读页数限制'),
                    value: options.comicTrial,
                    onChanged: options.setComicTrial,
                  ),
                  if (options.comicTrial)
                    ListTile(
                      dense: true,
                      title: const Text('试读页数'),
                      trailing: SizedBox(
                        width: 120,
                        child: Slider(
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '${options.comicTrialPages}',
                          value: options.comicTrialPages.toDouble(),
                          onChanged: (v) =>
                              options.setComicTrialPages(v.round()),
                        ),
                      ),
                    ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('云同步 onSync'),
                    value: options.comicSync,
                    onChanged: options.setComicSync,
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('RTL'),
                    value: options.comicRtl,
                    onChanged: options.setComicRtl,
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('双页模式'),
                    value: options.comicDoublePage,
                    onChanged: options.setComicDoublePage,
                  ),
                  ListTile(
                    dense: true,
                    title: const Text('翻页效果'),
                    trailing: DropdownButton<PageTurnEffect>(
                      value: options.comicPageTurn,
                      items: const [
                        DropdownMenuItem(
                          value: PageTurnEffect.none,
                          child: Text('无'),
                        ),
                        DropdownMenuItem(
                          value: PageTurnEffect.curl,
                          child: Text('curl'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) options.setComicPageTurn(v);
                      },
                    ),
                  ),
                  const Divider(height: 16),
                  _section('小说'),
                  SwitchListTile(
                    dense: true,
                    title: const Text('水印'),
                    value: options.novelWatermark,
                    onChanged: options.setNovelWatermark,
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('手绘 / 笔记层'),
                    value: options.novelInk,
                    onChanged: options.setNovelInk,
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('段落高亮'),
                    value: options.novelHighlight,
                    onChanged: options.setNovelHighlight,
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('云同步 onSync'),
                    value: options.novelSync,
                    onChanged: options.setNovelSync,
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('试读限制'),
                    value: options.novelTrial,
                    onChanged: options.setNovelTrial,
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('RTL'),
                    value: options.novelRtl,
                    onChanged: options.setNovelRtl,
                  ),
                  const Divider(height: 16),
                  _section('PDF'),
                  SwitchListTile(
                    dense: true,
                    title: const Text('水印'),
                    value: options.pdfWatermark,
                    onChanged: options.setPdfWatermark,
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('试读页数'),
                    value: options.pdfTrial,
                    onChanged: options.setPdfTrial,
                  ),
                  ListTile(
                    dense: true,
                    title: const Text('光栅 DPI'),
                    trailing: SizedBox(
                      width: 140,
                      child: Slider(
                        min: 72,
                        max: 200,
                        divisions: 8,
                        label: options.pdfRasterDpi.round().toString(),
                        value: options.pdfRasterDpi,
                        onChanged: options.setPdfRasterDpi,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

Widget _section(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    ),
  );
}
