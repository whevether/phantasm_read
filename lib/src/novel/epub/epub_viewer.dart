import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../common/novel_typography.dart';
import '../file_bytes.dart';
import 'epub_bridge.dart';

const _assetReaderHtml = 'packages/phantasm_read/assets/epubjs/reader.html';

/// EPUB viewer using offline epub.js inside [webview_flutter].
class EpubViewer extends StatefulWidget {
  const EpubViewer({
    super.key,
    required this.filePath,
    required this.typography,
    this.initialCfi,
    this.backgroundColor,
    this.foregroundColor,
    this.onLocationChanged,
    this.onReady,
    this.onError,
  });

  final String filePath;
  final NovelTypography typography;
  final String? initialCfi;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final ValueChanged<String?>? onLocationChanged;
  final VoidCallback? onReady;
  final ValueChanged<String>? onError;

  @override
  State<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<EpubViewer> {
  WebViewController? _controller;
  EpubBridge? _bridge;
  String? _error;
  bool _shellReady = false;
  bool _bookOpened = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _error =
          'EPUB WebView path is not used on web; use the web JS interop shell.';
      return;
    }
    _initWebView();
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
              widget.onReady?.call();
            case 'locationChanged':
              final payload = msg.payload;
              String? cfi;
              if (payload is Map) {
                cfi = payload['cfi'] as String?;
              }
              widget.onLocationChanged?.call(cfi);
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
    } catch (e) {
      // Fallback: some hosts resolve without packages/ prefix when running example.
      try {
        await controller.loadFlutterAsset('assets/epubjs/reader.html');
      } catch (e2) {
        if (mounted) {
          setState(() => _error = 'Failed to load EPUB shell: $e2');
        }
        return;
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _openBookIfNeeded() async {
    if (!_shellReady || _bookOpened || _bridge == null) return;
    try {
      final bytes = await readFileBytes(widget.filePath);
      // ~2MB threshold: base64 inflate ~33%.
      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        // Still use base64 for portability; host can switch to file URL later.
      }
      final b64 = base64Encode(bytes);
      await _bridge!.openFromBase64(b64);
    } catch (e) {
      widget.onError?.call(e.toString());
      if (mounted) setState(() => _error = e.toString());
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
    if (a >= 1) {
      return 'rgb($r,$g,$b)';
    }
    return 'rgba($r,$g,$b,${a.toStringAsFixed(3)})';
  }

  @override
  void didUpdateWidget(covariant EpubViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.typography != widget.typography ||
        oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.foregroundColor != widget.foregroundColor) {
      _applyTypography();
    }
    if (oldWidget.filePath != widget.filePath) {
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
