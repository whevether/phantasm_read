import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Reading progress for a book identified by [bookId].
class ReaderProgress {
  const ReaderProgress({
    required this.bookId,
    this.pageIndex = 0,
    this.cfi,
    this.paragraphIndex,
    this.textOffset,
    this.percentage = 0,
    this.updatedAt,
    this.positionVersion = 2,
  });

  final String bookId;
  final int pageIndex;
  final String? cfi;
  final int? paragraphIndex;
  final int? textOffset;
  final double percentage;
  final DateTime? updatedAt;

  /// Version 2 stores absolute content pages rather than view/spread indices.
  final int positionVersion;

  Map<String, dynamic> toJson() => {
    'positionVersion': positionVersion,
    'bookId': bookId,
    'pageIndex': pageIndex,
    'cfi': cfi,
    'paragraphIndex': paragraphIndex,
    'textOffset': textOffset,
    'percentage': percentage,
    'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
  };

  factory ReaderProgress.fromJson(Map<String, dynamic> json) {
    return ReaderProgress(
      positionVersion: json['positionVersion'] as int? ?? 1,
      bookId: json['bookId'] as String? ?? '',
      pageIndex: json['pageIndex'] as int? ?? 0,
      cfi: json['cfi'] as String?,
      paragraphIndex: json['paragraphIndex'] as int?,
      textOffset: json['textOffset'] as int?,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

/// Persist / restore reading progress via SharedPreferences.
class ReaderProgressStore {
  ReaderProgressStore._();
  static final ReaderProgressStore instance = ReaderProgressStore._();

  static const _prefix = 'phantasm_progress_';

  Future<void> save(ReaderProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix${progress.bookId}',
      jsonEncode(progress.toJson()),
    );
  }

  Future<ReaderProgress?> load(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$bookId');
    if (raw == null) return null;
    try {
      return ReaderProgress.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  /// Copies a known legacy key. The source is retained for rollback.
  Future<void> migrate(String oldBookId, String newBookId) async {
    if (await load(newBookId) != null) return;
    final previous = await load(oldBookId);
    if (previous == null) return;
    await save(
      ReaderProgress(
        bookId: newBookId,
        pageIndex: previous.pageIndex,
        cfi: previous.cfi,
        paragraphIndex: previous.paragraphIndex,
        textOffset: previous.textOffset,
        percentage: previous.percentage,
        updatedAt: previous.updatedAt,
        positionVersion: previous.positionVersion,
      ),
    );
  }

  Future<void> clear(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$bookId');
  }
}
