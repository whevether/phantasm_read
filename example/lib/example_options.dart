import 'package:flutter/foundation.dart';
import 'package:phantasm_read/phantasm_read.dart';

import 'trial_feedback.dart';

/// 示例应用高级功能开关（常用阅读能力默认开启，见各 Reader 构造参数）。
class ExampleReaderOptions extends ChangeNotifier {
  // —— 漫画 ——
  bool comicWatermark = false;
  bool comicInk = false;
  bool comicTrial = true;
  int comicTrialPages = 3;
  int comicTrialStartPage = 0;
  bool comicSync = false;
  bool comicRtl = false;
  bool comicDoublePage = false;
  PageTurnEffect comicPageTurn = PageTurnEffect.none;

  // —— 小说 ——
  bool novelWatermark = false;
  bool novelInk = false;
  bool novelHighlight = false;
  bool novelSync = false;
  bool novelTrial = true;
  int novelTrialChapters = 3;
  int novelTrialStartChapter = 0;
  bool novelRtl = false;
  bool novelMediaOverlay = false;

  // —— PDF ——
  bool pdfWatermark = false;
  bool pdfTrial = true;
  int pdfTrialPages = 3;
  int pdfTrialStartPage = 0;
  double pdfRasterDpi = 120;

  /// 试读触顶时示例应用的反馈方式（插件本身不展示 UI）。
  ExampleTrialFeedback trialFeedback = ExampleTrialFeedback.dialog;

  void setComicWatermark(bool v) {
    comicWatermark = v;
    notifyListeners();
  }

  void setComicInk(bool v) {
    comicInk = v;
    notifyListeners();
  }

  void setComicTrial(bool v) {
    comicTrial = v;
    notifyListeners();
  }

  void setComicTrialPages(int v) {
    comicTrialPages = v;
    notifyListeners();
  }

  void setComicTrialStartPage(int v) {
    comicTrialStartPage = v;
    notifyListeners();
  }

  void setComicSync(bool v) {
    comicSync = v;
    notifyListeners();
  }

  void setComicRtl(bool v) {
    comicRtl = v;
    notifyListeners();
  }

  void setComicDoublePage(bool v) {
    comicDoublePage = v;
    notifyListeners();
  }

  void setComicPageTurn(PageTurnEffect v) {
    comicPageTurn = v;
    notifyListeners();
  }

  void setNovelWatermark(bool v) {
    novelWatermark = v;
    notifyListeners();
  }

  void setNovelInk(bool v) {
    novelInk = v;
    notifyListeners();
  }

  void setNovelHighlight(bool v) {
    novelHighlight = v;
    notifyListeners();
  }

  void setNovelSync(bool v) {
    novelSync = v;
    notifyListeners();
  }

  void setNovelTrial(bool v) {
    novelTrial = v;
    notifyListeners();
  }

  void setNovelTrialChapters(int v) {
    novelTrialChapters = v;
    notifyListeners();
  }

  void setNovelTrialStartChapter(int v) {
    novelTrialStartChapter = v;
    notifyListeners();
  }

  void setNovelRtl(bool v) {
    novelRtl = v;
    notifyListeners();
  }

  void setPdfWatermark(bool v) {
    pdfWatermark = v;
    notifyListeners();
  }

  void setPdfTrial(bool v) {
    pdfTrial = v;
    notifyListeners();
  }

  void setPdfTrialPages(int v) {
    pdfTrialPages = v;
    notifyListeners();
  }

  void setPdfTrialStartPage(int v) {
    pdfTrialStartPage = v;
    notifyListeners();
  }

  void setPdfRasterDpi(double v) {
    pdfRasterDpi = v;
    notifyListeners();
  }

  void setTrialFeedback(ExampleTrialFeedback v) {
    trialFeedback = v;
    notifyListeners();
  }

  String? get comicWatermarkText =>
      comicWatermark ? 'phantasm_read · demo' : null;

  String? get novelWatermarkText =>
      novelWatermark ? 'phantasm_read · novel' : null;

  String? get pdfWatermarkText =>
      pdfWatermark ? 'phantasm_read · pdf' : null;

  ReaderTrialLimit? get comicTrialLimit => comicTrial
      ? ReaderTrialLimit.pages(
          comicTrialPages,
          startPage: comicTrialStartPage,
        )
      : null;

  ReaderTrialLimit? get novelTrialLimit => novelTrial
      ? ReaderTrialLimit.chapters(
          novelTrialChapters,
          startChapter: novelTrialStartChapter,
        )
      : null;

  ReaderTrialLimit? get pdfTrialLimit => pdfTrial
      ? ReaderTrialLimit.pages(
          pdfTrialPages,
          startPage: pdfTrialStartPage,
        )
      : null;
}
