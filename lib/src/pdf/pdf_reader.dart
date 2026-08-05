import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../common/reader_brightness.dart';
import '../common/reader_lifecycle.dart';
import '../common/reader_progress.dart';
import '../common/reader_settings.dart';
import '../common/reader_trial_limit.dart';
import '../common/reader_wake_lock.dart';
import '../common/reader_watermark.dart';
import '../common/tap_zones.dart';
import '../novel/file_bytes.dart';

/// PDF document source.
sealed class PdfSource {
  const PdfSource();
  factory PdfSource.file(String path) = PdfSourceFile;
  factory PdfSource.bytes(Uint8List bytes, {String name = 'doc.pdf'}) {
    return PdfSourceBytes(bytes, name: name);
  }
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

/// PDF reader using `pdf` 3.13.0 + `printing` raster (pdfium on desktop/mobile).
///
/// Renders each page to a bitmap via [Printing.raster], works on Linux / Windows /
/// Android / iOS / macOS and web (when pdf.js is configured).
class PdfReader extends StatefulWidget {
  const PdfReader({
    super.key,
    required this.source,
    this.bookId,
    this.settings = const ReaderSettings(),
    this.initialPage = 0,
    this.trialLimit,
    this.onTrialLimitReached,
    this.watermarkText,
    this.persistProgress = true,
    this.onPageChanged,
    this.showToolbar = true,
    this.rasterDpi = 120,
  });

  final PdfSource source;
  final String? bookId;
  final ReaderSettings settings;
  final int initialPage;
  final ReaderTrialLimit? trialLimit;
  final ReaderTrialLimitCallback? onTrialLimitReached;
  final String? watermarkText;
  final bool persistProgress;
  final ValueChanged<int>? onPageChanged;
  final bool showToolbar;
  final double rasterDpi;

  @override
  State<PdfReader> createState() => _PdfReaderState();
}

class _PdfReaderState extends State<PdfReader> with WidgetsBindingObserver {
  late final ReaderBrightness _brightness = ReaderBrightness();
  late ReaderSettings _settings;
  late final PageController _pageController;

  Uint8List? _bytes;
  final List<PdfRaster> _pages = [];
  int _currentPage = 0;
  bool _toolbar = false;
  bool _loading = true;
  bool _rasterizing = false;
  String? _error;

  String get _bookId => widget.bookId ?? 'pdf_${widget.source.hashCode}';

  int get _itemCount {
    final total = _pages.length;
    if (total == 0) return 1;
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive) return total;
    return limit.visibleCount(total);
  }

