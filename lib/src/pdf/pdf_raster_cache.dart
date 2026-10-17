import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Bounded raster cache. Thumbnails use their own low resolution entries.
class PdfRasterCache {
  PdfRasterCache(this.bytes, {this.maxBytes = 32 * 1024 * 1024});
  final Uint8List bytes;
  final int maxBytes;
  final _cache = <(int, double), PdfRaster>{};
  final _pending = <(int, double), Future<PdfRaster>>{};
  int _size = 0;
  bool _disposed = false;

  Future<PdfRaster> page(int index, double dpi) {
    final key = (index, dpi);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return Future.value(hit);
    }
    return _pending.putIfAbsent(key, () async {
      try {
        final raster = await Printing.raster(
          bytes,
          pages: [index],
          dpi: dpi,
        ).first;
        if (!_disposed && raster.pixels.length <= maxBytes) {
          while (_cache.isNotEmpty && _size + raster.pixels.length > maxBytes) {
            _size -= _cache.remove(_cache.keys.first)!.pixels.length;
          }
          _cache[key] = raster;
          _size += raster.pixels.length;
        }
        return raster;
      } finally {
        _pending.remove(key);
      }
    });
  }

  void dispose() {
    _disposed = true;
    _cache.clear();
    _size = 0;
  }
}
