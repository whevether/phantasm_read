import 'dart:typed_data';

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
  static ComicPages fromBytes(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final files = archive.files
        .where((f) => f.isFile && _imageExt.hasMatch(f.name))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final images = <Uint8List>[
      for (final f in files) Uint8List.fromList(f.content as List<int>),
    ];
    return ComicPages.fromBytes(images);
  }
}
