import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

/// PDF reader via WebView (no native pdfium hook).
///
/// Supports trial page hints, watermark, and progress.
/// Page-accurate navigation depends on the platform WebView PDF plugin;
/// [onPageChanged] may only fire for host-driven jumps when unsupported.
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

  @override
  State<PdfReader> createState() => _PdfReaderState();
}

class _PdfReaderState extends State<PdfReader> with WidgetsBindingObserver {
  late final ReaderBrightness _brightness = ReaderBrightness();
  late ReaderSettings _settings;
  WebViewController? _controller;
  int _page = 0;
  bool _toolbar = false;
  String? _error;

  String get _bookId => widget.bookId ?? 'pdf_${widget.source.hashCode}';

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _page = widget.initialPage;
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _brightness.apply(_settings.brightness);
    if (_settings.keepScreenOn) await ReaderWakeLock.enable();
    if (widget.persistProgress) {
      final p = await ReaderProgressStore.instance.load(_bookId);
      if (p != null) _page = p.pageIndex;
    }
    await _initWebView();
    if (mounted) setState(() {});
  }

  Future<void> _initWebView() async {
    try {
      final bytes = switch (widget.source) {
        PdfSourceFile(:final path) => await readFileBytes(path),
        PdfSourceBytes(:final bytes) => bytes,
      };
      final b64 = base64Encode(bytes);
      final html = '''
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;height:100%;background:#333}embed,iframe{width:100%;height:100%;border:0}</style>
</head><body>
<embed src="data:application/pdf;base64,$b64" type="application/pdf" width="100%" height="100%"/>
</body></html>
''';
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadHtmlString(html);
      _controller = controller;
      widget.onPageChanged?.call(_page);
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> _leave() async {
    await _brightness.restore();
    await ReaderWakeLock.disable();
  }

  Future<void> _save() async {
    if (!widget.persistProgress) return;
    await ReaderProgressStore.instance.save(
      ReaderProgress(bookId: _bookId, pageIndex: _page, percentage: 0),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _save();
    _leave();
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

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final trial = widget.maxReadablePages;
    return ListenableBuilder(
      listenable: _brightness,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            WebViewWidget(controller: controller),
            BrightnessOverlay(
              brightness: _brightness.value,
              mode: _brightness.mode,
            ),
            if (widget.watermarkText != null)
              ReaderWatermark(text: widget.watermarkText!),
            if (trial != null && _page >= trial)
              const ColoredBox(
                color: Color(0xCC000000),
                child: Center(
                  child: Text(
                    '试读结束',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
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
                        kIsWeb
                            ? 'PDF (WebView)'
                            : 'PDF · page ${_page + 1}'
                                '${trial != null ? ' · 试读 $trial 页' : ''}',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            if (!_toolbar)
              ReaderProgressBar(
                progress: trial == null || trial <= 0
                    ? 0
                    : ((_page + 1) / trial).clamp(0.0, 1.0),
              ),
          ],
        );
      },
    );
  }
}
