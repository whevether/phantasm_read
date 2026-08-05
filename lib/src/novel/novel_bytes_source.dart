import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'file_bytes.dart';

/// Resolve novel content bytes from path / asset / url / raw bytes.
sealed class NovelBytesSource {
  const NovelBytesSource();

  factory NovelBytesSource.file(String path) = NovelBytesFile;
  factory NovelBytesSource.asset(String assetPath) = NovelBytesAsset;
  factory NovelBytesSource.url(String url, {Map<String, String>? headers}) =
      NovelBytesUrl;
  factory NovelBytesSource.bytes(Uint8List bytes, {String name = 'book'}) {
    return NovelBytesMemory(bytes, name: name);
  }

  Future<Uint8List> load();
  String get displayName;
}

final class NovelBytesFile extends NovelBytesSource {
  const NovelBytesFile(this.path);
  final String path;

  @override
  String get displayName => path;

  @override
  Future<Uint8List> load() => readFileBytes(path);
}

final class NovelBytesAsset extends NovelBytesSource {
  const NovelBytesAsset(this.assetPath);
  final String assetPath;

  @override
  String get displayName => assetPath;

  @override
  Future<Uint8List> load() async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }
}

final class NovelBytesUrl extends NovelBytesSource {
  const NovelBytesUrl(this.url, {this.headers});
  final String url;
  final Map<String, String>? headers;

  @override
  String get displayName => url;

  @override
  Future<Uint8List> load() async {
    final res = await http.get(Uri.parse(url), headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('HTTP ${res.statusCode} loading $url');
    }
    return res.bodyBytes;
  }
}

final class NovelBytesMemory extends NovelBytesSource {
  const NovelBytesMemory(this.bytes, {this.name = 'book'});
  final Uint8List bytes;
  final String name;

  @override
  String get displayName => name;

  @override
  Future<Uint8List> load() async => bytes;
}
