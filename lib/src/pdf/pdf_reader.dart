import 'dart:async';
import 'dart:ui' as ui;

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
import '../common/reader_trial_limit.dart';
import '../common/reader_wake_lock.dart';
import '../common/reader_watermark.dart';
import '../common/tap_zones.dart';
import '../common/trial_gesture_boundary.dart';
import '../novel/file_bytes.dart';

/// PDF document source.
sealed class PdfSource {
  const PdfSource();
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

/// PDF reader using `pdf` 3.13.0 + `printing` raster (pdfium on desktop/mobile).
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
  PageController? _pageController;

  Uint8List? _bytes;
  final List<PdfRaster> _pages = [];
  int _currentPage = 0;
  bool _toolbarVisible = false;
  bool _loading = true;
  bool _rasterizing = false;
  String? _error;
  List<ReaderBookmark> _bookmarks = const [];
  DateTime? _sessionStarted;
  Timer? _sessionTimer;
  final TrialGestureNotifier _trialGesture = TrialGestureNotifier();

  String get _bookId => widget.bookId ?? 'pdf_${widget.source.hashCode}';

  bool get _doublePageActive =>
      _settings.doublePage &&
      _mode == ComicReadingMode.horizontal &&
      _pages.length > 1;

  int _readableRawCount() {
    final total = _pages.length;
    if (total == 0) return 0;
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive) return total;
    return limit.visibleCount(total);
  }

  int get _itemCount {
    final visibleRaw = _readableRawCount();
    if (visibleRaw <= 0) return 0;
    if (_doublePageActive) {
      return ((visibleRaw + 1) ~/ 2).clamp(1, visibleRaw);
    }
    return visibleRaw;
  }

  bool get _hasMoreBeyondTrial {
    final limit = widget.trialLimit;
    return limit != null &&
        limit.isActive &&
        _pages.isNotEmpty &&
        limit.hasMoreBeyond(_pages.length);
  }

  int get _pageViewCount =>
      trialPageViewCount(_itemCount, _hasMoreBeyondTrial);

  int _contentPageIndex(int logicalIndex) {
    final start = widget.trialLimit?.startIndex ?? 0;
    if (_doublePageActive) {
      return (start + logicalIndex * 2).clamp(0, _pages.length - 1);
    }
    return (start + logicalIndex).clamp(0, (_pages.length - 1).clamp(0, 1 << 30));
  }

  int _logicalIndexForContent(int contentIndex) {
    final start = widget.trialLimit?.startIndex ?? 0;
    final count = _itemCount;
    if (count <= 0) return 0;
    if (_doublePageActive) {
      return ((contentIndex - start) ~/ 2).clamp(0, count - 1);
    }
    return (contentIndex - start).clamp(0, count - 1);
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

  void _notifyTrialLimit(ReaderTrialLimitAction action, int targetIndex) {
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive) return;
    widget.onTrialLimitReached?.call(
      ReaderTrialLimitEvent(
        limit: limit,
        currentIndex: _contentPageIndex(_currentPage),
        targetIndex: targetIndex,
        totalCount: _pages.length,
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
      totalCount: _pages.length,
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

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _mode = widget.readingMode;
    if (_settings.doublePage && _mode == ComicReadingMode.vertical) {
      _mode = ComicReadingMode.horizontal;
    }
    _currentPage = widget.initialPage;
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      if (widget.persistSettings) {
        final saved = await ReaderSettingsStore.instance.load();
        if (saved != null) _settings = saved;
      }
      if (widget.persistProgress) {
        final p = await ReaderProgressStore.instance.load(_bookId);
        if (p != null) {
          _currentPage = _logicalIndexForContent(p.pageIndex);
        }
      }
      _bookmarks = await ReaderBookmarkStore.instance.listBookmarks(_bookId);

      final info = await Printing.info();
      if (!info.canRaster) {
        throw UnsupportedError(
          'PDF raster is not available on this platform. '
          'On web, configure pdf.js for the printing package.',
        );
      }

      _bytes = await _loadBytes();
      await _rasterDocument();
    } catch (e) {
      _error = e.toString();
    }

    if (mounted && _error == null && _pages.isEmpty) {
      _error =
          'PDF has no readable pages. On Android, use PDF 1.7+ without encryption.';
    }

    _currentPage = _currentPage.clamp(0, (_itemCount - 1).clamp(0, 1 << 30));
    _pageController = PageController(initialPage: _currentPage);
    if (_settings.immersive) await ReaderImmersive.enter();
    await _enterReading();
    _sessionStarted = DateTime.now();
    _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final started = _sessionStarted;
      if (started != null) {
        widget.onSessionTick?.call(DateTime.now().difference(started));
      }
    });

    if (mounted) {
      setState(() => _loading = false);
      if (_pages.isNotEmpty) {
        widget.onPageChanged?.call(_contentPageIndex(_currentPage));
      }
    }
  }

  Future<Uint8List> _loadBytes() async {
    switch (widget.source) {
      case PdfSourceFile(:final path):
        return readFileBytes(path);
      case PdfSourceBytes(:final bytes):
        return bytes;
      case PdfSourceUrl(:final url):
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode} loading $url');
        }
        if (response.bodyBytes.isEmpty) {
          throw Exception('Empty PDF response from $url');
        }
        return response.bodyBytes;
    }
  }

  Future<void> _rasterDocument() async {
    final bytes = _bytes;
    if (bytes == null || _rasterizing) return;
    _rasterizing = true;
    try {
      await for (final page in Printing.raster(bytes, dpi: widget.rasterDpi)) {
        if (!mounted) return;
        setState(() => _pages.add(page));
      }
    } catch (e) {
      if (mounted) _error = e.toString();
    } finally {
      _rasterizing = false;
    }
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
    if (!widget.persistProgress || _pages.isEmpty) return;
    final content = _contentPageIndex(_currentPage);
    final progress = ReaderProgress(
      bookId: _bookId,
      pageIndex: content,
      percentage: (content + 1) / _pages.length,
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
    final brightnessChanged = next.brightness != _settings.brightness;
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
    if (brightnessChanged) {
      _brightness.apply(next.brightness);
    }
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
    if (_pages.isEmpty || _itemCount <= 0) return;
    final limit = widget.trialLimit;
    final total = _pages.length;
    var target = logicalPage;
    if (limit != null && limit.isActive) {
      final contentTarget = _contentPageIndex(
        logicalPage.clamp(0, _itemCount - 1),
      );
      if (logicalPage < 0 ||
          logicalPage >= _itemCount ||
          !limit.isReadable(contentTarget, total)) {
        _notifyTrialLimit(
          ReaderTrialLimitAction.seek,
          logicalPage < 0 ? 0 : _contentPageIndex(_itemCount - 1) + 1,
        );
        target = _logicalIndexForContent(
          limit.clampIndex(contentTarget, total),
        );
      }
    } else {
      target = logicalPage.clamp(0, _itemCount - 1);
    }
    setState(() => _currentPage = target);
    final c = _pageController;
    if (c != null && c.hasClients) {
      c.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
    widget.onPageChanged?.call(_contentPageIndex(target));
    _saveProgress();
  }

  Future<void> _toggleBookmark() async {
    final content = _contentPageIndex(_currentPage);
    final existing = _bookmarks.where((b) => b.pageIndex == content);
    if (existing.isNotEmpty) {
      await ReaderBookmarkStore.instance
          .removeBookmark(_bookId, existing.first.id);
    } else {
      await ReaderBookmarkStore.instance.addBookmark(
        ReaderBookmark(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          bookId: _bookId,
          title: 'Page ${content + 1}',
          pageIndex: content,
        ),
      );
    }
    _bookmarks = await ReaderBookmarkStore.instance.listBookmarks(_bookId);
    await _saveProgress();
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
                  if (b.pageIndex != null) {
                    _goToPage(_logicalIndexForContent(b.pageIndex!));
                  }
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ReaderBookmarkStore.instance
                        .removeBookmark(_bookId, b.id);
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
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _goToPage(_logicalIndexForContent(index));
                },
                child: _PdfRasterThumb(raster: _pages[index]),
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
    final rtl = widget.rtl && _mode == ComicReadingMode.horizontal;
    if (key == LogicalKeyboardKey.audioVolumeUp ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown) {
      _goToPage(_currentPage + (rtl ? -1 : 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.audioVolumeDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      _goToPage(_currentPage + (rtl ? 1 : -1));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildPage(int logicalIndex) {
    final raw = _contentPageIndex(logicalIndex);
    if (_doublePageActive && raw + 1 < _pages.length) {
      final limit = widget.trialLimit;
      final secondOk = limit == null ||
          !limit.isActive ||
          limit.isReadable(raw + 1, _pages.length);
      return Row(
        children: [
          Expanded(child: _PdfRasterPage(raster: _pages[raw], fit: _fit)),
          if (secondOk)
            Expanded(child: _PdfRasterPage(raster: _pages[raw + 1], fit: _fit))
          else
            const Expanded(child: SizedBox.expand()),
        ],
      );
    }
    if (raw >= _pages.length) {
      return const Center(child: CircularProgressIndicator());
    }
    return _PdfRasterPage(raster: _pages[raw], fit: _fit);
  }

  @override
  void didUpdateWidget(covariant PdfReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      final wasDouble = _doublePageActive;
      final content = _contentPageIndex(_currentPage);
      final immersiveChanged =
          oldWidget.settings.immersive != widget.settings.immersive;
      setState(() {
        _settings = widget.settings;
        if (_settings.doublePage && _mode == ComicReadingMode.vertical) {
          _mode = ComicReadingMode.horizontal;
        }
        _currentPage = _logicalIndexForContent(content);
      });
      _brightness.apply(_settings.brightness);
      if (_settings.keepScreenOn) {
        ReaderWakeLock.enable();
      } else {
        ReaderWakeLock.disable();
      }
      if (immersiveChanged || _settings.immersive) {
        if (_settings.immersive) {
          ReaderImmersive.enter();
        } else {
          ReaderImmersive.leave();
        }
      }
      if (wasDouble != _doublePageActive) {
        _rebindPageController();
      }
    }
    if (oldWidget.readingMode != widget.readingMode) {
      final content = _contentPageIndex(_currentPage);
      setState(() {
        _mode = widget.readingMode;
        if (_settings.doublePage && _mode == ComicReadingMode.vertical) {
          _mode = ComicReadingMode.horizontal;
        }
        _currentPage = _logicalIndexForContent(content);
      });
      _rebindPageController();
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

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    if (_loading || _pageController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final controller = _pageController!;
    final progress = _itemCount == 0 ? 0.0 : (_currentPage + 1) / _itemCount;
    final content = _pages.isEmpty ? 0 : _contentPageIndex(_currentPage);
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
              if (_pages.isNotEmpty)
                GestureDetector(
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
                )
              else
                const Center(child: Text('Empty PDF')),
              BrightnessOverlay(
                brightness: _brightness.value,
                mode: _brightness.mode,
              ),
              if (widget.watermarkText != null)
                ReaderWatermark(text: widget.watermarkText!),
              InkAnnotationLayer(enabled: widget.enableInk),
              if (!_toolbarVisible && _pages.isNotEmpty)
                ReaderProgressBar(
                  progress: progress,
                  onSeek: (v) =>
                      _goToPage((v * (_itemCount - 1)).round()),
                ),
              if (widget.showToolbar && _toolbarVisible)
                _PdfToolbar(
                  pageLabel: _pages.isEmpty
                      ? 'PDF · loading…'
                      : 'PDF · ${content + 1} / ${_pages.length}',
                  progress: progress,
                  settings: _settings,
                  mode: _mode,
                  bookmarked: bookmarked,
                  onModeChanged: (mode) {
                    final c = _contentPageIndex(_currentPage);
                    setState(() {
                      _mode = mode;
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
                  onSeek: (v) =>
                      _goToPage((v * (_itemCount - 1)).round()),
                  onPageInput: (contentZeroBased) {
                    _goToPage(_logicalIndexForContent(contentZeroBased));
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PdfToolbar extends StatelessWidget {
  const _PdfToolbar({
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
                          text: pageLabel
                              .replaceFirst('PDF · ', '')
                              .split(' / ')
                              .first,
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

class _PdfRasterPage extends StatefulWidget {
  const _PdfRasterPage({required this.raster, this.fit = BoxFit.contain});

  final PdfRaster raster;
  final BoxFit fit;

  @override
  State<_PdfRasterPage> createState() => _PdfRasterPageState();
}

class _PdfRasterPageState extends State<_PdfRasterPage> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant _PdfRasterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.raster != widget.raster) {
      _image?.dispose();
      _image = null;
      _decode();
    }
  }

  Future<void> _decode() async {
    final image = await widget.raster.toImage();
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() => _image = image);
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4,
      child: SizedBox.expand(
        child: ColoredBox(
          color: Colors.white,
          child: FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: image.width.toDouble(),
              height: image.height.toDouble(),
              child: RawImage(image: image),
            ),
          ),
        ),
      ),
    );
  }
}

class _PdfRasterThumb extends StatefulWidget {
  const _PdfRasterThumb({required this.raster});

  final PdfRaster raster;

  @override
  State<_PdfRasterThumb> createState() => _PdfRasterThumbState();
}

class _PdfRasterThumbState extends State<_PdfRasterThumb> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant _PdfRasterThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.raster != widget.raster) {
      _image?.dispose();
      _image = null;
      _decode();
    }
  }

  Future<void> _decode() async {
    final image = await widget.raster.toImage();
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() => _image = image);
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return const ColoredBox(
        color: Colors.black12,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return ColoredBox(
      color: Colors.white,
      child: RawImage(image: image, fit: BoxFit.cover),
    );
  }
}
