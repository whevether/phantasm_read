import 'dart:convert';

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
  });

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
  bool _bookOpened = false;
  String? _cfi;

  String get _flow =>
      widget.readingMode == NovelReadingMode.vertical ? 'scrolled' : 'paginated';

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

  Future<void> _initWebView() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'EpubChannel',
        onMessageReceived: (message) {
          final msg = EpubBridgeMessage.parse(message.message);
          switch (msg.type) {
            case 'shellReady':
              _shellReady = true;
              _openBookIfNeeded();
            case 'ready':
              _bookOpened = true;
              _applyTypography();
              if (widget.initialCfi != null) {
                _bridge?.display(widget.initialCfi);
              }
              _loadChapters();
              widget.onReady?.call();
            case 'locationChanged':
              final payload = msg.payload;
              String? cfi;
              if (payload is Map) {
                cfi = payload['cfi'] as String?;
              }
              _cfi = cfi;
              widget.onLocationChanged?.call(cfi);
            case 'fontSizeChanged':
              final payload = msg.payload;
              if (payload is Map) {
                final percent = payload['percent'];
                if (percent is num) {
                  final px = (percent / 100.0) * 18.0;
                  widget.onFontSizeChanged?.call(px.clamp(12.0, 36.0));
                }
              }
            case 'error':
              final payload = msg.payload;
              final text = payload is Map
                  ? (payload['message']?.toString() ?? 'Unknown error')
                  : payload?.toString() ?? 'Unknown error';
              widget.onError?.call(text);
              if (mounted) setState(() => _error = text);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _shellReady = true;
            _openBookIfNeeded();
          },
          onWebResourceError: (error) {
            widget.onError?.call(error.description);
            if (mounted) setState(() => _error = error.description);
          },
        ),
      );

    _controller = controller;
    _bridge = EpubBridge(controller);

    try {
      await controller.loadFlutterAsset(_assetReaderHtml);
    } catch (_) {
      try {
        await controller.loadFlutterAsset('assets/epubjs/reader.html');
      } catch (e2) {
        // Web fallback: load HTML string with relative script tags may fail;
        // surface clear error.
        if (mounted) {
          setState(() {
            _error = kIsWeb
                ? 'EPUB on web requires asset loading support: $e2'
                : 'Failed to load EPUB shell: $e2';
          });
        }
        return;
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _openBookIfNeeded() async {
    if (!_shellReady || _bookOpened || _bridge == null) return;
    try {
      final b64 = base64Encode(widget.bytes);
      await _bridge!.openFromBase64(b64, flow: _flow);
    } catch (e) {
      widget.onError?.call(e.toString());
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadChapters() async {
    try {
      widget.onChaptersLoaded?.call(await getChapters());
    } catch (_) {
      widget.onChaptersLoaded?.call(const []);
    }
  }

  Future<void> _applyTypography() async {
    final bridge = _bridge;
    if (bridge == null) return;
    final t = widget.typography;
    await bridge.setFontSize(t.fontSize);
    await bridge.setLineHeight(t.lineHeight);
    await bridge.setFontFamily(t.fontFamily);
    final bg = widget.backgroundColor ?? const Color(0xFFFFFFFF);
    final fg = widget.foregroundColor ?? const Color(0xFF000000);
    await bridge.setTheme(
      background: _cssColor(bg),
      foreground: _cssColor(fg),
    );
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
      _bridge?.setFlow(_flow).then((_) => _applyTypography());
    }
    if (oldWidget.bytes != widget.bytes) {
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
