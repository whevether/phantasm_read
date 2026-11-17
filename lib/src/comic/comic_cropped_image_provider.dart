import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'comic_auto_crop.dart';

/// Wraps [source] and removes near-uniform margins (see [ComicAutoCrop]).
///
/// Cropping happens after decoding the already-readable page only, so it never
/// touches pages outside the trial window. Results are cached by Flutter's
/// [ImageCache] keyed on [source], [tolerance] and [maxCrop].
@immutable
class CroppedImageProvider extends ImageProvider<CroppedImageProvider> {
  const CroppedImageProvider(
    this.source, {
    this.tolerance = 16,
    this.maxCrop = 0.2,
  });

  final ImageProvider source;
  final int tolerance;
  final double maxCrop;

  @override
  Future<CroppedImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<CroppedImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    CroppedImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_load());
  }

  /// Longest edge of the copy used for margin detection. Margins are a
  /// coarse property, so scanning a thumbnail is enough and avoids pulling
  /// the full-size RGBA buffer of a huge page into memory.
  static const int _detectEdge = 256;

  Future<ImageInfo> _load() async {
    final original = await _resolve(source);
    ui.Image? small;
    ui.Picture? picture;
    try {
      final longest = original.width > original.height
          ? original.width
          : original.height;
      var scanned = original;
      if (longest > _detectEdge) {
        final scale = _detectEdge / longest;
        final tw = (original.width * scale).round().clamp(1, original.width);
        final th = (original.height * scale).round().clamp(1, original.height);
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawImageRect(
          original,
          ui.Rect.fromLTWH(
            0,
            0,
            original.width.toDouble(),
            original.height.toDouble(),
          ),
          ui.Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
          ui.Paint()..filterQuality = ui.FilterQuality.medium,
        );
        final thumbPicture = recorder.endRecording();
        try {
          small = await thumbPicture.toImage(tw, th);
        } finally {
          thumbPicture.dispose();
        }
        scanned = small;
      }
      final data = await scanned.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return ImageInfo(image: original.clone());
      final rect = ComicAutoCrop.detect(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        scanned.width,
        scanned.height,
        tolerance: tolerance,
        maxCrop: maxCrop,
      );
      if (rect.isFull) return ImageInfo(image: original.clone());
      final src = ui.Rect.fromLTRB(
        rect.left * original.width,
        rect.top * original.height,
        rect.right * original.width,
        rect.bottom * original.height,
      );
      final w = src.width.round().clamp(1, original.width);
      final h = src.height.round().clamp(1, original.height);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        original,
        src,
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      picture = recorder.endRecording();
      final cropped = await picture.toImage(w, h);
      return ImageInfo(image: cropped);
    } finally {
      picture?.dispose();
      small?.dispose();
      original.dispose();
    }
  }

  static Future<ui.Image> _resolve(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        // The listener owns `info`: keep our own handle and release it, or
        // the decoded image would never be freed.
        if (!completer.isCompleted) completer.complete(info.image.clone());
        info.dispose();
        stream.removeListener(listener);
      },
      onError: (error, stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  @override
  bool operator ==(Object other) =>
      other is CroppedImageProvider &&
      other.source == source &&
      other.tolerance == tolerance &&
      other.maxCrop == maxCrop;

  @override
  int get hashCode => Object.hash(source, tolerance, maxCrop);
}
