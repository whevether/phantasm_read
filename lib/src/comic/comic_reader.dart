import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:material_ui/material_ui.dart';
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
import '../common/reader_trial_limit.dart';
import '../common/reader_page_window.dart';
import '../common/page_reader_toolbar.dart';
import '../common/reader_identity.dart';
import '../common/reader_watermark.dart';
import '../common/tap_zones.dart';
import '../common/trial_gesture_boundary.dart';
import 'comic_network_cache.dart';
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
    this.trialLimit,
    this.onTrialLimitReached,
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
  final ReaderTrialLimit? trialLimit;
  final ReaderTrialLimitCallback? onTrialLimitReached;
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

class _ComicReaderState extends State<ComicReader> with WidgetsBindingObserver {
  late final ReaderBrightness _brightness = ReaderBrightness();
  late ReaderSettings _settings;
  late ComicReadingMode _mode;
  ExtendedPageController? _pageController;
  bool _toolbarVisible = false;
  int _currentPage = 0;
  List<ReaderBookmark> _bookmarks = const [];
  DateTime? _sessionStarted;
  Timer? _sessionTimer;
  late final _session = ReaderSession(_brightness);
  int _loadVersion = 0;
  String? _identity;
  String? _error;
  bool _loading = true;
  final TrialGestureNotifier _trialGesture = TrialGestureNotifier();

  String get _bookId => widget.bookId ?? (_identity ??= widget.pages.stableId);

  bool get _doublePageActive =>
      _settings.doublePage &&
      _mode == ComicReadingMode.horizontal &&
      widget.pages.length > 1;

  ReaderPageWindow get _window => ReaderPageWindow(
    widget.pages.length,
    trial: widget.trialLimit,
    doublePage: _doublePageActive,
  );
  int get _fullPageCount => widget.pages.length;
  int get _pageCount => _window.count;
  int _rawIndex(int logical) => _window.content(logical);

  int _contentPageIndex(int logicalIndex) => _rawIndex(logicalIndex);

