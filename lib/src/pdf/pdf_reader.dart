import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../common/reader_brightness.dart';
import '../common/reader_lifecycle.dart';
import '../common/reader_progress.dart';
import '../common/reader_settings.dart';
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
    this.maxReadablePages,
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
  final int? maxReadablePages;
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
    final trial = widget.maxReadablePages;
    if (trial == null || trial <= 0) return total;
    return total < trial ? total : trial;
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
        _pageController.jumpToPage(_currentPage);
      }
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
    final trial = widget.maxReadablePages;
    final max = trial == null ? _pages.length - 1 : (trial - 1).clamp(0, _pages.length - 1);
    final next = page.clamp(0, max);
    if (next == _currentPage) return;
    setState(() => _currentPage = next);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    widget.onPageChanged?.call(next);
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

  Widget _buildPage(int index) {
    if (index >= _pages.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final raster = _pages[index];
    return FutureBuilder(
      future: raster.toImage(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Center(
            child: RawImage(
              image: snapshot.data,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    if (_loading && _pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final trial = widget.maxReadablePages;
    final trialEnded = trial != null && _currentPage >= trial;

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
                    widget.onPageChanged?.call(i);
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
              if (trialEnded)
                const ColoredBox(
                  color: Color(0xCC000000),
                  child: Center(
                    child: Text(
                      '试读结束',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
              if (_settings.tapZonesEnabled && !trialEnded)
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
                              : 'PDF · page ${_currentPage + 1} / ${_pages.length}'
                                  '${trial != null ? ' · 试读 $trial 页' : ''}',
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
