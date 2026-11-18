import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

import '../comic/comic_reading_mode.dart';
import '../common/ink_annotation.dart';
import '../common/novel_typography.dart';
import '../common/reader_bookmark.dart';
import '../common/reader_brightness.dart';
import '../common/reader_lifecycle.dart';
import '../common/reader_progress.dart';
import '../common/reader_settings.dart';
import '../common/reader_settings_store.dart';
import '../common/reader_sync.dart';
import '../common/reader_stats.dart';
import '../common/reader_strings.dart';
import '../common/reader_swipe_physics.dart';
import '../common/reader_trial_limit.dart';
import '../common/reader_identity.dart';
import '../common/reader_page_window.dart';
import '../common/page_reader_toolbar.dart';
import 'pdf_raster_cache.dart';
import '../common/reader_watermark.dart';
import '../common/tap_zones.dart';
import '../common/trial_gesture_boundary.dart';
import '../novel/file_bytes.dart';

/// PDF document source.
sealed class PdfSource {
  const PdfSource();
  String get stableId => switch (this) {
    PdfSourceFile(:final path) => readerIdentity('pdf_file', [path]),
    PdfSourceUrl(:final url) => readerIdentity('pdf_url', [url]),
    PdfSourceBytes(:final bytes) => readerBytesIdentity('pdf_bytes', bytes),
  };
  factory PdfSource.file(String path) = PdfSourceFile;
  factory PdfSource.bytes(Uint8List bytes, {String name = 'doc.pdf'}) {
    return PdfSourceBytes(bytes, name: name);
  }
  factory PdfSource.url(String url, {String? name}) = PdfSourceUrl;
}

final class PdfSourceFile extends PdfSource {
  const PdfSourceFile(this.path);
  final String path;
}

final class PdfSourceBytes extends PdfSource {
  PdfSourceBytes(this.bytes, {this.name = 'doc.pdf'});
  final Uint8List bytes;
  final String name;
}

final class PdfSourceUrl extends PdfSource {
  const PdfSourceUrl(this.url, {this.name});
  final String url;
  final String? name;
}

/// PDF reader using bounded on-demand `printing` rasters.
///
/// Feature set aligns with [ComicReader] for page-based reading: toolbar,
/// bookmarks, thumbs, trial, ink, sync, immersive, RTL, vertical/horizontal,
/// double-page, brightness / wakelock, settings & progress persistence.
class PdfReader extends StatefulWidget {
  const PdfReader({
    super.key,
    required this.source,
    this.bookId,
    this.settings = const ReaderSettings(),
    this.readingMode = ComicReadingMode.horizontal,
    this.rtl = false,
    this.initialPage = 0,
    this.persistProgress = true,
    this.persistSettings = false,
    this.trialLimit,
    this.onTrialLimitReached,
    this.watermarkText,
    this.enableInk = false,
    this.onPageChanged,
    this.onSettingsChanged,
    this.onSessionTick,
    this.onStats,
    this.strings = ReaderStrings.auto,
    this.onSync,
    this.showToolbar = true,
    this.rasterDpi = 120,
  });

  final PdfSource source;
  final String? bookId;
  final ReaderSettings settings;
  final ComicReadingMode readingMode;
  final bool rtl;
  final int initialPage;
  final bool persistProgress;
  final bool persistSettings;
  final ReaderTrialLimit? trialLimit;
  final ReaderTrialLimitCallback? onTrialLimitReached;
  final String? watermarkText;
  final bool enableInk;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<ReaderSettings>? onSettingsChanged;
  final ValueChanged<Duration>? onSessionTick;

  /// Receives per-session reading stats (only readable pages are counted).
  final ReaderStatsCallback? onStats;

  /// Replaceable UI strings.
  final ReaderStrings strings;
  final ReaderSyncCallback? onSync;
  final bool showToolbar;
  final double rasterDpi;

  @override
  State<PdfReader> createState() => _PdfReaderState();
}

class _PdfReaderState extends State<PdfReader> with WidgetsBindingObserver {
  late final ReaderBrightness _brightness = ReaderBrightness();
  late ReaderSettings _settings;
  late ComicReadingMode _mode;
  ReaderStatsTracker? _stats;
  PageController? _pageController;

