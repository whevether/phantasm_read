import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/ink_annotation.dart';
import '../common/novel_typography.dart';
import '../common/page_curl.dart';
import '../common/reader_bookmark.dart';
import '../common/reader_brightness.dart';
import '../common/reader_lifecycle.dart';
import '../common/reader_progress.dart';
import '../common/reader_settings.dart';
import '../common/reader_settings_store.dart';
import '../common/reader_sync.dart';
import '../common/reader_wake_lock.dart';
import '../common/reader_watermark.dart';
import '../common/tap_zones.dart';
import 'comic_pages.dart';
import 'comic_reading_mode.dart';

/// Image comic reader powered by `extended_image` 10.1.0.
class ComicReader extends StatefulWidget {
  const ComicReader({
    super.key,
    required this.pages,
    this.bookId,
    this.readingMode = ComicReadingMode.vertical,
    this.settings = const ReaderSettings(),
    this.rtl = false,
    this.initialPage = 0,
    this.persistProgress = true,
    this.persistSettings = true,
    this.maxReadablePages,
    this.watermarkText,
    this.enableInk = false,
    this.pageTurnEffect = PageTurnEffect.none,
    this.onPageChanged,
    this.onSettingsChanged,
    this.onSessionTick,
    this.onSync,
    this.showToolbar = true,
  });

  final ComicPages pages;
  final String? bookId;
  final ComicReadingMode readingMode;
  final ReaderSettings settings;
  final bool rtl;
  final int initialPage;
  final bool persistProgress;
  final bool persistSettings;
  final int? maxReadablePages;
  final String? watermarkText;
  final bool enableInk;
  final PageTurnEffect pageTurnEffect;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<ReaderSettings>? onSettingsChanged;
  final ValueChanged<Duration>? onSessionTick;
  final ReaderSyncCallback? onSync;
  final bool showToolbar;

  @override
  State<ComicReader> createState() => _ComicReaderState();
}

