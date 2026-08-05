import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/painting.dart';

import 'comic_file_image.dart';

/// Page list for the comic reader.
sealed class ComicPages {
  const ComicPages();

  factory ComicPages.fromFiles(List<String> paths) = ComicPagesFiles;
  factory ComicPages.fromUrls(List<String> urls) = ComicPagesUrls;
  factory ComicPages.fromBytes(List<Uint8List> bytes) = ComicPagesBytes;

  int get length;

  ImageProvider imageProviderAt(int index);
}

final class ComicPagesFiles extends ComicPages {
  const ComicPagesFiles(this.paths);
  final List<String> paths;

  @override
  int get length => paths.length;

  @override
  ImageProvider imageProviderAt(int index) => fileImageProvider(paths[index]);
}

final class ComicPagesUrls extends ComicPages {
  const ComicPagesUrls(this.urls);
  final List<String> urls;

  @override
  int get length => urls.length;

  @override
  ImageProvider imageProviderAt(int index) =>
      ExtendedNetworkImageProvider(urls[index], cache: true);
}

final class ComicPagesBytes extends ComicPages {
  const ComicPagesBytes(this.bytes);
  final List<Uint8List> bytes;

  @override
  int get length => bytes.length;

  @override
  ImageProvider imageProviderAt(int index) => MemoryImage(bytes[index]);
}
