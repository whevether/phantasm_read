import 'dart:async';
import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Bounded raster cache. Thumbnails use their own low resolution entries.
class PdfRasterCache {
  PdfRasterCache(
    this.bytes, {
    this.maxBytes = 32 * 1024 * 1024,
    this.maxConcurrent = 2,
  });
  final Uint8List bytes;
  final int maxBytes;

  /// Rasterising is memory hungry; never run more than this many at once.
  final int maxConcurrent;
  int _running = 0;
  final _waiting = <Completer<void>>[];

  Future<void> _acquire() async {
    if (_running < maxConcurrent) {
      _running++;
      return;
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    await waiter.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _running--;
    }
  }

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
      await _acquire();
      try {
        if (_disposed) throw StateError('PDF raster cache disposed');
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
        _release();
      }
    });
  }

  void dispose() {
    _disposed = true;
    _cache.clear();
    _size = 0;
  }
}
