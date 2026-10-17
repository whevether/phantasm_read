import 'package:material_ui/material_ui.dart';

import '../comic/comic_reading_mode.dart';
import 'reader_settings.dart';
import 'novel_typography.dart';

class PageReaderToolbar extends StatelessWidget {
  const PageReaderToolbar({
    super.key,
    required this.pageLabel,
    required this.progress,
    required this.settings,
    required this.mode,
    required this.bookmarked,
    required this.onModeChanged,
    required this.onSettingsChanged,
    required this.onToggleBookmark,
    required this.onShowBookmarks,
    required this.onShowThumbs,
    required this.onSeek,
    required this.onPageInput,
  });

  final String pageLabel;
  final double progress;
  final ReaderSettings settings;
  final ComicReadingMode mode;
  final bool bookmarked;
  final ValueChanged<ComicReadingMode> onModeChanged;
  final ValueChanged<ReaderSettings> onSettingsChanged;
  final VoidCallback onToggleBookmark;
  final VoidCallback onShowBookmarks;
  final VoidCallback onShowThumbs;
  final ValueChanged<double> onSeek;
  final ValueChanged<int> onPageInput;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Colors.black54,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(pageLabel, style: const TextStyle(color: Colors.white)),
                Slider(value: progress.clamp(0, 1), onChanged: onSeek),
                Row(
                  children: [
                    const Icon(
                      Icons.brightness_6,
                      color: Colors.white,
                      size: 18,
                    ),
                    Expanded(
                      child: Slider(
                        value: settings.brightness,
                        onChanged: (v) =>
                            onSettingsChanged(settings.copyWith(brightness: v)),
                      ),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '方向',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onModeChanged(
                          mode == ComicReadingMode.vertical
                              ? ComicReadingMode.horizontal
                              : ComicReadingMode.vertical,
                        ),
                        icon: Icon(
                          mode == ComicReadingMode.vertical
                              ? Icons.swap_vert
                              : Icons.swap_horiz,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        tooltip: '适应',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final next = switch (settings.comicFitMode) {
                            ComicFitMode.contain => ComicFitMode.width,
                            ComicFitMode.width => ComicFitMode.height,
                            ComicFitMode.height => ComicFitMode.contain,
                          };
                          onSettingsChanged(
                            settings.copyWith(comicFitMode: next),
                          );
                        },
                        icon: const Icon(Icons.fit_screen, color: Colors.white),
                      ),
                      IconButton(
                        tooltip: settings.doublePage
                            ? '关闭双页'
                            : mode == ComicReadingMode.vertical
                            ? '双页（将切换为横向）'
                            : '双页',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onSettingsChanged(
                          settings.copyWith(doublePage: !settings.doublePage),
                        ),
                        icon: Icon(
                          settings.doublePage
                              ? Icons.menu_book
                              : Icons.menu_book_outlined,
                          color: settings.doublePage
                              ? (mode == ComicReadingMode.horizontal
                                    ? Colors.amber
                                    : Colors.amber.withValues(alpha: 0.45))
                              : Colors.white,
                        ),
                      ),
                      IconButton(
                        tooltip: '书签',
                        visualDensity: VisualDensity.compact,
                        onPressed: onToggleBookmark,
                        icon: Icon(
                          bookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        tooltip: '书签列表',
                        visualDensity: VisualDensity.compact,
                        onPressed: onShowBookmarks,
                        icon: const Icon(Icons.bookmarks, color: Colors.white),
                      ),
                      IconButton(
                        tooltip: '缩略图',
                        visualDensity: VisualDensity.compact,
                        onPressed: onShowThumbs,
                        icon: const Icon(Icons.grid_view, color: Colors.white),
                      ),
                      IconButton(
                        tooltip: '不熄屏',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onSettingsChanged(
                          settings.copyWith(
                            keepScreenOn: !settings.keepScreenOn,
                          ),
                        ),
                        icon: Icon(
                          settings.keepScreenOn
                              ? Icons.phonelink_lock
                              : Icons.phonelink_erase,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        tooltip: settings.immersive ? '退出全屏' : '全屏',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onSettingsChanged(
                          settings.copyWith(immersive: !settings.immersive),
                        ),
                        icon: Icon(
                          settings.immersive
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    for (final c in [0xFF000000, 0xFF333333, 0xFFFFFFFF])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => onSettingsChanged(
                            settings.copyWith(comicBackground: c),
                          ),
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Color(c),
                          ),
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final controller = TextEditingController(
                          text: pageLabel.split(' · ').last.split(' / ').first,
                        );
                        final go = await showDialog<int>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('跳转页码'),
                            content: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(
                                  context,
                                  int.tryParse(controller.text),
                                ),
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        );
                        controller.dispose();
                        if (go != null) onPageInput(go - 1);
                      },
                      child: const Text(
                        '跳页',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