  int _totalPages = 0;
  PdfRasterCache? _rasterCache;
  late final _session = ReaderSession(_brightness);
  int _loadVersion = 0;
  String? _identity;
  int _currentPage = 0;
  bool _toolbarVisible = false;
  bool _loading = true;
  String? _error;
  List<ReaderBookmark> _bookmarks = const [];
  DateTime? _sessionStarted;
  Timer? _sessionTimer;
  final TrialGestureNotifier _trialGesture = TrialGestureNotifier();
  bool _bookmarkBusy = false;

  /// True while page 0 is shown as a preview during the page-count scan.
  bool _previewing = false;

  /// PDF has no webtoon strip; treat it as vertical.
  static ComicReadingMode _normalizeMode(ComicReadingMode mode) =>
      mode == ComicReadingMode.webtoon ? ComicReadingMode.vertical : mode;

  String get _bookId => widget.bookId ?? (_identity ??= widget.source.stableId);

  bool get _doublePageActive =>
      _settings.doublePage &&
      _mode == ComicReadingMode.horizontal &&
      _totalPages > 1;

  ReaderPageWindow get _window => ReaderPageWindow(
    _totalPages,
    trial: widget.trialLimit,
    doublePage: _doublePageActive,
  );
  int get _itemCount => _window.count;
  bool get _hasMoreBeyondTrial =>
      widget.trialLimit?.hasMoreBeyond(_totalPages) ?? false;
  int get _pageViewCount => trialPageViewCount(_itemCount, _hasMoreBeyondTrial);
  int _contentPageIndex(int logicalIndex) => _window.content(logicalIndex);
  int _logicalIndexForContent(int contentIndex) =>
      _window.logical(contentIndex);

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

