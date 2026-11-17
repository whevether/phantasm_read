import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Stable across widget instances and process restarts.
String readerIdentity(String kind, Iterable<String> parts) =>
    '${kind}_${sha256.convert(utf8.encode(jsonEncode(parts.toList())))}';

// Hashing a large file on every widget update is expensive; the digest of a
// given buffer instance is computed once.
final Expando<String> _bytesDigests = Expando<String>('readerBytesDigest');

String readerBytesIdentity(String kind, Uint8List bytes) {
  final digest = _bytesDigests[bytes] ??= sha256.convert(bytes).toString();
  return '${kind}_$digest';
}

int _recordSequence = 0;
String readerRecordId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_recordSequence++}';