  void _notifyTrialLimit(ReaderTrialLimitAction action, int targetIndex) {
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive) return;
    widget.onTrialLimitReached?.call(
      ReaderTrialLimitEvent(
        limit: limit,
        currentIndex: _contentPageIndex(_currentPage),
        targetIndex: targetIndex,
        totalCount: widget.pages.length,
        action: action,
      ),
    );
  }

  bool get _hasMoreBeyondTrial {
    final limit = widget.trialLimit;
    return limit != null &&
        limit.isActive &&
        limit.hasMoreBeyond(widget.pages.length);
  }

  int get _pageViewCount => trialPageViewCount(_pageCount, _hasMoreBeyondTrial);

  void _onTrialNextSentinel() {
    final limit = widget.trialLimit;
    if (limit == null || !_hasMoreBeyondTrial || _pageCount <= 0) return;
    final lastLogical = _pageCount - 1;
    _trialGesture.call(
      widget.onTrialLimitReached,
      limit: limit,
      currentIndex: _contentPageIndex(lastLogical),
      targetIndex: _contentPageIndex(lastLogical) + 1,
      totalCount: widget.pages.length,
      action: ReaderTrialLimitAction.next,
    );
    _currentPage = lastLogical;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = _pageController;
      if (c != null && c.hasClients) {
        c.jumpToPage(lastLogical);
      }
      if (mounted) setState(() {});
    });
  }

  int _logicalIndexForRaw(int raw, {bool? doublePage, ComicReadingMode? mode}) {
    return ReaderPageWindow(
      widget.pages.length,
      trial: widget.trialLimit,
      doublePage:
          (doublePage ?? _settings.doublePage) &&
          (mode ?? _mode) == ComicReadingMode.horizontal,
    ).logical(raw);
  }

  void _syncPageIndexAfterLayoutChange() {
    final logical = _logicalIndexForRaw(_currentRawIndex);
    _currentPage = logical;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _pageController;
      if (controller == null || !controller.hasClients) return;
      if (controller.page?.round() != logical) {
        controller.jumpToPage(logical);
      }
    });
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
    final version = ++_loadVersion;
    final bookId = _bookId;
    final pages = widget.pages;
    var settings = widget.settings;
    var content = widget.initialPage;
    var legacyPosition = false;
    try {
      if (widget.persistSettings) {
        settings = await ReaderSettingsStore.instance.load() ?? settings;
      }
      if (!mounted || version != _loadVersion) return;
      if (widget.persistProgress) {
        final progress = await ReaderProgressStore.instance.load(bookId);
        if (progress != null) {
          content = progress.pageIndex;
          legacyPosition = progress.positionVersion < 2;
        }
      }
      final bookmarks = await ReaderBookmarkStore.instance.listBookmarks(
        bookId,
      );
      if (pages is ComicPagesUrls) await ensureComicNetworkImageCache();
      if (!mounted || version != _loadVersion) return;
      _settings = settings;
      if (legacyPosition) content = _window.content(content);
      _bookmarks = bookmarks
          .map(
            (b) => b.positionVersion >= 2 || b.pageIndex == null
                ? b
                : ReaderBookmark(
                    id: b.id,
                    bookId: b.bookId,
                    title: b.title,
                    pageIndex: _window.content(b.pageIndex!),
                    cfi: b.cfi,
                    paragraphIndex: b.paragraphIndex,
                    note: b.note,
                    createdAt: b.createdAt,
                  ),
          )
          .toList();
      if (bookmarks.any((b) => b.positionVersion < 2)) {
        await ReaderBookmarkStore.instance.saveBookmarks(bookId, _bookmarks);
      }
      if (!mounted || version != _loadVersion) return;
      _currentPage = _logicalIndexForRaw(content);
      final old = _pageController;
      _pageController = ExtendedPageController(initialPage: _currentPage);
      WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
      await _session.apply(_settings);
      if (!mounted || version != _loadVersion) return;
      _sessionTimer?.cancel();
      _sessionStarted = DateTime.now();
      _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          widget.onSessionTick?.call(
            DateTime.now().difference(_sessionStarted!),
          );
        }
      });
      setState(() => _loading = false);
    } catch (e) {
      if (mounted && version == _loadVersion) setState(() => _error = '$e');
    }
  }

  Future<void> _saveProgress() async {
    if (!widget.persistProgress ||
        _loading ||
        _pageController == null ||
        widget.pages.length == 0) {
      return;
    }
    final progress = ReaderProgress(
      bookId: _bookId,
      pageIndex: _currentRawIndex,
      percentage: widget.pages.length == 0
          ? 0
          : (_currentRawIndex + 1) / widget.pages.length,
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
    if (oldWidget.pages.stableId != widget.pages.stableId ||
        oldWidget.bookId != widget.bookId) {
      _identity = null;
      _error = null;
      _loading = true;
      _sessionTimer?.cancel();
      _mode = widget.readingMode;
      _bootstrap();
      return;
    }
    final raw = _currentRawIndex;
    if (oldWidget.settings != widget.settings) {
      _settings = widget.settings;
      _session.apply(_settings);
    }
    if (oldWidget.readingMode != widget.readingMode) _mode = widget.readingMode;
    _currentPage = _logicalIndexForRaw(raw);
    _syncPageIndexAfterLayoutChange();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveProgress();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _saveProgress();
    _loadVersion++;
    _session.dispose();
    _pageController?.dispose();

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
      if (_doublePageActive && _window.readable(raw + 1)) {
        await precacheImage(_providerAt(raw + 1), context);
      }
    }
  }

  int get _currentRawIndex => _contentPageIndex(_currentPage);

  void _emitSettings(ReaderSettings next) {
    final wasDouble = _doublePageActive;
    final enablingDouble = next.doublePage && !_settings.doublePage;
    var nextMode = _mode;
    if (enablingDouble && _mode == ComicReadingMode.vertical) {
      nextMode = ComicReadingMode.horizontal;
    }
    final raw = _currentRawIndex;
    setState(() {
      _settings = next;
      _mode = nextMode;
      _currentPage = _logicalIndexForRaw(
        raw,
        doublePage: next.doublePage,
        mode: nextMode,
      );
    });
    if (wasDouble != _doublePageActive) {
      _syncPageIndexAfterLayoutChange();
    }
    _session.apply(next);
    if (widget.persistSettings) {
      ReaderSettingsStore.instance.save(next);
    }
    widget.onSettingsChanged?.call(next);
  }

  void _goToPage(int logicalPage) {
    if (_pageCount == 0) return;
    if (logicalPage < 0 || logicalPage >= _pageCount) {
      _notifyTrialLimit(
        ReaderTrialLimitAction.seek,
        logicalPage < 0 ? _window.start - 1 : _window.start + _window.visible,
      );
    }
    final target = logicalPage.clamp(0, _pageCount - 1);
    if (_pageController?.hasClients ?? false) {
      _pageController!.jumpToPage(target);
    }
    setState(() => _currentPage = target);
    widget.onPageChanged?.call(_contentPageIndex(target));
    _saveProgress();
  }

  void _goToContent(int raw) {
    if (!_window.readable(raw)) {
      _notifyTrialLimit(ReaderTrialLimitAction.seek, raw);
      return;
    }
    _goToPage(_logicalIndexForRaw(raw));
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
    if (_doublePageActive && _window.readable(raw + 1)) {
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
        state.handleDoubleTap(scale: end, doubleTapPosition: pointerDown);
      },
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return const Center(child: CircularProgressIndicator());
          case LoadState.failed:
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '图片加载失败',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: state.reLoadImage,
                  ),
                ],
              ),
            );
          case LoadState.completed:
            return null;
        }
      },
    );
  }

  Future<void> _toggleBookmark() async {
    final existing = _bookmarks.where((b) => b.pageIndex == _currentRawIndex);
    if (existing.isNotEmpty) {
      await ReaderBookmarkStore.instance.removeBookmark(
        _bookId,
        existing.first.id,
      );
    } else {
      await ReaderBookmarkStore.instance.addBookmark(
        ReaderBookmark(
          id: readerRecordId(),
          bookId: _bookId,
          title: 'Page ${_currentRawIndex + 1}',
          pageIndex: _currentRawIndex,
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
                  if (b.pageIndex != null) _goToContent(b.pageIndex!);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ReaderBookmarkStore.instance.removeBookmark(
                      _bookId,
                      b.id,
                    );
                    _bookmarks = await ReaderBookmarkStore.instance
                        .listBookmarks(_bookId);
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
            itemCount: _window.visible,
            itemBuilder: (context, i) {
              final index = _window.start + i;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _goToContent(index);
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
    if (_loading && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) return Center(child: Text('Load failed: $_error'));
    if (widget.pages.length == 0 || _window.visible == 0) {
      return const Center(child: Text('No readable content'));
    }
    final controller = _pageController;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final progress = _pageCount == 0 ? 0.0 : (_currentPage + 1) / _pageCount;
    final bookmarked = _bookmarks.any((b) => b.pageIndex == _currentRawIndex);

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
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (_) {
                    if (widget.showToolbar) {
                      setState(() => _toolbarVisible = !_toolbarVisible);
                    }
                  },
                  child: ExtendedImageGesturePageView.builder(
                    key: ValueKey(
                      '${_mode.name}-${_settings.doublePage}-$_pageViewCount',
                    ),
                    itemCount: _pageViewCount,
                    controller: controller,
                    scrollDirection: _mode == ComicReadingMode.vertical
                        ? Axis.vertical
                        : Axis.horizontal,
                    reverse: widget.rtl && _mode == ComicReadingMode.horizontal,
                    onPageChanged: (index) {
                      if (isTrialNextSentinel(
                        index: index,
                        readableCount: _pageCount,
                        hasMoreBeyond: _hasMoreBeyondTrial,
                      )) {
                        _onTrialNextSentinel();
                        return;
                      }
                      _currentPage = index;
                      widget.onPageChanged?.call(_contentPageIndex(index));
                      _precacheNeighbors(index);
                      _saveProgress();
                      if (mounted) setState(() {});
                    },
                    itemBuilder: (context, index) {
                      if (isTrialNextSentinel(
                        index: index,
                        readableCount: _pageCount,
                        hasMoreBeyond: _hasMoreBeyondTrial,
                      )) {
                        return const SizedBox.expand();
                      }
                      final page = _buildPage(index);
                      if (widget.pageTurnEffect == PageTurnEffect.none ||
                          _mode == ComicReadingMode.vertical) {
                        return page;
                      }
                      return AnimatedBuilder(
                        animation: controller,
                        child: page,
                        builder: (context, child) {
                          final offset =
                              controller.hasClients &&
                                  controller.position.hasContentDimensions
                              ? ((controller.page ??
                                            controller.initialPage.toDouble()) -
                                        index)
                                    .clamp(-1.0, 1.0)
                              : 0.0;
                          return PageCurl(
                            progress: offset.abs(),
                            hinge: offset < 0
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: child!,
                          );
                        },
                      );
                    },
                  ),
                ),
                BrightnessOverlay(
                  brightness: _brightness.value,
                  mode: _brightness.mode,
                ),
                if (widget.watermarkText != null)
                  ReaderWatermark(text: widget.watermarkText!),
                ReaderInk(
                  key: ValueKey('$_bookId:$_currentRawIndex'),
                  bookId: _bookId,
                  location: '$_currentRawIndex',
                  enabled: widget.enableInk,
                ),
                if (!_toolbarVisible)
                  ReaderProgressBar(
                    progress: progress,
                    onSeek: (v) => _goToPage((v * (_pageCount - 1)).round()),
                  ),
                if (widget.showToolbar && _toolbarVisible)
                  PageReaderToolbar(
                    pageLabel:
                        '${_contentPageIndex(_currentPage) + 1} / $_fullPageCount',
                    progress: progress,
                    settings: _settings,
                    mode: _mode,
                    bookmarked: bookmarked,
                    onModeChanged: (mode) {
                      final raw = _currentRawIndex;
                      setState(() {
                        _mode = mode;
                        _currentPage = _logicalIndexForRaw(raw, mode: mode);
                      });
                      _syncPageIndexAfterLayoutChange();
                    },
                    onSettingsChanged: _emitSettings,
                    onToggleBookmark: _toggleBookmark,
                    onShowBookmarks: _showBookmarks,
                    onShowThumbs: _showThumbnails,
                    onSeek: (v) => _goToPage((v * (_pageCount - 1)).round()),
                    onPageInput: _goToContent,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
