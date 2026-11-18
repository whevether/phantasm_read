import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import '../file_bytes.dart';

/// Decode text files: BOM first, then UTF-8, then the best-scoring legacy
/// encoding (GB18030/GBK, Big5, Shift_JIS, EUC-KR, Thai/Vietnamese code
/// pages).
class NovelTextDecoder {
  const NovelTextDecoder();

  /// Legacy candidates tried (in priority order) when the bytes are not UTF-8.
  static const List<String> legacyCandidates = [
    'gb18030',
    'big5',
    'shift_jis',
    'euc-kr',
    'windows-874',
    'windows-1258',
    'windows-1252',
  ];

  /// Platform charset names tried for each canonical encoding name.
  static const Map<String, List<String>> _platformNames = {
    'gb18030': ['GB18030', 'gb18030', 'GBK', 'gbk'],
    'gbk': ['GBK', 'gbk', 'GB18030', 'gb18030', 'GB2312'],
    'big5': ['Big5', 'big5', 'Big5-HKSCS'],
    'shift_jis': ['Shift_JIS', 'shift_jis', 'windows-31j', 'SJIS'],
    'euc-kr': ['EUC-KR', 'euc-kr', 'windows-949'],
    'windows-874': ['windows-874', 'TIS-620', 'ISO-8859-11', 'cp874'],
    'windows-1258': ['windows-1258', 'cp1258'],
    'windows-1252': ['windows-1252', 'cp1252', 'ISO-8859-1'],
  };

  static const Map<String, String> _aliases = {
    'utf8': 'utf-8',
    'utf-8': 'utf-8',
    'unicode-1-1-utf-8': 'utf-8',
    'gb2312': 'gbk',
    'gbk': 'gbk',
    'cp936': 'gbk',
    'gb18030': 'gb18030',
    'big5': 'big5',
    'big5-hkscs': 'big5',
    'cp950': 'big5',
    'shift_jis': 'shift_jis',
    'shift-jis': 'shift_jis',
    'sjis': 'shift_jis',
    'windows-31j': 'shift_jis',
    'cp932': 'shift_jis',
    'euc-kr': 'euc-kr',
    'euckr': 'euc-kr',
    'cp949': 'euc-kr',
    'windows-949': 'euc-kr',
    'tis-620': 'windows-874',
    'iso-8859-11': 'windows-874',
    'windows-874': 'windows-874',
    'cp874': 'windows-874',
    'windows-1258': 'windows-1258',
    'cp1258': 'windows-1258',
    'windows-1252': 'windows-1252',
    'cp1252': 'windows-1252',
    'iso-8859-1': 'windows-1252',
    'latin1': 'windows-1252',
    'us-ascii': 'utf-8',
    'ascii': 'utf-8',
    'utf-16': 'utf-16',
    'utf-16le': 'utf-16le',
    'utf-16be': 'utf-16be',
  };

  /// Maps user/HTML supplied names (`UTF8`, `GB2312`, `cp936`, ...) to a
  /// canonical lower-case name; unknown names are returned lower-cased.
  static String canonicalEncoding(String name) {
    final key = name.trim().toLowerCase().replaceAll('_', '-');
    return _aliases[key] ??
        _aliases[key.replaceAll('-', '')] ??
        name.trim().toLowerCase();
  }

  Future<String> decodeFile(String path, {String? encoding}) async {
    final bytes = await readFileBytes(path);
    return decodeBytes(bytes, encoding: encoding);
  }

