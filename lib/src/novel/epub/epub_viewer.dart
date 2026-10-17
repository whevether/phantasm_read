import 'dart:convert';

import '../../common/reader_trial_limit.dart';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../common/novel_reading_mode.dart';
import '../../common/novel_typography.dart';
import '../novel_chapter.dart';
import 'epub_bridge.dart';

const _assetReaderHtml = 'packages/phantasm_read/assets/epubjs/reader.html';

/// Imperative API for EPUB navigation.
class EpubViewerController {
  _EpubViewerState? _state;

  Future<List<NovelChapter>> getChapters() async =>
      _state?.getChapters() ?? const [];

  Future<void> goToChapter(String href) async => _state?.goToChapter(href);

  Future<void> next() async => _state?.next();

  Future<void> prev() async => _state?.prev();

  Future<List<Map<String, String>>> search(String query) async =>
      _state?.search(query) ?? const [];

  Future<String?> currentCfi() async => _state?.currentCfi();
  Future<String> currentText() async => await _state?._bridge?.getText() ?? '';
}

/// EPUB viewer using offline epub.js inside [webview_flutter].
class EpubViewer extends StatefulWidget {
  const EpubViewer({
    super.key,
    required this.bytes,
    required this.typography,
    this.controller,
    this.initialCfi,
    this.readingMode = NovelReadingMode.horizontal,
    this.backgroundColor,
    this.foregroundColor,
    this.onLocationChanged,
    this.onChaptersLoaded,
    this.onReady,
    this.onError,
    this.onFontSizeChanged,
    this.trialLimit,
    this.onTrialBoundaryReached,
    this.onPositionChanged,
  });

