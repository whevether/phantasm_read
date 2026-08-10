import 'reader_trial_limit.dart';

/// Debounced host callback when the user tries to leave the trial window.
class TrialGestureNotifier {
  TrialGestureNotifier({this.debounce = const Duration(milliseconds: 800)});

  final Duration debounce;
  DateTime? _lastAt;

  bool get allow {
    final now = DateTime.now();
    final last = _lastAt;
    if (last != null && now.difference(last) < debounce) return false;
    _lastAt = now;
    return true;
  }

  void call(
    ReaderTrialLimitCallback? callback, {
    required ReaderTrialLimit limit,
    required int currentIndex,
    required int targetIndex,
    required int totalCount,
    required ReaderTrialLimitAction action,
  }) {
    if (!limit.isActive || callback == null || !allow) return;
    callback(
      ReaderTrialLimitEvent(
        limit: limit,
        currentIndex: currentIndex,
        targetIndex: targetIndex,
        totalCount: totalCount,
        action: action,
      ),
    );
  }
}

/// Extra PageView page after the last readable item; landing on it means
/// the user swiped past the trial end.
bool isTrialNextSentinel({
  required int index,
  required int readableCount,
  required bool hasMoreBeyond,
}) =>
    hasMoreBeyond && readableCount > 0 && index >= readableCount;

int trialPageViewCount(int readableCount, bool hasMoreBeyond) {
  if (readableCount <= 0) return 0;
  return hasMoreBeyond ? readableCount + 1 : readableCount;
}
