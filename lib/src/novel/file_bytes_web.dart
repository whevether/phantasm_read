import 'dart:typed_data';

Future<Uint8List> readFileBytesImpl(String path) {
  throw UnsupportedError(
    'Reading local EPUB/text file paths is not supported on web. '
    'Provide bytes via a host-side fetch or use a non-web platform.',
  );
}
