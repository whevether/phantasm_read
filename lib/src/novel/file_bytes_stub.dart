import 'dart:typed_data';

Future<Uint8List> readFileBytesImpl(String path) {
  throw UnsupportedError('File reading is not available on this platform: $path');
}
