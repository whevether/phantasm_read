import 'package:flutter/services.dart';

final Set<String> _loadedFonts = <String>{};

/// Registers a host-provided font so it can be used as
/// `NovelTypography.fontFamily`. Safe to call repeatedly for the same family.
Future<void> loadReaderCustomFont(String family, Uint8List bytes) async {
  if (family.isEmpty || bytes.isEmpty) return;
  if (!_loadedFonts.add(family)) return;
  try {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  } catch (_) {
    _loadedFonts.remove(family);
    rethrow;
  }
}
