import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A bookmark for comic page or novel location.
class ReaderBookmark {
  const ReaderBookmark({
    required this.id,
    required this.bookId,
    required this.title,
    this.pageIndex,
    this.cfi,
    this.paragraphIndex,
    this.note,
    this.createdAt,
  });

  final String id;
  final String bookId;
  final String title;
  final int? pageIndex;
  final String? cfi;
  final int? paragraphIndex;
  final String? note;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'title': title,
        'pageIndex': pageIndex,
        'cfi': cfi,
        'paragraphIndex': paragraphIndex,
        'note': note,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory ReaderBookmark.fromJson(Map<String, dynamic> json) {
    return ReaderBookmark(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      pageIndex: json['pageIndex'] as int?,
      cfi: json['cfi'] as String?,
      paragraphIndex: json['paragraphIndex'] as int?,
      note: json['note'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

/// Highlight / annotation on novel text.
class ReaderHighlight {
  const ReaderHighlight({
    required this.id,
    required this.bookId,
    required this.excerpt,
    this.cfi,
    this.paragraphIndex,
    this.color = 0xFFFFEB3B,
    this.note,
    this.createdAt,
  });

  final String id;
  final String bookId;
  final String excerpt;
  final String? cfi;
  final int? paragraphIndex;
  final int color;
  final String? note;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'excerpt': excerpt,
        'cfi': cfi,
        'paragraphIndex': paragraphIndex,
        'color': color,
        'note': note,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory ReaderHighlight.fromJson(Map<String, dynamic> json) {
    return ReaderHighlight(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ?? '',
      excerpt: json['excerpt'] as String? ?? '',
      cfi: json['cfi'] as String?,
      paragraphIndex: json['paragraphIndex'] as int?,
      color: json['color'] as int? ?? 0xFFFFEB3B,
      note: json['note'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

class ReaderBookmarkStore {
  ReaderBookmarkStore._();
  static final ReaderBookmarkStore instance = ReaderBookmarkStore._();

  static const _bmPrefix = 'phantasm_bookmarks_';
  static const _hlPrefix = 'phantasm_highlights_';

  Future<List<ReaderBookmark>> listBookmarks(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_bmPrefix$bookId');
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => ReaderBookmark.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveBookmarks(String bookId, List<ReaderBookmark> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_bmPrefix$bookId',
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addBookmark(ReaderBookmark bookmark) async {
    final list = [...await listBookmarks(bookmark.bookId), bookmark];
    await saveBookmarks(bookmark.bookId, list);
  }

  Future<void> removeBookmark(String bookId, String id) async {
    final list = await listBookmarks(bookId);
    await saveBookmarks(bookId, list.where((e) => e.id != id).toList());
  }

  Future<List<ReaderHighlight>> listHighlights(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_hlPrefix$bookId');
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => ReaderHighlight.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveHighlights(String bookId, List<ReaderHighlight> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_hlPrefix$bookId',
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addHighlight(ReaderHighlight highlight) async {
    final list = [...await listHighlights(highlight.bookId), highlight];
    await saveHighlights(highlight.bookId, list);
  }

  Future<void> removeHighlight(String bookId, String id) async {
    final list = await listHighlights(bookId);
    await saveHighlights(bookId, list.where((e) => e.id != id).toList());
  }

  /// Export bookmarks + highlights as JSON map.
  Future<Map<String, dynamic>> exportJson(String bookId) async {
    return {
      'bookmarks': (await listBookmarks(bookId)).map((e) => e.toJson()).toList(),
      'highlights': (await listHighlights(bookId)).map((e) => e.toJson()).toList(),
    };
  }
}
