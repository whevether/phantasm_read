import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:webview_flutter/webview_flutter.dart';

import '../novel_chapter.dart';

/// Correlates asynchronous JS replies; native evaluateJavascript need not await JS.
class EpubRequestBroker {
  EpubRequestBroker(this.execute, {this.timeout = const Duration(seconds: 45)});
  final Future<void> Function(String) execute;
  final Duration timeout;
  final _pending = <int, Completer<dynamic>>{};
  int _nextId = 0;
  bool _closed = false;

  Future<dynamic> call(String method, [List<Object?> args = const []]) async {
    if (_closed) throw StateError('EPUB bridge is closed');
    final id = ++_nextId;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    // Install the error/timeout handler before executing a synchronous test bridge.
    final result = completer.future.timeout(timeout);
    void fail(Object error, StackTrace stack) {
      if (!completer.isCompleted) completer.completeError(error, stack);
    }

    try {
      unawaited(
        execute(
          'window.epubBridge.request($id, ${jsonEncode(method)}, ${jsonEncode(args)})',
        ).then<void>((_) {}, onError: fail),
      );
    } catch (error, stack) {
      fail(error, stack);
    }
    try {
      return await result;
    } finally {
      _pending.remove(id);
    }
  }

  void receive(dynamic payload) {
    if (payload is! Map || payload['id'] is! int) return;
    final pending = _pending.remove(payload['id']);
    if (pending == null || pending.isCompleted) return;
    if (payload['error'] != null) {
      pending.completeError(StateError('${payload['error']}'));
    } else {
      pending.complete(payload['result']);
    }
  }

  void dispose() {
    _closed = true;
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('EPUB bridge disposed'));
      }
    }
    _pending.clear();
  }
}

class EpubBridge {
  EpubBridge(this.controller)
    : requests = EpubRequestBroker(controller.runJavaScript);
  final WebViewController controller;
  final EpubRequestBroker requests;
  void dispose() => requests.dispose();
  void receive(dynamic payload) => requests.receive(payload);
  Future<void> openFromBase64(
    String base64, {
    String flow = 'paginated',
    int? trialStart,
    int? trialCount,
    String? initialCfi,
  }) async => requests.call('openFromBase64', [
    base64,
    flow,
    trialStart,
    trialCount,
    initialCfi,
  ]);

  /// Sends [bytes] in chunks (no single multi-megabyte JavaScript string) and
  /// opens the book from the assembled upload.
  Future<void> openFromBytes(
    Uint8List bytes, {
    String flow = 'paginated',
    int? trialStart,
    int? trialCount,
    String? initialCfi,
    int chunkSize = 512 * 1024,
    bool Function()? isCancelled,
  }) async {
    if (bytes.length <= chunkSize) {
      return openFromBase64(
        base64Encode(bytes),
        flow: flow,
        trialStart: trialStart,
        trialCount: trialCount,
        initialCfi: initialCfi,
      );
    }
    await requests.call('beginUpload');
    for (var at = 0; at < bytes.length; at += chunkSize) {
      if (isCancelled?.call() ?? false) return;
      final end = at + chunkSize < bytes.length ? at + chunkSize : bytes.length;
      await requests.call('appendChunk', [
        base64Encode(Uint8List.sublistView(bytes, at, end)),
      ]);
    }
    if (isCancelled?.call() ?? false) return;
    await requests.call('openFromBase64', [
      null,
      flow,
      trialStart,
      trialCount,
      initialCfi,
    ]);
  }

  /// `rtl` forces right-to-left text and page progression; anything else keeps
  /// the book's own direction.
  Future<void> setDirection(String direction) async =>
      requests.call('setDirection', [direction]);

  Future<void> next() async => requests.call('next');
  Future<void> prev() async => requests.call('prev');
  Future<void> display(String? target) async =>
      requests.call('display', [target]);
  Future<void> goToChapter(String href) => display(href);
  Future<List<NovelChapter>> getToc() async {
    final result = await requests.call('getToc');
    if (result is! List) throw const FormatException('Invalid EPUB TOC reply');
    return result
        .whereType<Map>()
        .map((e) => NovelChapter.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> setAutoScroll(bool enabled, {double speed = 40}) async =>
      requests.call('setAutoScroll', [enabled, speed]);

  Future<void> setFlow(String flow) async => requests.call('setFlow', [flow]);
  Future<List<Map<String, String>>> search(String query) async {
    final result = await requests.call('search', [query]);
    if (result is! List) {
      throw const FormatException('Invalid EPUB search reply');
    }
    return result
        .whereType<Map>()
        .map(
          (e) => {
            'cfi': '${e['cfi'] ?? ''}',
            'excerpt': '${e['excerpt'] ?? ''}',
          },
        )
        .toList();
  }

  Future<Map<String, dynamic>?> getLocation() async {
    final result = await requests.call('getLocation');
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  Future<String?> getLanguage() async {
    final value = await requests.call('getLanguage');
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<String> getText() async => '${await requests.call('getText') ?? ''}';
  Future<void> setFontSize(double px) async =>
      requests.call('setFontSize', [((px / 18) * 100).clamp(50, 300).round()]);
  Future<void> addFontFace(
    String family,
    String base64Data, {
    String mime = 'font/ttf',
  }) async => requests.call('addFontFace', [family, base64Data, mime]);
  Future<void> setFontFamily(String? family) async =>
      requests.call('setFontFamily', [family]);
  Future<void> setLineHeight(double height) async =>
      requests.call('setLineHeight', [height]);
  Future<void> setTypography({
    required double letterSpacing,
    required double margin,
    required String textAlign,
  }) async =>
      requests.call('setTypography', [letterSpacing, margin, textAlign]);
  Future<void> setTheme({
    required String background,
    required String foreground,
  }) async => requests.call('setTheme', [background, foreground]);
}

/// Guesses the font MIME type from its magic bytes (defaults to TrueType).
String epubFontMimeType(List<int> bytes) {
  if (bytes.length >= 4) {
    final tag = String.fromCharCodes(bytes.take(4));
    if (tag == 'wOFF') return 'font/woff';
    if (tag == 'wOF2') return 'font/woff2';
    if (tag == 'OTTO') return 'font/otf';
  }
  return 'font/ttf';
}

class EpubBridgeMessage {
  EpubBridgeMessage({required this.type, this.payload});
  factory EpubBridgeMessage.parse(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is Map && map['type'] is String) {
        return EpubBridgeMessage(type: map['type'], payload: map['payload']);
      }
    } catch (e) {
      /* Ignore non-protocol messages from a document. */
      debugPrint('EpubBridge: ignored non-protocol message: $e');
    }
    return EpubBridgeMessage(type: 'invalid');
  }
  final String type;
  final dynamic payload;
}