  static bool get isSupported =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);

  final ReaderTrialLimit? trialLimit;
  final ValueChanged<bool>? onTrialBoundaryReached;
  final void Function(int chapterIndex, double percentage)? onPositionChanged;
  final Uint8List bytes;
  final NovelTypography typography;
  final EpubViewerController? controller;
  final String? initialCfi;
  final NovelReadingMode readingMode;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final ValueChanged<String?>? onLocationChanged;
  final ValueChanged<List<NovelChapter>>? onChaptersLoaded;
  final VoidCallback? onReady;
  final ValueChanged<String>? onError;
  final ValueChanged<double>? onFontSizeChanged;

  @override
  State<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<EpubViewer> {
  WebViewController? _controller;
  EpubBridge? _bridge;
  String? _error;
  bool _shellReady = false;
  bool _opening = false;
  int _generation = 0;
  bool _bookOpened = false;
  String? _cfi;

  String get _flow => widget.readingMode == NovelReadingMode.vertical
      ? 'scrolled'
      : 'paginated';

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _initWebView();
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
    _generation++;
    _controller
        ?.runJavaScript("window.epubBridge && window.epubBridge.close()")
        .catchError((Object _) {});
    _bridge?.dispose();
    super.dispose();
  }

  Future<List<NovelChapter>> getChapters() async {
    final bridge = _bridge;
    if (bridge == null || !_bookOpened) return const [];
    return bridge.getToc();
  }

  Future<void> goToChapter(String href) async => _bridge?.goToChapter(href);

  Future<void> next() async => _bridge?.next();

  Future<void> prev() async => _bridge?.prev();

  Future<List<Map<String, String>>> search(String query) async {
    final bridge = _bridge;
    if (bridge == null || !_bookOpened) return const [];
    return bridge.search(query);
  }

  Future<String?> currentCfi() async {
    final loc = await _bridge?.getLocation();
    return loc?['cfi'] as String? ?? _cfi;
  }

  void _fail(Object error) {
    if (!mounted) return;
    widget.onError?.call('$error');
    setState(() => _error = '$error');
  }

  Future<void> _initWebView() async {
    if (!EpubViewer.isSupported) {
      _fail(
        UnsupportedError(
          'EPUB is supported on Android, iOS and macOS. Use text/comic/PDF on this platform.',
        ),
      );
      return;
    }
    try {
      final controller = WebViewController();
      _controller = controller;
      _bridge = EpubBridge(controller);
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (!mounted) return;
      await controller.addJavaScriptChannel(
        'EpubChannel',
        onMessageReceived: (message) {
          if (!mounted) return;
          final msg = EpubBridgeMessage.parse(message.message);
          final payload = msg.payload;
          switch (msg.type) {
            case 'response':
              _bridge?.receive(payload);
            case 'shellReady':
              _shellReady = true;
              _openBookIfNeeded();
            case 'locationChanged':
              if (payload is Map && payload['cfi'] is String) {
                _cfi = payload['cfi'];
                final index = payload['chapterIndex'];
                final percentage = payload['percentage'];
                if (index is int && percentage is num) {
                  widget.onPositionChanged?.call(
                    index,
                    percentage.toDouble().clamp(0, 1),
                  );
                }
                widget.onLocationChanged?.call(_cfi);
              }
            case 'trialBoundary':
              if (payload is Map) {
                widget.onTrialBoundaryReached?.call(payload['next'] == true);
              }
            case 'fontSizeChanged':
              if (payload is Map && payload['percent'] is num) {
                widget.onFontSizeChanged?.call(
                  ((payload['percent'] as num) / 100 * 18)
                      .clamp(12, 36)
                      .toDouble(),
                );
              }
            case 'error':
              _fail(
                payload is Map
                    ? payload['message'] ?? 'EPUB error'
                    : 'EPUB error',
              );
          }
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            final shell =
                uri.path.endsWith('/assets/epubjs/reader.html') &&
                (uri.scheme == 'file' ||
                    uri.host == 'localhost' ||
                    uri.host == '127.0.0.1');
            if (shell ||
                (!request.isMainFrame &&
                    (uri.scheme == 'blob' || request.url == 'about:blank'))) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) _fail(error.description);
          },
        ),
      );
      if (!mounted) return;
      await controller.loadFlutterAsset(_assetReaderHtml);
      if (mounted) setState(() {});
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _openBookIfNeeded() async {
    if (!mounted ||
        !_shellReady ||
        _bookOpened ||
        _opening ||
        _bridge == null) {
      return;
    }
    final generation = _generation;
    final bridge = _bridge!;
    _opening = true;
    try {
      final limit = widget.trialLimit;
      await bridge.openFromBase64(
        base64Encode(widget.bytes),
        flow: _flow,
        trialStart: limit?.isActive == true ? limit!.startIndex : null,
        trialCount: limit?.isActive == true ? limit!.maxCount : null,
        initialCfi: widget.initialCfi,
      );
      if (!mounted || generation != _generation) return;
      _bookOpened = true;
      await _applyTypography();
      final chapters = await bridge.getToc();
      if (!mounted || generation != _generation) return;
      widget.onChaptersLoaded?.call(chapters);
      widget.onReady?.call();
    } catch (e) {
      if (generation == _generation) _fail(e);
    } finally {
      _opening = false;
      if (mounted && generation != _generation) _openBookIfNeeded();
    }
  }

  Future<void> _applyTypography() async {
    final bridge = _bridge;
    if (bridge == null || !_bookOpened) return;
    try {
      final t = widget.typography;
      await bridge.setFontSize(t.fontSize);
      await bridge.setLineHeight(t.lineHeight);
      await bridge.setFontFamily(t.fontFamily);
      await bridge.setTypography(
        letterSpacing: t.letterSpacing,
        margin: t.pageMargin,
        textAlign: t.textAlign.name,
      );
      await bridge.setTheme(
        background: _cssColor(
          widget.backgroundColor ?? const Color(0xFFFFFFFF),
        ),
        foreground: _cssColor(
          widget.foregroundColor ?? const Color(0xFF000000),
        ),
      );
    } catch (e) {
      if (mounted) _fail(e);
    }
  }

  String _cssColor(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    final a = c.a;
    if (a >= 1) return 'rgb($r,$g,$b)';
    return 'rgba($r,$g,$b,${a.toStringAsFixed(3)})';
  }

  @override
  void didUpdateWidget(covariant EpubViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
    if (oldWidget.typography != widget.typography ||
        oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.foregroundColor != widget.foregroundColor) {
      _applyTypography();
    }
    if (oldWidget.readingMode != widget.readingMode && _bookOpened) {
      _bridge?.setFlow(_flow).then((_) => _applyTypography()).catchError(_fail);
    }
    if (oldWidget.bytes != widget.bytes ||
        oldWidget.trialLimit != widget.trialLimit) {
      _generation++;
      _error = null;
      _bookOpened = false;
      _openBookIfNeeded();
    }
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
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return WebViewWidget(controller: controller);
  }
}
