import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Folder name used by `extended_image_library` disk cache.
const _cacheImageFolder = 'cacheimage';

/// Ensures the disk cache folder exists before `ExtendedNetworkImageProvider`
/// loads on macOS. The sandbox temp parent may not exist yet; the library calls
/// [Directory.create] without `recursive: true`, which throws [PathNotFoundException].
/// Other platforms are unaffected and rely on `extended_image` defaults.
Future<void> ensureComicNetworkImageCache() async {
  if (!Platform.isMacOS) return;
  try {
    final base = (await getTemporaryDirectory()).path;
    final dir = Directory('$base/$_cacheImageFolder');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  } on Object {
    // Best-effort; images may still load without disk cache.
  }
}
