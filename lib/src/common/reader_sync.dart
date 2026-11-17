import 'package:synchronized/synchronized.dart';

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

/// How the host should resolve differences between local and remote data.
///
/// The package only reports local changes through [ReaderSyncCallback]; it
/// never merges remote data itself. Suggested defaults:
/// - progress: [latestWins] using an `updatedAt` kept by the host
/// - bookmarks / highlights / notes: [mergeById]
enum ReaderSyncConflictPolicy { latestWins, mergeById, localWins, remoteWins }

typedef ReaderSyncCallback = Future<void> Function(ReaderSyncPayload payload);

/// Fires [onSync] after local progress/bookmark changes (debounce-friendly).
///
/// Emissions from all hubs are serialized (one host callback at a time, in
/// order) and a throwing host callback never breaks the reader; report such
/// failures through [onError] when you want to observe them.
class ReaderSyncHub {
  ReaderSyncHub({this.onSync, this.onError});

  ReaderSyncCallback? onSync;

  /// Called when [onSync] throws.
  void Function(Object error, StackTrace stackTrace)? onError;

  static final Lock _lock = Lock();

  Future<void> emit(ReaderSyncPayload payload) async {
    final cb = onSync;
    if (cb == null) return;
    await _lock.synchronized(() async {
      try {
        await cb(payload);
      } catch (error, stack) {
        onError?.call(error, stack);
      }
    });
  }
}