  void _notifyTrialLimit(ReaderTrialLimitAction action, int targetIndex) {
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive) return;
    widget.onTrialLimitReached?.call(
      ReaderTrialLimitEvent(
        limit: limit,
        currentIndex: _contentPageIndex(_currentPage),
        targetIndex: targetIndex,
        totalCount: _totalPages,
        action: action,
      ),
    );
  }

  void _onTrialNextSentinel() {
    final limit = widget.trialLimit;
    if (limit == null || !_hasMoreBeyondTrial || _itemCount <= 0) return;
    final lastLogical = _itemCount - 1;
    _trialGesture.call(
      widget.onTrialLimitReached,
      limit: limit,
      currentIndex: _contentPageIndex(lastLogical),
      targetIndex: _contentPageIndex(lastLogical) + 1,
      totalCount: _totalPages,
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

  /// Strings resolved against the ambient locale when `strings` is
  /// [ReaderStrings.auto] (the default).
  ReaderStrings get _strings =>
      widget.strings.resolveFor(Localizations.maybeLocaleOf(context));

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _mode = _normalizeMode(widget.readingMode);
    if (_settings.doublePage && _mode == ComicReadingMode.vertical) {
      _mode = ComicReadingMode.horizontal;
    }
    _currentPage = widget.initialPage;
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap({int? restorePage}) async {
    final version = ++_loadVersion;
    final source = widget.source;
    final bookId = _bookId;
    var content = restorePage ?? widget.initialPage;
    try {
      var settings = widget.settings;
      if (widget.persistSettings) {
        settings = await ReaderSettingsStore.instance.load() ?? settings;
      }
      if (!mounted || version != _loadVersion) return;
      if (widget.persistProgress && restorePage == null) {
        content =
            (await ReaderProgressStore.instance.load(bookId))?.pageIndex ??
            content;
      }
      final bookmarks = await ReaderBookmarkStore.instance.listBookmarks(
        bookId,
      );
      final info = await Printing.info();
      if (!info.canRaster) {
        throw UnsupportedError('PDF raster is unavailable on this platform.');
      }
      final bytes = await _loadBytes(source);
      if (!mounted || version != _loadVersion) return;
      // First-page-first: build the cache now so page 0 can be shown while
      // the page count is still being determined.
      _rasterCache?.dispose();
      _rasterCache = PdfRasterCache(bytes);
      if (widget.trialLimit == null && content == 0) {
        setState(() => _previewing = true);
      }
      // Count with tiny rasters, discarding pixels immediately. Full-resolution
      // pages are rendered only when visible, rather than expanding the book.
      var count = 0;
      await for (final _ in Printing.raster(bytes, dpi: 8)) {
        if (!mounted || version != _loadVersion) return;
        if (++count > 100000) throw const FormatException('Too many PDF pages');
      }
      if (!mounted || version != _loadVersion) return;
      if (count == 0) throw const FormatException('PDF has no readable pages');
      _settings = settings;
      _bookmarks = bookmarks;
      _totalPages = count;
      _previewing = false;
      _currentPage = _logicalIndexForContent(content);
      _rebindPageController();
      await _session.apply(_settings);
      if (!mounted || version != _loadVersion) return;
      _sessionTimer?.cancel();
      _sessionStarted = DateTime.now();
      _stats = ReaderStatsTracker(
        _bookId,
        minDwell: const Duration(milliseconds: 800),
      );
      _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          widget.onSessionTick?.call(
            DateTime.now().difference(_sessionStarted!),
          );
          _emitStats();
        }
      });
      setState(() => _loading = false);
      _recordVisit();
      if (_itemCount > 0) {
        widget.onPageChanged?.call(_contentPageIndex(_currentPage));
      }
    } catch (e) {
      if (mounted && version == _loadVersion) {
        setState(() {
          _error = _describeError(e);
          _loading = false;
        });
      }
    }
  }

  /// Localised, user-facing error text (encrypted PDFs get a clear hint).
  String _describeError(Object e) {
    final text = '$e';
    final lower = text.toLowerCase();
    if (lower.contains('encrypt') || lower.contains('password')) {
      return '${_strings.loadFailed}: ${_strings.pdfEncrypted}';
    }
    return '${_strings.loadFailed}: $text';
  }

  static const _maxDownloadBytes = 300 * 1024 * 1024;

  Future<Uint8List> _loadBytes(PdfSource source) async {
    switch (source) {
      case PdfSourceFile(:final path):
        return readFileBytes(path);
      case PdfSourceBytes(:final bytes):
        return bytes;
      case PdfSourceUrl(:final url):
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 60));
        if (response.bodyBytes.length > _maxDownloadBytes) {
          throw Exception('PDF is larger than 300 MB');
        }
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode} loading $url');
        }
        if (response.bodyBytes.isEmpty) {
          throw Exception('Empty PDF response from $url');
        }
        return response.bodyBytes;
    }
  }

  /// Counts the current page (logical pages only address the readable window).
  void _recordVisit() {
    if (_loading || _totalPages == 0 || _itemCount == 0) return;
    _stats?.visit(_contentPageIndex(_currentPage));
  }

  /// Stats are independent of progress persistence.
  void _emitStats() {
    final stats = _stats;
    if (stats == null) return;
    widget.onStats?.call(stats.snapshot());
  }

  Future<void> _saveProgress() async {
    if (_totalPages == 0) return;
    _emitStats();
    if (!widget.persistProgress) return;
    final content = _contentPageIndex(_currentPage);
    final progress = ReaderProgress(
      bookId: _bookId,
      pageIndex: content,
      percentage: (content + 1) / _totalPages,
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

  void _emitSettings(ReaderSettings next) {
    final wasDouble = _doublePageActive;
    final enablingDouble = next.doublePage && !_settings.doublePage;
    final content = _contentPageIndex(_currentPage);
    var nextMode = _mode;
    if (enablingDouble && _mode == ComicReadingMode.vertical) {
      nextMode = ComicReadingMode.horizontal;
    }
    setState(() {
      _settings = next;
      _mode = nextMode;
      _currentPage = _logicalIndexForContent(content);
    });
    _session.apply(next);
    if (widget.persistSettings) {
      ReaderSettingsStore.instance.save(next);
    }
    widget.onSettingsChanged?.call(next);
    if (wasDouble != _doublePageActive || enablingDouble) {
      _rebindPageController();
      if (mounted) setState(() {});
    }
  }

  void _rebindPageController() {
    final old = _pageController;
    _pageController = PageController(initialPage: _currentPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old?.dispose();
    });
  }

  void _goToPage(int logicalPage) {
    if ((_totalPages == 0) || _itemCount <= 0) return;
    final limit = widget.trialLimit;
    if (limit != null && limit.isActive) {
      // Only a real paywall when more content exists beyond the window.
      if (logicalPage >= _itemCount && _hasMoreBeyondTrial) {
        _trialGesture.call(
          widget.onTrialLimitReached,
          limit: limit,
          currentIndex: _contentPageIndex(_currentPage),
          targetIndex: _window.start + _window.visible,
          totalCount: _totalPages,
          action: ReaderTrialLimitAction.next,
        );
      } else if (logicalPage < 0 && _window.start > 0) {
        _trialGesture.call(
          widget.onTrialLimitReached,
          limit: limit,
          currentIndex: _contentPageIndex(_currentPage),
          targetIndex: _window.start - 1,
          totalCount: _totalPages,
          action: ReaderTrialLimitAction.seek,
        );
      }
    }
    final target = logicalPage.clamp(0, _itemCount - 1);
    final c = _pageController;
    if (c != null && c.hasClients) {
      c.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
    if (target == _currentPage) return;
    setState(() => _currentPage = target);
    widget.onPageChanged?.call(_contentPageIndex(target));
    _recordVisit();
    _saveProgress();
  }

  Future<void> _toggleBookmark() async {
    if (_bookmarkBusy) return;
    _bookmarkBusy = true;
    try {
      final content = _contentPageIndex(_currentPage);
      final existing = _bookmarks.where((b) => b.pageIndex == content);
      if (existing.isNotEmpty) {
        await ReaderBookmarkStore.instance.removeBookmark(
          _bookId,
          existing.first.id,
        );
      } else {
        // The title is derived from the page index at display time.
        await ReaderBookmarkStore.instance.addBookmark(
          ReaderBookmark(
            id: readerRecordId(),
            bookId: _bookId,
            title: '',
            pageIndex: content,
          ),
        );
      }
      _bookmarks = await ReaderBookmarkStore.instance.listBookmarks(_bookId);
      await _saveProgress();
      if (mounted) setState(() {});
    } finally {
      _bookmarkBusy = false;
    }
  }

  /// Bookmarks created by older versions stored an English "Page N" title.
  String _bookmarkLabel(ReaderBookmark b) {
    final index = b.pageIndex;
    final legacy = RegExp(r'^Page \d+$').hasMatch(b.title);
    if (index != null && (b.title.isEmpty || legacy)) {
      return _strings.pageN(index + 1);
    }
    return b.title;
  }

  Future<void> _showBookmarks() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return ListView(
          children: [
            ListTile(title: Text(_strings.bookmarks)),
            for (final b in _bookmarks)
              ListTile(
                title: Text(_bookmarkLabel(b)),
                onTap: () {
                  Navigator.pop(context);
                  if (b.pageIndex != null) {
                    _goToContent(b.pageIndex!);
                  }
                },
                trailing: IconButton(
                  tooltip: _strings.delete,
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
              return Semantics(
                button: true,
                label: _strings.pageN(index + 1),
                child: GestureDetector(
                  excludeFromSemantics: true,
                  onTap: () {
                    Navigator.pop(context);
                    _goToContent(index);
                  },
                  child: _rasterWidget(index, thumbnail: true),
                ),
              );
            },
          ),
        );
      },
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final volume =
        _settings.volumeKeyPaging &&
        (key == LogicalKeyboardKey.audioVolumeUp ||
            key == LogicalKeyboardKey.audioVolumeDown);
    // Swallow key repeats of the volume keys too (no system volume change).
    if (event is KeyRepeatEvent && volume) return KeyEventResult.handled;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final rtl = widget.rtl && _mode == ComicReadingMode.horizontal;
    if ((volume && key == LogicalKeyboardKey.audioVolumeUp) ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown) {
      _goToPage(_currentPage + (rtl ? -1 : 1));
      return KeyEventResult.handled;
    }
    if ((volume && key == LogicalKeyboardKey.audioVolumeDown) ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      _goToPage(_currentPage + (rtl ? 1 : -1));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _goToContent(int raw) {
    if (!_window.readable(raw)) {
      _notifyTrialLimit(ReaderTrialLimitAction.seek, raw);
      return;
    }
    _goToPage(_logicalIndexForContent(raw));
  }

  Widget _rasterWidget(int index, {bool thumbnail = false}) => _PdfRasterImage(
    key: ValueKey((_rasterCache, index, thumbnail)),
    load: () => _rasterCache!.page(index, thumbnail ? 24 : widget.rasterDpi),
    thumbnail: thumbnail,
    fit: _fit,
  );

  Widget _buildPage(int logicalIndex) {
    final raw = _contentPageIndex(logicalIndex);
    if (_doublePageActive) {
      return Row(
        children: [
          Expanded(child: _rasterWidget(raw)),
          Expanded(
            child: _window.readable(raw + 1)
                ? _rasterWidget(raw + 1)
                : const SizedBox.expand(),
          ),
        ],
      );
    }
    return _rasterWidget(raw);
  }

  @override
  void didUpdateWidget(covariant PdfReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.stableId != widget.source.stableId ||
        oldWidget.bookId != widget.bookId ||
        oldWidget.rasterDpi != widget.rasterDpi) {
      final restore =
          oldWidget.source.stableId == widget.source.stableId &&
              oldWidget.bookId == widget.bookId
          ? _contentPageIndex(_currentPage)
          : null;
      _identity = null;
      _loading = true;
      _error = null;
      _sessionTimer?.cancel();
      _rasterCache?.dispose();
      _rasterCache = null;
      _previewing = false;
      _totalPages = 0;
      _mode = _normalizeMode(widget.readingMode);
      _bootstrap(restorePage: restore);
      return;
    }
    // Absolute page via the OLD window, then back through the new one.
    final content = ReaderPageWindow(
      _totalPages,
      trial: oldWidget.trialLimit,
      doublePage: _doublePageActive,
    ).content(_currentPage);
    if (oldWidget.settings != widget.settings) {
      _settings = widget.settings;
      _session.apply(_settings);
    }
    if (oldWidget.readingMode != widget.readingMode) {
      _mode = _normalizeMode(widget.readingMode);
    }
    _currentPage = _logicalIndexForContent(content);
    if (oldWidget.trialLimit != widget.trialLimit && _totalPages > 0) {
      final now = _contentPageIndex(_currentPage);
      if (now != content) widget.onPageChanged?.call(now);
    }
    if (oldWidget.settings != widget.settings ||
        oldWidget.readingMode != widget.readingMode ||
        oldWidget.trialLimit != widget.trialLimit) {
      _rebindPageController();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stats?.pause();
      _saveProgress();
    } else if (state == AppLifecycleState.resumed) {
      _stats?.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _saveProgress();
    _loadVersion++;
    _session.dispose();
    _rasterCache?.dispose();
    _pageController?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_loading || _pageController == null) {
      if (_previewing && _rasterCache != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Color(_settings.comicBackground)),
            _rasterWidget(0),
            const Positioned(
              right: 16,
              bottom: 16,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (_itemCount == 0) {
      return Center(child: Text(_strings.noReadableContent));
    }
    final controller = _pageController!;
    final progress = _itemCount == 0 ? 0.0 : (_currentPage + 1) / _itemCount;
    final content = (_totalPages == 0) ? 0 : _contentPageIndex(_currentPage);
    final bookmarked = _bookmarks.any((b) => b.pageIndex == content);

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ListenableBuilder(
        listenable: _brightness,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Color(_settings.comicBackground)),
              if ((_totalPages > 0))
                Semantics(
                  button: widget.showToolbar,
                  label: _strings.toggleToolbar,
                  onTap: widget.showToolbar
                      ? () => setState(() => _toolbarVisible = !_toolbarVisible)
                      : null,
                  child: GestureDetector(
                    excludeFromSemantics: true,
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (_) {
                      if (widget.showToolbar) {
                        setState(() => _toolbarVisible = !_toolbarVisible);
                      }
                    },
                    child: PageView.builder(
                      key: ValueKey(
                        '${_mode.name}-${_settings.doublePage}-'
                        '${widget.rtl}-$_pageViewCount',
                      ),
                      controller: controller,
                      physics: readerSwipePhysics(_settings.swipeSensitivity),
                      itemCount: _pageViewCount,
                      scrollDirection: _mode == ComicReadingMode.vertical
                          ? Axis.vertical
                          : Axis.horizontal,
                      reverse:
                          widget.rtl && _mode == ComicReadingMode.horizontal,
                      onPageChanged: (i) {
                        if (isTrialNextSentinel(
                          index: i,
                          readableCount: _itemCount,
                          hasMoreBeyond: _hasMoreBeyondTrial,
                        )) {
                          _onTrialNextSentinel();
                          return;
                        }
                        setState(() => _currentPage = i);
                        widget.onPageChanged?.call(_contentPageIndex(i));
                        _recordVisit();
                        _saveProgress();
                      },
                      itemBuilder: (context, index) {
                        if (isTrialNextSentinel(
                          index: index,
                          readableCount: _itemCount,
                          hasMoreBeyond: _hasMoreBeyondTrial,
                        )) {
                          return const SizedBox.expand();
                        }
                        return _buildPage(index);
                      },
                    ),
                  ),
                )
              else
                Center(child: Text(_strings.emptyDocument)),
              BrightnessOverlay(
                brightness: _brightness.value,
                mode: _brightness.mode,
              ),
              if (widget.watermarkText != null)
                ReaderWatermark(text: widget.watermarkText!),
              ReaderInk(
                key: ValueKey('$_bookId:$content'),
                bookId: _bookId,
                location: '$content',
                enabled: widget.enableInk,
                strings: _strings,
              ),
              if (!_toolbarVisible && (_totalPages > 0))
                ReaderProgressBar(
                  semanticsLabel: _strings.progress,
                  progress: progress,
                  onSeek: (v) => _goToPage((v * (_itemCount - 1)).round()),
                ),
              if (widget.showToolbar && _toolbarVisible)
                PageReaderToolbar(
                  strings: _strings,
                  allowWebtoon: false,
                  currentPage: content + 1,
                  totalPages: _totalPages,
                  progress: progress,
                  settings: _settings,
                  mode: _mode,
                  bookmarked: bookmarked,
                  onModeChanged: (mode) {
                    final c = _contentPageIndex(_currentPage);
                    setState(() {
                      _mode = _normalizeMode(mode);
                      if (_settings.doublePage &&
                          _mode == ComicReadingMode.vertical) {
                        _mode = ComicReadingMode.horizontal;
                      }
                      _currentPage = _logicalIndexForContent(c);
                    });
                    _rebindPageController();
                  },
                  onSettingsChanged: _emitSettings,
                  onToggleBookmark: _toggleBookmark,
                  onShowBookmarks: _showBookmarks,
                  onShowThumbs: _showThumbnails,
                  onSeek: (v) => _goToPage((v * (_itemCount - 1)).round()),
                  onPageInput: _goToContent,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PdfRasterImage extends StatefulWidget {
  const _PdfRasterImage({
    super.key,
    required this.load,
    required this.fit,
    this.thumbnail = false,
  });
  final Future<PdfRaster> Function() load;
  final BoxFit fit;
  final bool thumbnail;
  @override
  State<_PdfRasterImage> createState() => _PdfRasterImageState();
}

class _PdfRasterImageState extends State<_PdfRasterImage> {
  late final Future<PdfRaster> _future = widget.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<PdfRaster>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Icon(Icons.broken_image_outlined));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final image = Image(
        image: PdfRasterImage(snapshot.data!),
        fit: widget.thumbnail ? BoxFit.cover : widget.fit,
      );
      return ColoredBox(
        color: Colors.white,
        child: widget.thumbnail
            ? image
            : InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: SizedBox.expand(child: image),
              ),
      );
    },
  );
}
