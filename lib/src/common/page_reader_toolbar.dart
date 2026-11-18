import 'package:material_ui/material_ui.dart';

import '../comic/comic_reading_mode.dart';
import 'reader_settings.dart';
import 'reader_strings.dart';
import 'novel_typography.dart';

class PageReaderToolbar extends StatelessWidget {
  const PageReaderToolbar({
    super.key,
    @Deprecated('Use currentPage and totalPages instead.') this.pageLabel,
    this.currentPage,
    this.totalPages,
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
    this.strings = ReaderStrings.auto,
    this.showAutoCrop = false,
    this.allowWebtoon = true,
  }) : assert(
         pageLabel != null || (currentPage != null && totalPages != null),
         'Provide currentPage and totalPages (or the legacy pageLabel).',
       );

  /// Offer the webtoon reading mode (comic only; PDF must pass `false`).
  final bool allowWebtoon;

  /// Show the auto-crop toggle (comic only).
  final bool showAutoCrop;

  final ReaderStrings strings;

  /// Legacy free-form label; ignored when [currentPage]/[totalPages] are set.
  final String? pageLabel;

  /// 1-based page shown to the user.
  final int? currentPage;
  final int? totalPages;
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

  String _label(ReaderStrings strings) =>
      currentPage != null && totalPages != null
      ? strings.pageOf(currentPage!, totalPages!)
      : pageLabel ?? '';

  String _modeName(ReaderStrings strings, ComicReadingMode m) => switch (m) {
    ComicReadingMode.vertical => strings.modeVertical,
    ComicReadingMode.horizontal => strings.modeHorizontal,
    ComicReadingMode.webtoon => strings.modeWebtoon,
  };

  String _fitName(ReaderStrings strings, ComicFitMode m) => switch (m) {
    ComicFitMode.contain => strings.fitContain,
    ComicFitMode.width => strings.fitWidth,
    ComicFitMode.height => strings.fitHeight,
  };

  @override
  Widget build(BuildContext context) {
    final strings = this.strings.resolveFor(
      Localizations.maybeLocaleOf(context),
    );
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Colors.black54,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _label(strings),
                    style: const TextStyle(color: Colors.white),
                  ),
                  Slider(
                    value: progress.clamp(0, 1),
                    label: '${(progress.clamp(0, 1) * 100).round()}%',
                    semanticFormatterCallback: (v) =>
                        '${strings.progress} ${(v * 100).round()}%',
                    onChanged: onSeek,
                  ),
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
                          label: '${(settings.brightness * 100).round()}%',
                          semanticFormatterCallback: (v) =>
                              '${strings.brightness} ${(v * 100).round()}%',
                          onChanged: (v) => onSettingsChanged(
                            settings.copyWith(brightness: v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.swipe, color: Colors.white, size: 18),
                      Expanded(
                        child: Slider(
                          min: 0.5,
                          max: 2.0,
                          value: settings.swipeSensitivity.clamp(0.5, 2.0),
                          label: settings.swipeSensitivity.toStringAsFixed(1),
                          semanticFormatterCallback: (v) =>
                              '${strings.swipeSensitivity} ${v.toStringAsFixed(1)}',
                          onChanged: (v) => onSettingsChanged(
                            settings.copyWith(swipeSensitivity: v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip:
                              '${strings.readingMode}: ${_modeName(strings, mode)}',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onModeChanged(switch (mode) {
                            ComicReadingMode.vertical =>
                              ComicReadingMode.horizontal,
                            ComicReadingMode.horizontal =>
                              allowWebtoon
                                  ? ComicReadingMode.webtoon
                                  : ComicReadingMode.vertical,
                            ComicReadingMode.webtoon =>
                              ComicReadingMode.vertical,
                          }),
                          icon: Icon(switch (mode) {
                            ComicReadingMode.vertical => Icons.swap_vert,
                            ComicReadingMode.horizontal => Icons.swap_horiz,
                            ComicReadingMode.webtoon => Icons.view_day,
                          }, color: Colors.white),
                        ),
                        IconButton(
                          tooltip:
                              '${strings.fit}: ${_fitName(strings, settings.comicFitMode)}',
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
                          icon: const Icon(
                            Icons.fit_screen,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: settings.doublePage
                              ? strings.doublePageOff
                              : mode == ComicReadingMode.vertical
                              ? strings.doublePageSwitchHint
                              : strings.doublePage,
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
                          tooltip: bookmarked
                              ? strings.removeBookmark
                              : strings.addBookmark,
                          visualDensity: VisualDensity.compact,
                          onPressed: onToggleBookmark,
                          icon: Icon(
                            bookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: strings.bookmarkList,
                          visualDensity: VisualDensity.compact,
                          onPressed: onShowBookmarks,
                          icon: const Icon(
                            Icons.bookmarks,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: strings.thumbnails,
                          visualDensity: VisualDensity.compact,
                          onPressed: onShowThumbs,
                          icon: const Icon(
                            Icons.grid_view,
                            color: Colors.white,
                          ),
                        ),
                        if (showAutoCrop)
                          IconButton(
                            tooltip: settings.comicAutoCrop
                                ? strings.autoCropOff
                                : strings.autoCrop,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onSettingsChanged(
                              settings.copyWith(
                                comicAutoCrop: !settings.comicAutoCrop,
                              ),
                            ),
                            icon: Icon(
                              Icons.crop,
                              color: settings.comicAutoCrop
                                  ? Colors.amber
                                  : Colors.white,
                            ),
                          ),
                        IconButton(
                          tooltip: strings.keepScreenOn,
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
                          tooltip: settings.volumeKeyPaging
                              ? strings.volumeKeyPagingOff
                              : strings.volumeKeyPaging,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onSettingsChanged(
                            settings.copyWith(
                              volumeKeyPaging: !settings.volumeKeyPaging,
                            ),
                          ),
                          icon: Icon(
                            Icons.volume_up,
                            color: settings.volumeKeyPaging
                                ? Colors.amber
                                : Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: settings.immersive
                              ? strings.exitFullscreen
                              : strings.fullscreen,
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
                          child: Semantics(
                            button: true,
                            selected: settings.comicBackground == c,
                            label:
                                '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                            excludeSemantics: true,
                            onTap: () => onSettingsChanged(
                              settings.copyWith(comicBackground: c),
                            ),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => onSettingsChanged(
                                settings.copyWith(comicBackground: c),
                              ),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Color(c),
                                    child: settings.comicBackground == c
                                        ? Icon(
                                            Icons.check,
                                            size: 14,
                                            color: c == 0xFFFFFFFF
                                                ? Colors.black
                                                : Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final go = await showDialog<int>(
                            context: context,
                            builder: (context) => _GoToPageDialog(
                              strings: strings,
                              initial: currentPage ?? 1,
                            ),
                          );
                          if (go != null) onPageInput(go - 1);
                        },
                        child: Text(
                          strings.goToPage,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Page-number dialog that owns (and disposes) its controller, so the text
/// field is never used after the route's exit animation.
class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({required this.strings, required this.initial});

  final ReaderStrings strings;
  final int initial;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.initial}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return AlertDialog(
      title: Text(strings.goToPageTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        onSubmitted: (_) =>
            Navigator.pop(context, int.tryParse(_controller.text)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, int.tryParse(_controller.text)),
          child: Text(strings.confirm),
        ),
      ],
    );
  }
}
