import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';

import '../file_bytes.dart';

/// Decode text files with UTF-8 first, then GBK/GB18030.
class NovelTextDecoder {
  const NovelTextDecoder();

  Future<String> decodeFile(String path, {String? encoding}) async {
    final bytes = await readFileBytes(path);
    return decodeBytes(bytes, encoding: encoding);
  }

  Future<String> decodeBytes(Uint8List bytes, {String? encoding}) async {
    if (encoding != null) {
      return CharsetConverter.decode(encoding, bytes);
    }
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return await CharsetConverter.decode('gbk', bytes);
      } catch (_) {
        try {
          return await CharsetConverter.decode('gb18030', bytes);
        } catch (_) {
          return utf8.decode(bytes, allowMalformed: true);
        }
      }
    }
  }

  /// Strip tags for html; light markdown normalization for md.
  String normalizeContent(String raw, {required String kind}) {
    switch (kind) {
      case 'html':
        return raw
            .replaceAll(
              RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
              '',
            )
            .replaceAll(
              RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
              '',
            )
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&')
            .trim();
      case 'markdown':
        return raw
            .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
            .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
            .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
            .replaceAll(RegExp(r'`(.+?)`'), r'$1')
            .trim();
      default:
        return raw;
    }
  }
}
