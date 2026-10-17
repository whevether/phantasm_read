import 'package:flutter/foundation.dart';

import 'package:archive/archive.dart';

import 'comic_pages.dart';

/// Parse CBZ / ZIP comic archives into [ComicPages].
class ComicArchive {
  const ComicArchive._();

  static final _imageExt = RegExp(
    r'\.(jpe?g|png|gif|webp|bmp)$',
    caseSensitive: false,
  );

  /// Decode archive bytes (CBZ/ZIP) into memory pages ordered by filename.
  static Future<ComicPages> fromBytesAsync(Uint8List bytes) =>
      compute(fromBytes, bytes);

  static ComicPages fromBytes(Uint8List bytes) {
    if (bytes.length > 64 * 1024 * 1024) {
      throw const FormatException('Comic archive exceeds 64 MiB');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final files =
        archive.files
            .where((f) => f.isFile && _imageExt.hasMatch(f.name))
            .toList()
          ..sort((a, b) => _naturalCompare(a.name, b.name));
    if (files.length > 5000 ||
        files.fold<int>(0, (sum, f) => sum + f.size) > 256 * 1024 * 1024) {
      throw const FormatException(
        'Comic archive exceeds page or uncompressed size limit',
      );
    }
    final images = <Uint8List>[for (final f in files) f.content];
    return ComicPages.fromBytes(images);
  }
}

int _naturalCompare(String a, String b) {
  final parts = RegExp(r'\d+|\D+');
  final left = parts.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final right = parts.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < left.length && i < right.length; i++) {
    final x = BigInt.tryParse(left[i]), y = BigInt.tryParse(right[i]);
    final result = x != null && y != null
        ? x.compareTo(y)
        : left[i].compareTo(right[i]);
    if (result != 0) return result;
  }
  final length = left.length.compareTo(right.length);
  return length != 0 ? length : a.compareTo(b);
}
