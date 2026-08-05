import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

/// Dart ↔ epub.js bridge over [WebViewController].
class EpubBridge {
  EpubBridge(this.controller);

  final WebViewController controller;

  Future<void> openFromBase64(String base64) {
    final encoded = jsonEncode(base64);
    return controller.runJavaScript(
      'window.epubBridge.openFromBase64($encoded)',
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

  Future<void> setFontSize(double fontSizePx) {
    // Map px roughly to percent (18px ≈ 100%).
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

  Future<void> setTheme({required String background, required String foreground}) {
    return controller.runJavaScript(
      'window.epubBridge.setTheme(${jsonEncode(background)}, ${jsonEncode(foreground)})',
    );
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
