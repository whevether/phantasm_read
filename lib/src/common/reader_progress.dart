import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Reading progress for a book identified by [bookId].
class ReaderProgress {
  const ReaderProgress({
    required this.bookId,
    this.pageIndex = 0,
    this.cfi,
    this.paragraphIndex,
    this.percentage = 0,
    this.updatedAt,
  });

  final String bookId;
  final int pageIndex;
  final String? cfi;
  final int? paragraphIndex;
  final double percentage;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'pageIndex': pageIndex,
        'cfi': cfi,
        'paragraphIndex': paragraphIndex,
        'percentage': percentage,
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory ReaderProgress.fromJson(Map<String, dynamic> json) {
    return ReaderProgress(
      bookId: json['bookId'] as String? ?? '',
      pageIndex: json['pageIndex'] as int? ?? 0,
      cfi: json['cfi'] as String?,
      paragraphIndex: json['paragraphIndex'] as int?,
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
    await prefs.setString('$_prefix${progress.bookId}', jsonEncode(progress.toJson()));
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

  Future<void> clear(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$bookId');
  }
}
