import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../common/reader_brightness.dart';
import '../common/reader_lifecycle.dart';
import '../common/reader_settings.dart';
import '../common/reader_wake_lock.dart';
import 'comic_pages.dart';
import 'comic_reading_mode.dart';

/// Image comic reader powered by `extended_image` 10.1.0.
class ComicReader extends StatefulWidget {
  const ComicReader({
    super.key,
    required this.pages,
    this.readingMode = ComicReadingMode.vertical,
    this.settings = const ReaderSettings(),
    this.rtl = false,
    this.initialPage = 0,
    this.onPageChanged,
    this.onSettingsChanged,
    this.showToolbar = true,
  });

  final ComicPages pages;
  final ComicReadingMode readingMode;
  final ReaderSettings settings;
  final bool rtl;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<ReaderSettings>? onSettingsChanged;
  final bool showToolbar;

  @override
  State<ComicReader> createState() => _ComicReaderState();
}

class _ComicReaderState extends State<ComicReader>
    with WidgetsBindingObserver {
  late final ReaderBrightness _brightness = ReaderBrightness();
  late ReaderSettings _settings;
  late ComicReadingMode _mode;
  late final ExtendedPageController _pageController;
  bool _toolbarVisible = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _mode = widget.readingMode;
    _currentPage = widget.initialPage;
    _pageController = ExtendedPageController(initialPage: widget.initialPage);
    WidgetsBinding.instance.addObserver(this);
    _enterReading();
  }

  Future<void> _enterReading() async {
    await _brightness.apply(_settings.brightness);
    if (_settings.keepScreenOn) {
      await ReaderWakeLock.enable();
    }
  }

  Future<void> _leaveReading() async {
    await _brightness.restore();
    await ReaderWakeLock.disable();
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
    } else if (state == AppLifecycleState.resumed && _settings.keepScreenOn) {
      ReaderWakeLock.enable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _leaveReading();
    _pageController.dispose();
    _brightness.dispose();
    super.dispose();
  }

  ImageProvider _providerAt(int index) => widget.pages.imageProviderAt(index);

  Future<void> _precacheNeighbors(int index) async {
    final targets = <int>{
      if (index - 1 >= 0) index - 1,
      if (index + 1 < widget.pages.length) index + 1,
    };
    for (final i in targets) {
      await precacheImage(_providerAt(i), context);
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
    widget.onSettingsChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _brightness,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!widget.showToolbar) return;
                setState(() => _toolbarVisible = !_toolbarVisible);
              },
              child: ExtendedImageGesturePageView.builder(
                itemCount: widget.pages.length,
                controller: _pageController,
                scrollDirection: _mode == ComicReadingMode.vertical
                    ? Axis.vertical
                    : Axis.horizontal,
                reverse: widget.rtl && _mode == ComicReadingMode.horizontal,
                onPageChanged: (index) {
                  _currentPage = index;
                  widget.onPageChanged?.call(index);
                  _precacheNeighbors(index);
                  if (mounted) setState(() {});
                },
                itemBuilder: (context, index) {
                  return ExtendedImage(
                    image: _providerAt(index),
                    mode: ExtendedImageMode.gesture,
                    fit: BoxFit.contain,
                    initGestureConfigHandler: (state) => GestureConfig(
                      minScale: 1.0,
                      maxScale: 4.0,
                      animationMinScale: 0.8,
                      animationMaxScale: 4.5,
                      inPageView: true,
                    ),
                    loadStateChanged: (state) {
                      switch (state.extendedImageLoadState) {
                        case LoadState.loading:
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                },
              ),
            ),
            BrightnessOverlay(
              brightness: _brightness.value,
              mode: _brightness.mode,
            ),
            if (widget.showToolbar && _toolbarVisible)
              _ComicToolbar(
                pageLabel: '${_currentPage + 1} / ${widget.pages.length}',
                settings: _settings,
                mode: _mode,
                onModeChanged: (mode) => setState(() => _mode = mode),
                onSettingsChanged: _emitSettings,
              ),
          ],
        );
      },
    );
  }
}

class _ComicToolbar extends StatelessWidget {
  const _ComicToolbar({
    required this.pageLabel,
    required this.settings,
    required this.mode,
    required this.onModeChanged,
    required this.onSettingsChanged,
  });

  final String pageLabel;
  final ReaderSettings settings;
  final ComicReadingMode mode;
  final ValueChanged<ComicReadingMode> onModeChanged;
  final ValueChanged<ReaderSettings> onSettingsChanged;

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
                      tooltip: 'Reading mode',
                      onPressed: () {
                        onModeChanged(
                          mode == ComicReadingMode.vertical
                              ? ComicReadingMode.horizontal
                              : ComicReadingMode.vertical,
                        );
                      },
                      icon: Icon(
                        mode == ComicReadingMode.vertical
                            ? Icons.swap_vert
                            : Icons.swap_horiz,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Keep screen on',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
