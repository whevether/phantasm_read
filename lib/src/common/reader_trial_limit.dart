/// Unit counted by [ReaderTrialLimit].
enum ReaderTrialUnit {
  /// Comic / PDF pages.
  page,

  /// Novel chapters (TOC or detected headings).
  chapter,
}

/// What the user attempted when the trial cap blocked them.
enum ReaderTrialLimitAction {
  next,
  seek,
  chapterSelect,
  search,
}

/// Trial / preview window configured by the host app.
///
/// For comics and PDFs, [unit] is [ReaderTrialUnit.page].
/// For novels, [unit] is [ReaderTrialUnit.chapter].
class ReaderTrialLimit {
  const ReaderTrialLimit({
    required this.maxCount,
    this.startIndex = 0,
    this.unit = ReaderTrialUnit.page,
  });

  /// First [maxCount] pages starting at [startPage].
  factory ReaderTrialLimit.pages(int maxCount, {int startPage = 0}) {
    return ReaderTrialLimit(
      maxCount: maxCount,
      startIndex: startPage,
      unit: ReaderTrialUnit.page,
    );
  }

  /// First [maxCount] chapters starting at [startChapter].
  factory ReaderTrialLimit.chapters(int maxCount, {int startChapter = 0}) {
    return ReaderTrialLimit(
      maxCount: maxCount,
      startIndex: startChapter,
      unit: ReaderTrialUnit.chapter,
    );
  }

  /// How many pages / chapters are readable inside the window.
  final int maxCount;

  /// First readable page / chapter index (0-based).
  final int startIndex;

  final ReaderTrialUnit unit;

  bool get isActive => maxCount > 0;

  /// Last readable index (inclusive) when there are [total] items.
  int maxReadableIndex(int total) {
    if (!isActive || total <= 0) return total - 1;
    if (startIndex >= total) return startIndex;
    final end = startIndex + maxCount;
    return (end - 1).clamp(startIndex, total - 1);
  }

  /// How many items the reader should expose (page view length, etc.).
  int visibleCount(int total) {
    if (!isActive || total <= 0) return total;
    if (startIndex >= total) return 0;
    final end = (startIndex + maxCount).clamp(0, total);
    return end - startIndex;
  }

  /// Whether more content exists after the trial window.
  bool hasMoreBeyond(int total) =>
      isActive && total > startIndex + maxCount;

  bool isReadable(int index, int total) {
    if (index < 0 || index >= total) return false;
    if (!isActive) return true;
    return index >= startIndex && index <= maxReadableIndex(total);
  }

  /// Whether [index] is the last readable slot while more content exists.
  bool atBoundary(int index, int total) =>
      hasMoreBeyond(total) && index >= maxReadableIndex(total);

  int clampIndex(int index, int total) {
    if (total <= 0) return 0;
    if (!isActive) return index.clamp(0, total - 1);
    final min = startIndex.clamp(0, total - 1);
    return index.clamp(min, maxReadableIndex(total));
  }

  /// Maps a page-view logical index to an absolute content index.
  int contentIndex(int logicalIndex) => startIndex + logicalIndex;

  /// Maps an absolute content index to a page-view logical index.
  int logicalIndex(int contentIndex) => contentIndex - startIndex;
}

/// Payload delivered to [ReaderTrialLimitCallback].
class ReaderTrialLimitEvent {
  const ReaderTrialLimitEvent({
    required this.limit,
    required this.currentIndex,
    required this.targetIndex,
    required this.totalCount,
    required this.action,
  });

  final ReaderTrialLimit limit;
  final int currentIndex;
  final int targetIndex;
  final int totalCount;
  final ReaderTrialLimitAction action;
}

typedef ReaderTrialLimitCallback = void Function(ReaderTrialLimitEvent event);

/// Legacy helper — prefer [ReaderTrialLimit.visibleCount].
int trialPageCount(int total, int? maxReadablePages) {
  if (maxReadablePages == null || maxReadablePages <= 0) return total;
  return ReaderTrialLimit.pages(maxReadablePages).visibleCount(total);
}

/// Legacy helper — prefer [ReaderTrialLimit.clampIndex].
int clampTrialPage(int page, int total, int? maxReadablePages) {
  if (maxReadablePages == null || maxReadablePages <= 0) {
    return page.clamp(0, (total - 1).clamp(0, 1 << 30));
  }
  return ReaderTrialLimit.pages(maxReadablePages).clampIndex(page, total);
}

/// Legacy helper — prefer [ReaderTrialLimit.hasMoreBeyond].
bool trialLimited(int total, int? maxReadable) =>
    maxReadable != null &&
    maxReadable > 0 &&
    ReaderTrialLimit.pages(maxReadable).hasMoreBeyond(total);

/// Legacy helper — prefer [ReaderTrialLimit.atBoundary].
bool atTrialEnd(int currentIndex, int total, int? maxReadable) {
  if (maxReadable == null || maxReadable <= 0) return false;
  return ReaderTrialLimit.pages(maxReadable)
      .atBoundary(currentIndex, total);
}
