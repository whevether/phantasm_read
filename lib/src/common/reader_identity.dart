import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Stable across widget instances and process restarts.
String readerIdentity(String kind, Iterable<String> parts) =>
    '${kind}_${sha256.convert(utf8.encode(jsonEncode(parts.toList())))}';
String readerBytesIdentity(String kind, Uint8List bytes) =>
    '${kind}_${sha256.convert(bytes)}';

int _recordSequence = 0;
String readerRecordId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_recordSequence++}';
