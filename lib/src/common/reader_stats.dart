/// Reading statistics delivered to the host (e.g. for cloud sync or charts).
class ReaderStats {
  const ReaderStats({
    required this.bookId,
    this.duration = Duration.zero,
    this.pagesRead = 0,
    this.charsRead = 0,
  });

  final String bookId;

  /// Time spent in the current session.
  final Duration duration;

  /// Distinct pages / chapters visited in this session.
  final int pagesRead;

  /// Characters shown in this session (novel only).
  final int charsRead;

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'durationSeconds': duration.inSeconds,
    'pagesRead': pagesRead,
    'charsRead': charsRead,
  };

  factory ReaderStats.fromJson(Map<String, dynamic> json) => ReaderStats(
    bookId: json['bookId'] as String? ?? '',
    duration: Duration(seconds: json['durationSeconds'] as int? ?? 0),
    pagesRead: json['pagesRead'] as int? ?? 0,
    charsRead: json['charsRead'] as int? ?? 0,
  );
}

typedef ReaderStatsCallback = void Function(ReaderStats stats);

/// Accumulates per-session stats. Only call [visit] for readable positions so
/// that trial-restricted content is never counted.
///
/// Reading time is measured with a [Stopwatch] (monotonic, unaffected by
/// wall-clock changes) and can be paused while the app is in the background.
/// With a non-zero [minDwell] a position only counts once the reader stayed
/// on it that long, so dragging a slider or auto-scrolling past pages does
/// not inflate the numbers.
class ReaderStatsTracker {
  ReaderStatsTracker(
    this.bookId, {
    this.minDwell = Duration.zero,
    Stopwatch? stopwatch,
  }) : _clock = stopwatch ?? Stopwatch() {
    _clock.start();
  }

  final String bookId;
  final Duration minDwell;
  final Stopwatch _clock;
  final Set<int> _visited = <int>{};
  int _chars = 0;
  int? _pendingIndex;
  int _pendingChars = 0;
  Duration _pendingSince = Duration.zero;

  /// Stops the clock (e.g. app paused). Pending dwell time is not counted.
  void pause() => _clock.stop();

  /// Resumes the clock after [pause].
  void resume() {
    if (!_clock.isRunning) _clock.start();
  }

  void _commitPending({bool force = false}) {
    final index = _pendingIndex;
    if (index == null) return;
    if (!force && _clock.elapsed - _pendingSince < minDwell) return;
    if (_visited.add(index)) _chars += _pendingChars;
    _pendingIndex = null;
  }

  void visit(int index, {int chars = 0}) {
    if (_pendingIndex == index) return;
    // Leaving a position commits it only if the reader stayed long enough.
    _commitPending();
    if (minDwell == Duration.zero) {
      if (_visited.add(index)) _chars += chars;
      _pendingIndex = null;
      return;
    }
    _pendingIndex = index;
    _pendingChars = chars;
    _pendingSince = _clock.elapsed;
  }

  ReaderStats snapshot() {
    _commitPending();
    return ReaderStats(
      bookId: bookId,
      duration: _clock.elapsed,
      pagesRead: _visited.length,
      charsRead: _chars,
    );
  }
}
