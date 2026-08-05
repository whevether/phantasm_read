import 'reader_bookmark.dart';
import 'reader_progress.dart';

/// Payload for host-side cloud sync.
class ReaderSyncPayload {
  const ReaderSyncPayload({
    required this.bookId,
    this.progress,
    this.bookmarks = const [],
    this.highlights = const [],
  });

  final String bookId;
  final ReaderProgress? progress;
  final List<ReaderBookmark> bookmarks;
  final List<ReaderHighlight> highlights;
}

typedef ReaderSyncCallback = Future<void> Function(ReaderSyncPayload payload);

/// Fires [onSync] after local progress/bookmark changes (debounce-friendly).
class ReaderSyncHub {
  ReaderSyncHub({this.onSync});

  ReaderSyncCallback? onSync;

  Future<void> emit(ReaderSyncPayload payload) async {
    final cb = onSync;
    if (cb == null) return;
    await cb(payload);
  }
}