  int _contentPageIndex(int logicalIndex) {
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive) return logicalIndex;
    return limit.contentIndex(logicalIndex);
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

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _brightness.apply(_settings.brightness);
    if (_settings.keepScreenOn) await ReaderWakeLock.enable();
    if (widget.persistProgress) {
      final p = await ReaderProgressStore.instance.load(_bookId);
      if (p != null) {
        _currentPage = p.pageIndex;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        }
      }
    }

    try {
      final info = await Printing.info();
      if (!info.canRaster) {
        throw UnsupportedError(
          'PDF raster is not available on this platform. '
          'On web, configure pdf.js for the printing package.',
        );
      }

      _bytes = switch (widget.source) {
        PdfSourceFile(:final path) => await readFileBytes(path),
        PdfSourceBytes(:final bytes) => bytes,
      };
      await _rasterDocument();
    } catch (e) {
      _error = e.toString();
    }

    if (mounted && _error == null && _pages.isEmpty) {
      _error =
          'PDF has no readable pages. On Android, use PDF 1.7+ without encryption.';
    }

    if (mounted) {
      setState(() => _loading = false);
      widget.onPageChanged?.call(_currentPage);
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
      if (_currentPage >= _pages.length && _pages.isNotEmpty) {
        _currentPage = _pages.length - 1;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        }
      }
    } catch (e) {
      if (mounted) _error = e.toString();
    } finally {
      _rasterizing = false;
    }
  }

  Future<void> _leave() async {
    await _brightness.restore();
    await ReaderWakeLock.disable();
  }

  Future<void> _save() async {
    if (!widget.persistProgress || _pages.isEmpty) return;
    final pct = (_currentPage + 1) / _pages.length;
    await ReaderProgressStore.instance.save(
      ReaderProgress(
        bookId: _bookId,
        pageIndex: _currentPage,
        percentage: pct,
      ),
    );
  }

  void _goToPage(int page) {
    if (_pages.isEmpty) return;
    final limit = widget.trialLimit;
    final total = _pages.length;
    var next = page;
    if (limit != null && limit.isActive) {
      final contentTarget = _contentPageIndex(page.clamp(0, _itemCount - 1));
      if (page < 0 ||
          page >= _itemCount ||
          !limit.isReadable(contentTarget, total)) {
        _notifyTrialLimit(
          ReaderTrialLimitAction.seek,
          page < 0 ? 0 : contentTarget + 1,
        );
        next = limit.logicalIndex(limit.clampIndex(contentTarget, total));
      }
    } else {
      next = page.clamp(0, total - 1);
    }
    if (next == _currentPage) return;
    setState(() => _currentPage = next);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    widget.onPageChanged?.call(_contentPageIndex(next));
    _save();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.audioVolumeUp) {
      _goToPage(_currentPage - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.audioVolumeDown) {
      _goToPage(_currentPage + 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _save();
    _leave();
    _pageController.dispose();
    _brightness.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ReaderWakeLock.disable();
      _save();
    } else if (state == AppLifecycleState.resumed && _settings.keepScreenOn) {
      ReaderWakeLock.enable();
    }
  }

  Widget _buildPage(int logicalIndex) {
    final index = _contentPageIndex(logicalIndex);
    if (index >= _pages.length) {
      return const Center(child: CircularProgressIndicator());
    }
    return _PdfRasterPage(raster: _pages[index]);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    if (_loading && _pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

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
                PageView.builder(
                  controller: _pageController,
                  itemCount: _itemCount,
                  onPageChanged: (i) {
                    setState(() => _currentPage = i);
                    widget.onPageChanged?.call(_contentPageIndex(i));
                    _save();
                  },
                  itemBuilder: (context, index) => _buildPage(index),
                )
              else
                const Center(child: Text('Empty PDF')),
              BrightnessOverlay(
                brightness: _brightness.value,
                mode: _brightness.mode,
              ),
              if (widget.watermarkText != null)
                ReaderWatermark(text: widget.watermarkText!),
              if (_settings.tapZonesEnabled)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (d) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box == null) return;
                      final action = TapZoneDetector(enabled: true).resolve(
                        d.localPosition,
                        box.size,
                      );
                      switch (action) {
                        case TapZoneAction.previous:
                          _goToPage(_currentPage - 1);
                        case TapZoneAction.toggleToolbar:
                          setState(() => _toolbar = !_toolbar);
                        case TapZoneAction.next:
                          final limit = widget.trialLimit;
                          final content = _contentPageIndex(_currentPage);
                          if (limit != null &&
                              limit.atBoundary(content, _pages.length)) {
                            _notifyTrialLimit(
                              ReaderTrialLimitAction.next,
                              content + 1,
                            );
                            return;
                          }
                          _goToPage(_currentPage + 1);
                      }
                    },
                  ),
                ),
              if (widget.showToolbar)
                Positioned(
                  right: 12,
                  bottom: 24,
                  child: FloatingActionButton.small(
                    onPressed: () => setState(() => _toolbar = !_toolbar),
                    child: Icon(_toolbar ? Icons.close : Icons.menu),
                  ),
                ),
              if (_toolbar)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: Colors.black54,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _pages.isEmpty
                              ? 'PDF · loading…'
                              : 'PDF · page ${_contentPageIndex(_currentPage) + 1} / ${_pages.length}',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!_toolbar && _pages.isNotEmpty)
                ReaderProgressBar(
                  progress: _pages.isEmpty
                      ? 0
                      : ((_currentPage + 1) / _pages.length).clamp(0.0, 1.0),
                  onSeek: (v) {
                    final target = (v * (_pages.length - 1)).round();
                    _goToPage(target);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PdfRasterPage extends StatefulWidget {
  const _PdfRasterPage({required this.raster});

  final PdfRaster raster;

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
      child: Center(
        child: ColoredBox(
          color: Colors.white,
          child: RawImage(
            image: image,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