  Future<String> decodeBytes(
    Uint8List bytes, {
    String? encoding,
    String kind = 'text',
  }) async {
    final bom = _decodeBom(bytes);
    if (bom != null) return bom;
    var name = encoding == null || encoding.trim().isEmpty
        ? null
        : canonicalEncoding(encoding);
    if (name == null && kind == 'html') {
      final meta = sniffHtmlCharset(bytes);
      if (meta != null) {
        final metaName = canonicalEncoding(meta);
        // Only trust the meta tag when it actually decodes cleanly.
        if (metaName == 'utf-8') {
          name = 'utf-8';
        } else {
          final decoded = await _decodeWith(metaName, bytes);
          if (decoded != null && !decoded.contains('\uFFFD')) return decoded;
        }
      }
    }
    if (name == 'utf-8') return utf8.decode(bytes, allowMalformed: true);
    if (name != null) {
      final decoded = await _decodeWith(name, bytes);
      if (decoded != null) return decoded;
      // Unknown/unsupported name: fall back to detection below.
    }
    try {
      return utf8.decode(bytes);
    } catch (_) {
      final sample = bytes.length > 65536
          ? Uint8List.sublistView(bytes, 0, 65536)
          : bytes;
      final candidates = <String, String>{};
      for (final candidate in legacyCandidates) {
        final decoded = await _decodeWith(candidate, sample);
        if (decoded != null) candidates[candidate] = decoded;
      }
      final best = chooseBestDecoding(candidates);
      if (best != null) {
        final full = bytes.length == sample.length
            ? candidates[best]
            : await _decodeWith(best, bytes);
        if (full != null) return full;
      }
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  Future<String?> _decodeWith(String canonical, Uint8List bytes) async {
    if (canonical == 'utf-8') return utf8.decode(bytes, allowMalformed: true);
    if (canonical == 'utf-16' ||
        canonical == 'utf-16le' ||
        canonical == 'utf-16be') {
      return _decodeUtf16(bytes, bigEndian: canonical == 'utf-16be');
    }
    final names = _platformNames[canonical] ?? [canonical];
    for (final platformName in names) {
      try {
        return await CharsetConverter.decode(platformName, bytes);
      } catch (e) {
        // Try the next platform alias.
        debugPrint('TextDecoder: $platformName unavailable: $e');
      }
    }
    return null;
  }

  String? _decodeBom(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(Uint8List.sublistView(bytes, 3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(Uint8List.sublistView(bytes, 2), bigEndian: false);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(Uint8List.sublistView(bytes, 2), bigEndian: true);
    }
    return null;
  }

  String _decodeUtf16(Uint8List bytes, {required bool bigEndian}) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(
        bigEndian
            ? (bytes[i] << 8) | bytes[i + 1]
            : (bytes[i + 1] << 8) | bytes[i],
      );
    }
    return String.fromCharCodes(units);
  }

  /// Reads `<meta charset=...>` / `Content-Type` charset from the head.
  @visibleForTesting
  static String? sniffHtmlCharset(Uint8List bytes) {
    final head = latin1.decode(
      bytes.length > 2048 ? Uint8List.sublistView(bytes, 0, 2048) : bytes,
      allowInvalid: true,
    );
    final match = RegExp(
      r'''charset\s*=\s*["']?\s*([A-Za-z0-9_\-]+)''',
      caseSensitive: false,
    ).firstMatch(head);
    return match?.group(1);
  }

  /// Plausibility score of a decoded sample: common scripts count, mojibake
  /// markers (U+FFFD, private-use, C1 controls, isolated Latin-1 symbols)
  /// are penalised.
  @visibleForTesting
  static double scoreDecoded(String text) {
    if (text.isEmpty) return 0;
    var good = 0.0;
    var bad = 0.0;
    var total = 0;
    for (final rune in text.runes) {
      total++;
      if (rune == 0xFFFD) {
        bad += 10;
      } else if (rune >= 0xE000 && rune <= 0xF8FF) {
        bad += 5;
      } else if (rune >= 0x80 && rune <= 0x9F) {
        bad += 5;
      } else if (rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D) {
        bad += 3;
      } else if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
          (rune >= 0x3040 && rune <= 0x30FF) ||
          (rune >= 0xAC00 && rune <= 0xD7AF) ||
          (rune >= 0x0E00 && rune <= 0x0E7F)) {
        good += 1;
      } else if (rune >= 0x3400 && rune <= 0x4DBF) {
        bad += 1;
      } else if (rune >= 0xA0 && rune <= 0xBF) {
        bad += 0.5;
      } else if ((rune >= 0x0300 && rune <= 0x036F) ||
          (rune >= 0x00C0 && rune <= 0x024F) ||
          (rune >= 0x1EA0 && rune <= 0x1EF9)) {
        good += 0.3;
      } else if (rune < 0x80) {
        good += 0.2;
      }
    }
    return (good - bad) / total;
  }

