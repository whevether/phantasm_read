import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import '../novel_chapter.dart';

/// Dart ↔ epub.js bridge over [WebViewController].
class EpubBridge {
  EpubBridge(this.controller);

  final WebViewController controller;

  Future<void> openFromBase64(String base64, {String flow = 'paginated'}) {
    final encoded = jsonEncode(base64);
    final flowArg = jsonEncode(flow);
    return controller.runJavaScript(
      'window.epubBridge.openFromBase64($encoded, $flowArg)',
    );
  }

  Future<void> next() =>
      controller.runJavaScript('window.epubBridge.next()');

  Future<void> prev() =>
      controller.runJavaScript('window.epubBridge.prev()');

  Future<void> display(String? target) {
    final arg = target == null ? 'null' : jsonEncode(target);
    return controller.runJavaScript('window.epubBridge.display($arg)');
  }

  Future<void> goToChapter(String href) => display(href);

  Future<List<NovelChapter>> getToc() async {
    final raw = await controller.runJavaScriptReturningResult(
      'window.epubBridge.getToc()',
    );
    final text = _stringifyJsResult(raw);
    if (text.isEmpty || text == 'null') return const [];
    final decoded = jsonDecode(text);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => NovelChapter.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> setFlow(String flow) {
    return controller.runJavaScript(
      'window.epubBridge.setFlow(${jsonEncode(flow)})',
    );
  }

  Future<void> setFontSize(double fontSizePx) {
    final percent = ((fontSizePx / 18.0) * 100).clamp(50, 300).round();
    return controller.runJavaScript(
      'window.epubBridge.setFontSize($percent)',
    );
  }

  Future<void> setFontFamily(String? family) {
    if (family == null || family.isEmpty) return Future.value();
    return controller.runJavaScript(
      'window.epubBridge.setFontFamily(${jsonEncode(family)})',
    );
  }

  Future<void> setLineHeight(double lineHeight) {
    return controller.runJavaScript(
      'window.epubBridge.setLineHeight(${jsonEncode(lineHeight.toString())})',
    );
  }

  Future<void> setTheme({
    required String background,
    required String foreground,
  }) {
    return controller.runJavaScript(
      'window.epubBridge.setTheme(${jsonEncode(background)}, ${jsonEncode(foreground)})',
    );
  }

  String _stringifyJsResult(Object? raw) {
    if (raw == null) return '';
    if (raw is String) {
      // Android may wrap the returned string with extra quotes.
      try {
        final decoded = jsonDecode(raw);
        if (decoded is String) return decoded;
        return raw;
      } catch (_) {
        return raw;
      }
    }
    return raw.toString();
  }
}

class EpubBridgeMessage {
  EpubBridgeMessage({required this.type, this.payload});

  factory EpubBridgeMessage.parse(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return EpubBridgeMessage(
      type: map['type'] as String? ?? '',
      payload: map['payload'],
    );
  }

  final String type;
  final dynamic payload;
}
