import 'reader_trial_limit.dart';

/// One conversion for comic/PDF absolute pages, spreads and preview windows.
class ReaderPageWindow {
  const ReaderPageWindow(this.total, {this.trial, this.doublePage = false});
  final int total;
  final ReaderTrialLimit? trial;
  final bool doublePage;
  int get start => trial?.isActive == true ? trial!.startIndex : 0;
  int get visible => trial?.visibleCount(total) ?? total;
  int get count => doublePage ? (visible + 1) ~/ 2 : visible;
  int content(int logical) => total <= 0
      ? 0
      : (start + logical * (doublePage ? 2 : 1)).clamp(0, total - 1);
  int logical(int content) => count <= 0
      ? 0
      : ((content - start) ~/ (doublePage ? 2 : 1)).clamp(0, count - 1);
  bool readable(int index) =>
      index >= 0 && index < total && (trial?.isReadable(index, total) ?? true);
}
