import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/painting.dart';

ImageProvider fileImageProvider(String path) {
  return ExtendedFileImageProvider(File(path), cacheRawData: true);
}