class _ComicReaderState extends State<ComicReader>
    with WidgetsBindingObserver {
  late final ReaderBrightness _brightness = ReaderBrightness();
  late ReaderSettings _settings;
  late ComicReadingMode _mode;
  ExtendedPageController? _pageController;
  bool _toolbarVisible = false;
  int _currentPage = 0;
  List<ReaderBookmark> _bookmarks = const [];
  DateTime? _sessionStarted;
  Timer? _sessionTimer;

  String get _bookId =>
      widget.bookId ?? 'comic_${widget.pages.length}_${widget.pages.hashCode}';

  int get _pageCount {
    final total = () {
      if (_settings.doublePage &&
          _mode == ComicReadingMode.horizontal &&
          widget.pages.length > 1) {
        return (widget.pages.length / 2).ceil();
      }
      return widget.pages.length;
    }();
    return trialPageCount(total, widget.maxReadablePages);
  }

  int _rawIndex(int logical) {
    if (_settings.doublePage && _mode == ComicReadingMode.horizontal) {
      return (logical * 2).clamp(0, widget.pages.length - 1);
    }
    return logical.clamp(0, widget.pages.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _mode = widget.readingMode;
    _currentPage = widget.initialPage;
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.persistSettings) {
      final saved = await ReaderSettingsStore.instance.load();
      if (saved != null && mounted) {
        _settings = saved.copyWith(
          // keep comic-specific from widget if needed
        );
      }
    }
    if (widget.persistProgress) {
      final progress = await ReaderProgressStore.instance.load(_bookId);
      if (progress != null) {
        _currentPage = progress.pageIndex.clamp(0, _pageCount - 1);
      }
    }
    _bookmarks = await ReaderBookmarkStore.instance.listBookmarks(_bookId);
    _pageController = ExtendedPageController(initialPage: _currentPage);
    if (_settings.immersive) await ReaderImmersive.enter();
    await _enterReading();
    _sessionStarted = DateTime.now();
    _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final started = _sessionStarted;
      if (started != null) {
        widget.onSessionTick?.call(DateTime.now().difference(started));
      }
    });
    if (mounted) setState(() {});
  }

  Future<void> _enterReading() async {
    await _brightness.apply(_settings.brightness);
    if (_settings.keepScreenOn) await ReaderWakeLock.enable();
  }

  Future<void> _leaveReading() async {
    await _brightness.restore();
    await ReaderWakeLock.disable();
    await ReaderImmersive.leave();
  }

  Future<void> _saveProgress() async {
    if (!widget.persistProgress) return;
    final progress = ReaderProgress(
      bookId: _bookId,
      pageIndex: _currentPage,
      percentage: _pageCount == 0 ? 0 : (_currentPage + 1) / _pageCount,
    );
    await ReaderProgressStore.instance.save(progress);
    await ReaderSyncHub(onSync: widget.onSync).emit(
      ReaderSyncPayload(
        bookId: _bookId,
        progress: progress,
        bookmarks: _bookmarks,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant ComicReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _settings = widget.settings;
      _brightness.apply(_settings.brightness);
      if (_settings.keepScreenOn) {
        ReaderWakeLock.enable();
      } else {
        ReaderWakeLock.disable();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ReaderWakeLock.disable();
      _saveProgress();
    } else if (state == AppLifecycleState.resumed && _settings.keepScreenOn) {
      ReaderWakeLock.enable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _saveProgress();
    _leaveReading();
    _pageController?.dispose();
    _brightness.dispose();
    super.dispose();
  }

  ImageProvider _providerAt(int index) => widget.pages.imageProviderAt(index);

  Future<void> _precacheNeighbors(int index) async {
    final targets = <int>{
      if (index - 1 >= 0) index - 1,
      if (index + 1 < _pageCount) index + 1,
    };
    for (final i in targets) {
      if (!mounted) return;
      final raw = _rawIndex(i);
      await precacheImage(_providerAt(raw), context);
      if (!mounted) return;
      if (_settings.doublePage && raw + 1 < widget.pages.length) {
        await precacheImage(_providerAt(raw + 1), context);
      }
    }
  }

  void _emitSettings(ReaderSettings next) {
    setState(() => _settings = next);
    _brightness.apply(next.brightness);
    if (next.keepScreenOn) {
      ReaderWakeLock.enable();
    } else {
      ReaderWakeLock.disable();
    }
    if (next.immersive) {
      ReaderImmersive.enter();
    } else {
      ReaderImmersive.leave();
    }
    if (widget.persistSettings) {
      ReaderSettingsStore.instance.save(next);
    }
    widget.onSettingsChanged?.call(next);
  }

  void _goToPage(int page) {
    final p = clampTrialPage(page, _pageCount, null);
    _pageController?.jumpToPage(p);
    setState(() => _currentPage = p);
    widget.onPageChanged?.call(p);
    _saveProgress();
  }

  void _onTapZone(TapZoneAction action) {
    switch (action) {
      case TapZoneAction.previous:
        _goToPage(_currentPage - 1);
      case TapZoneAction.next:
        _goToPage(_currentPage + 1);
      case TapZoneAction.toggleToolbar:
        if (widget.showToolbar) {
          setState(() => _toolbarVisible = !_toolbarVisible);
        }
    }
  }

  BoxFit get _fit {
    switch (_settings.comicFitMode) {
      case ComicFitMode.contain:
        return BoxFit.contain;
      case ComicFitMode.width:
        return BoxFit.fitWidth;
      case ComicFitMode.height:
        return BoxFit.fitHeight;
    }
  }

  Widget _buildPage(int logicalIndex) {
    final raw = _rawIndex(logicalIndex);
    if (_settings.doublePage &&
        _mode == ComicReadingMode.horizontal &&
        raw + 1 < widget.pages.length) {
      return Row(
        children: [
          Expanded(child: _image(raw)),
          Expanded(child: _image(raw + 1)),
        ],
      );
    }
    return _image(raw);
  }

  Widget _image(int index) {
    return ExtendedImage(
      image: _providerAt(index),
      mode: ExtendedImageMode.gesture,
      fit: _fit,
      initGestureConfigHandler: (state) => GestureConfig(
        minScale: 1.0,
        maxScale: 4.0,
        animationMinScale: 0.8,
        animationMaxScale: 4.5,
        inPageView: true,
        initialScale: 1.0,
        cacheGesture: false,
      ),
      onDoubleTap: (state) {
        final pointerDown = state.pointerDownPosition;
        final begin = state.gestureDetails?.totalScale ?? 1.0;
        final end = begin > 1.5 ? 1.0 : 2.5;
        state.handleDoubleTap(
          scale: end,
          doubleTapPosition: pointerDown,
        );
      },
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
            return null;
        }
      },
    );
  }

  Future<void> _toggleBookmark() async {
    final existing = _bookmarks.where((b) => b.pageIndex == _currentPage);
    if (existing.isNotEmpty) {
      await ReaderBookmarkStore.instance.removeBookmark(_bookId, existing.first.id);
    } else {
      await ReaderBookmarkStore.instance.addBookmark(
        ReaderBookmark(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          bookId: _bookId,
          title: 'Page ${_currentPage + 1}',
          pageIndex: _currentPage,
        ),
      );
    }
    _bookmarks = await ReaderBookmarkStore.instance.listBookmarks(_bookId);
    if (mounted) setState(() {});
  }

  Future<void> _showBookmarks() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return ListView(
          children: [
            const ListTile(title: Text('书签')),
            for (final b in _bookmarks)
              ListTile(
                title: Text(b.title),
                onTap: () {
                  Navigator.pop(context);
                  if (b.pageIndex != null) _goToPage(b.pageIndex!);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ReaderBookmarkStore.instance
                        .removeBookmark(_bookId, b.id);
                    _bookmarks =
                        await ReaderBookmarkStore.instance.listBookmarks(_bookId);
                    if (context.mounted) Navigator.pop(context);
                    if (mounted) setState(() {});
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showThumbnails() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: widget.pages.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  final logical = _settings.doublePage ? index ~/ 2 : index;
                  _goToPage(logical);
                },
                child: Image(image: _providerAt(index), fit: BoxFit.cover),
              );
            },
          ),
        );
      },
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.audioVolumeUp ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown) {
      _goToPage(_currentPage + (widget.rtl ? -1 : 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.audioVolumeDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      _goToPage(_currentPage + (widget.rtl ? 1 : -1));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _pageController;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final progress = _pageCount == 0 ? 0.0 : (_currentPage + 1) / _pageCount;
    final bookmarked = _bookmarks.any((b) => b.pageIndex == _currentPage);

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ListenableBuilder(
        listenable: _brightness,
        builder: (context, _) {
          return ColoredBox(
            color: Color(_settings.comicBackground),
            child: Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapUp: (d) {
                        if (!_settings.tapZonesEnabled) {
                          if (widget.showToolbar) {
                            setState(
                              () => _toolbarVisible = !_toolbarVisible,
                            );
                          }
                          return;
                        }
                        final action = TapZoneDetector(
                          enabled: true,
                          rtl: widget.rtl &&
                              _mode == ComicReadingMode.horizontal,
                        ).resolve(
                          d.localPosition,
                          Size(constraints.maxWidth, constraints.maxHeight),
                        );
                        _onTapZone(action);
                      },
                      child: ExtendedImageGesturePageView.builder(
                        itemCount: _pageCount,
                        controller: controller,
                        scrollDirection: _mode == ComicReadingMode.vertical
                            ? Axis.vertical
                            : Axis.horizontal,
                        reverse:
                            widget.rtl && _mode == ComicReadingMode.horizontal,
                        onPageChanged: (index) {
                          _currentPage = index;
                          widget.onPageChanged?.call(index);
                          _precacheNeighbors(index);
                          _saveProgress();
                          if (mounted) setState(() {});
                        },
                        itemBuilder: (context, index) => _buildPage(index),
                      ),
                    );
                  },
                ),
                BrightnessOverlay(
                  brightness: _brightness.value,
                  mode: _brightness.mode,
                ),
                if (widget.watermarkText != null)
                  ReaderWatermark(text: widget.watermarkText!),
                InkAnnotationLayer(enabled: widget.enableInk),
                if (!_toolbarVisible)
                  ReaderProgressBar(
                    progress: progress,
                    onSeek: (v) =>
                        _goToPage((v * (_pageCount - 1)).round()),
                  ),
                if (widget.showToolbar && _toolbarVisible)
                  _ComicToolbar(
                    pageLabel: '${_currentPage + 1} / $_pageCount',
                    progress: progress,
                    settings: _settings,
                    mode: _mode,
                    bookmarked: bookmarked,
                    onModeChanged: (mode) => setState(() => _mode = mode),
                    onSettingsChanged: _emitSettings,
                    onToggleBookmark: _toggleBookmark,
                    onShowBookmarks: _showBookmarks,
                    onShowThumbs: _showThumbnails,
                    onSeek: (v) =>
                        _goToPage((v * (_pageCount - 1)).round()),
                    onPageInput: _goToPage,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ComicToolbar extends StatelessWidget {
  const _ComicToolbar({
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
                    const Icon(Icons.brightness_6, color: Colors.white, size: 18),
                    Expanded(
                      child: Slider(
                        value: settings.brightness,
                        onChanged: (v) =>
                            onSettingsChanged(settings.copyWith(brightness: v)),
                      ),
                    ),
                    IconButton(
                      tooltip: '方向',
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
                      onPressed: () {
                        final next = switch (settings.comicFitMode) {
                          ComicFitMode.contain => ComicFitMode.width,
                          ComicFitMode.width => ComicFitMode.height,
                          ComicFitMode.height => ComicFitMode.contain,
                        };
                        onSettingsChanged(settings.copyWith(comicFitMode: next));
                      },
                      icon: const Icon(Icons.fit_screen, color: Colors.white),
                    ),
                    IconButton(
                      tooltip: '双页',
                      onPressed: () => onSettingsChanged(
                        settings.copyWith(doublePage: !settings.doublePage),
                      ),
                      icon: Icon(
                        Icons.chrome_reader_mode,
                        color: settings.doublePage ? Colors.amber : Colors.white,
                      ),
                    ),
                    IconButton(
                      tooltip: '书签',
                      onPressed: onToggleBookmark,
                      icon: Icon(
                        bookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      tooltip: '书签列表',
                      onPressed: onShowBookmarks,
                      icon: const Icon(Icons.bookmarks, color: Colors.white),
                    ),
                    IconButton(
                      tooltip: '缩略图',
                      onPressed: onShowThumbs,
                      icon: const Icon(Icons.grid_view, color: Colors.white),
                    ),
                    IconButton(
                      tooltip: '不熄屏',
                      onPressed: () => onSettingsChanged(
                        settings.copyWith(keepScreenOn: !settings.keepScreenOn),
                      ),
                      icon: Icon(
                        settings.keepScreenOn
                            ? Icons.phonelink_lock
                            : Icons.phonelink_erase,
                        color: Colors.white,
                      ),
                    ),
                  ],
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
                          text: pageLabel.split(' / ').first,
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
                        if (go != null) onPageInput(go - 1);
                      },
                      child: const Text('跳页', style: TextStyle(color: Colors.white)),
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