  /// Picks the candidate with the highest [scoreDecoded]; earlier entries
  /// win ties, so insertion order is the priority order.
  @visibleForTesting
  static String? chooseBestDecoding(Map<String, String> candidates) {
    String? best;
    var bestScore = double.negativeInfinity;
    candidates.forEach((name, text) {
      final score = scoreDecoded(text);
      if (score > bestScore + 1e-9) {
        bestScore = score;
        best = name;
      }
    });
    return best;
  }

  static const Map<String, String> _namedEntities = {
    'nbsp': ' ',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'copy': '\u00A9',
    'reg': '\u00AE',
    'trade': '\u2122',
    'hellip': '\u2026',
    'mdash': '\u2014',
    'ndash': '\u2013',
    'lsquo': '\u2018',
    'rsquo': '\u2019',
    'ldquo': '\u201C',
    'rdquo': '\u201D',
    'laquo': '\u00AB',
    'raquo': '\u00BB',
    'middot': '\u00B7',
    'bull': '\u2022',
    'times': '\u00D7',
    'divide': '\u00F7',
    'deg': '\u00B0',
    'euro': '\u20AC',
    'yen': '\u00A5',
    'pound': '\u00A3',
    'cent': '\u00A2',
    'sect': '\u00A7',
    'para': '\u00B6',
    'iexcl': '\u00A1',
    'iquest': '\u00BF',
  };

  /// Decodes numeric and common named HTML entities (`&amp;` last).
  @visibleForTesting
  static String decodeHtmlEntities(String input) {
    return input
        .replaceAllMapped(RegExp(r'&#[xX]([0-9a-fA-F]{1,6});'), (m) {
          final code = int.tryParse(m[1]!, radix: 16);
          return _safeChar(code) ?? m[0]!;
        })
        .replaceAllMapped(RegExp(r'&#(\d{1,7});'), (m) {
          final code = int.tryParse(m[1]!);
          return _safeChar(code) ?? m[0]!;
        })
        .replaceAllMapped(
          RegExp(r'&([A-Za-z]{2,8});'),
          (m) => m[1] == 'amp' ? m[0]! : (_namedEntities[m[1]!] ?? m[0]!),
        )
        .replaceAll('&amp;', '&');
  }

  static String? _safeChar(int? code) {
    if (code == null ||
        code <= 0 ||
        code > 0x10FFFF ||
        (code >= 0xD800 && code <= 0xDFFF)) {
      return null;
    }
    return String.fromCharCode(code);
  }

  /// Heading texts in document order for markdown/html (empty for plain
  /// text). Must be called on the raw text, before [normalizeContent].
  List<String> extractHeadings(String raw, {required String kind}) {
    final headings = <String>[];
    switch (kind) {
      case 'markdown':
        for (final m in RegExp(
          r'^#{1,3}[ \t]*(.+?)[ \t#]*$',
          multiLine: true,
        ).allMatches(raw)) {
          headings.add(_plain(m[1]!));
        }
      case 'html':
        for (final m in RegExp(
          r'<h[1-3][^>]*>([\s\S]*?)</h[1-3]\s*>',
          caseSensitive: false,
        ).allMatches(raw)) {
          headings.add(
            _plain(
              decodeHtmlEntities(m[1]!.replaceAll(RegExp(r'<[^>]+>'), '')),
            ),
          );
        }
    }
    return headings.where((e) => e.isNotEmpty).toList();
  }

  String _plain(String value) => value
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'`(.+?)`'), (m) => m[1]!)
      .trim();

  /// Strip tags for html; light markdown normalization for md.
  String normalizeContent(String raw, {required String kind}) {
    switch (kind) {
      case 'html':
        return decodeHtmlEntities(
          raw
              .replaceAll(
                RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
                '',
              )
              .replaceAll(
                RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
                '',
              )
              .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
              .replaceAll(
                RegExp(
                  r'</(?:p|div|h[1-6]|li|section|article|blockquote|tr)\s*>',
                  caseSensitive: false,
                ),
                '\n\n',
              )
              .replaceAll(RegExp(r'<[^>]+>'), ''),
        ).trim();
      case 'markdown':
        return raw
            .replaceAll(RegExp(r'^#{1,6}[ \t]*', multiLine: true), '')
            .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!)
            .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m[1]!)
            .replaceAllMapped(RegExp(r'`(.+?)`'), (m) => m[1]!)
            .trim();
      default:
        return raw;
    }
  }
}
