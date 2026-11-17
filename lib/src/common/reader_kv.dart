import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tostore/tostore.dart';

/// Shared ToStore key-value backend for all persisted reader data
/// (settings, progress, bookmarks, highlights, ink).
///
/// All keys are written with `isGlobal: true` so they stay visible when the
/// host app switches ToStore spaces.
class ReaderKv {
  ReaderKv._();

  static const _dbName = 'phantasm_read';
  static Future<ToStore>? _db;

  /// When non-null, all calls use this map instead of ToStore. Widget tests
  /// run in FakeAsync, which ToStore's real I/O cannot be driven from.
  static Map<String, String>? _fake;

  static Future<ToStore> get _instance => _db ??= _open();

  static Future<ToStore> _open() async {
    try {
      if (kIsWeb) return await ToStore.open(dbName: _dbName);
      final dir = await getApplicationSupportDirectory();
      return await ToStore.open(dbPath: dir.path, dbName: _dbName);
    } catch (_) {
      // Allow a later call to retry instead of caching a failed open.
      _db = null;
      rethrow;
    }
  }

  /// Switches to a fresh in-memory map. Intended for tests.
  @visibleForTesting
  static Future<void> useMemoryForTesting() async {
    _fake = <String, String>{};
  }

  /// Uses [db] as the backend (and clears any in-memory test map).
  @visibleForTesting
  static void useDatabaseForTesting(ToStore db) {
    _fake = null;
    _db = Future.value(db);
  }

  static Future<String?> getString(String key) async {
    final fake = _fake;
    if (fake != null) return fake[key];
    return (await _instance).kv.getString(key, isGlobal: true);
  }

  static Future<void> setString(String key, String value) async {
    final fake = _fake;
    if (fake != null) {
      fake[key] = value;
      return;
    }
    await (await _instance).kv.set(key, value, isGlobal: true);
  }

  static Future<void> remove(String key) async {
    final fake = _fake;
    if (fake != null) {
      fake.remove(key);
      return;
    }
    await (await _instance).kv.remove(key, isGlobal: true);
  }

  static Future<List<String>> keys(String prefix) async {
    final fake = _fake;
    if (fake != null) {
      return fake.keys.where((k) => k.startsWith(prefix)).toList();
    }
    return (await _instance).kv.getKeys(prefix: prefix, isGlobal: true);
  }
}
