import 'dart:async';
import 'dart:convert';

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

  Future<String> getText() async => '${await requests.call('getText') ?? ''}';
  Future<void> setFontSize(double px) async =>
      requests.call('setFontSize', [((px / 18) * 100).clamp(50, 300).round()]);
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

class EpubBridgeMessage {
  EpubBridgeMessage({required this.type, this.payload});
  factory EpubBridgeMessage.parse(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is Map && map['type'] is String) {
        return EpubBridgeMessage(type: map['type'], payload: map['payload']);
      }
    } catch (_) {
      /* Ignore non-protocol messages from a document. */
    }
    return EpubBridgeMessage(type: 'invalid');
  }
  final String type;
  final dynamic payload;
}
