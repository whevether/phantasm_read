import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../common/novel_reading_mode.dart';
import '../../common/novel_typography.dart';
import '../../common/page_curl.dart';
import '../../common/reader_font_pinch.dart';
import '../../common/trial_gesture_boundary.dart';
import '../novel_chapter.dart';
import '../novel_search.dart';
import 'text_decoder.dart';
import 'text_paginator.dart';

class TextReader extends StatefulWidget {
  const TextReader({
    super.key,
    required this.bytes,
    required this.kind,
    required this.typography,
    this.encoding,
    this.readingMode = NovelReadingMode.horizontal,
    this.backgroundColor,
    this.foregroundColor,
    this.onChaptersLoaded,
    this.jumpToParagraph,
    this.initialParagraph,
    this.initialTextOffset = 0,
    this.onParagraphChanged,
    this.highlightParagraphs = const {},
    this.rtl = false,
    this.pageTurnEffect = PageTurnEffect.curl,
    this.minParagraphIndex,
    this.maxParagraphIndex,
    this.onTrialBoundaryReached,
    this.onFontSizeChanged,
  });

  final Uint8List bytes;
  final String kind;
  final NovelTypography typography;
  final String? encoding;
  final NovelReadingMode readingMode;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final ValueChanged<List<NovelChapter>>? onChaptersLoaded;
  final int? jumpToParagraph;
  final int? initialParagraph;
  final int initialTextOffset;
  final ValueChanged<int>? onParagraphChanged;
  final Set<int> highlightParagraphs;
  final bool rtl;
  final PageTurnEffect pageTurnEffect;
  final int? minParagraphIndex;
  final int? maxParagraphIndex;

  /// Called when the user overscrolls past the trial window.
  /// Argument is `true` for next / end, `false` for previous / start.
  final ValueChanged<bool>? onTrialBoundaryReached;
  final ValueChanged<double>? onFontSizeChanged;

  @override
  State<TextReader> createState() => TextReaderState();
}

class TextReaderState extends State<TextReader> {
  final _decoder = const NovelTextDecoder();
  late Future<_TextBook> _future;
  final ScrollController _scrollController = ScrollController();
  PageController? _pageController;
  List<double> _offsets = [];
  List<double> _heights = [];
  int _loadVersion = 0;
  bool _restoreScroll = true;
  TextScaler _scaler = TextScaler.noScaling;
  TextDirection _direction = TextDirection.ltr;
  List<String> _paragraphs = [];
  List<int> _characterOffsets = [];
  int _totalCharacters = 0;
  List<List<TextFragment>> _pages = [];
  int _currentParagraph = 0;
  int _currentTextOffset = 0;
  Size? _layoutSize;
  bool _pagesReady = false;
  final TrialGestureNotifier _trialGesture = TrialGestureNotifier();

  List<String> get paragraphs => _paragraphs;
  int get currentParagraph => _currentParagraph;
  int get currentTextOffset => _currentTextOffset;
  double get characterProgress =>
      _totalCharacters == 0 || _characterOffsets.isEmpty
      ? 0
      : ((_characterOffsets[_currentParagraph.clamp(
                      0,
                      _characterOffsets.length - 1,
                    )] +
                    _currentTextOffset) /
                _totalCharacters)
            .clamp(0, 1);

  @override
  void initState() {
    super.initState();
    _currentParagraph = widget.initialParagraph ?? 0;
    _currentTextOffset = widget.initialTextOffset;
    _future = _load();
  }

  @override
  void dispose() {
    _loadVersion++;
    _scrollController.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TextReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes ||
        oldWidget.encoding != widget.encoding ||
        oldWidget.kind != widget.kind) {
      _pagesReady = false;
      _layoutSize = null;
      _restoreScroll = true;
      _currentParagraph = widget.initialParagraph ?? 0;
      _currentTextOffset = widget.initialTextOffset;
      _future = _load();
    }
    if (oldWidget.jumpToParagraph != widget.jumpToParagraph &&
        widget.jumpToParagraph != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.jumpToParagraph != null) {
          jumpToParagraph(widget.jumpToParagraph!);
        }
      });
    }
    if (oldWidget.typography != widget.typography ||
        oldWidget.readingMode != widget.readingMode ||
        oldWidget.minParagraphIndex != widget.minParagraphIndex ||
        oldWidget.maxParagraphIndex != widget.maxParagraphIndex) {
      _pagesReady = false;
      _layoutSize = null;
    }
  }

  int get _firstReadableParagraph {
    final min = widget.minParagraphIndex;
    if (min == null) return 0;
    if (_paragraphs.isEmpty) return 0;
    return min.clamp(0, _paragraphs.length - 1);
  }

  int get _lastReadableParagraph {
    final max = widget.maxParagraphIndex;
    if (max == null) return _paragraphs.length - 1;
    if (_paragraphs.isEmpty) return 0;
    return max.clamp(-1, _paragraphs.length - 1);
  }

  bool get _hasContentBeforeTrial {
    final min = widget.minParagraphIndex;
    return min != null && min > 0;
  }

  bool get _hasContentAfterTrial {
    final max = widget.maxParagraphIndex;
    return max != null &&
        _paragraphs.isNotEmpty &&
        max < _paragraphs.length - 1;
  }

  void _emitTrialBoundary(bool next) {
    final cb = widget.onTrialBoundaryReached;
    if (cb == null) return;
    if (next && !_hasContentAfterTrial) return;
    if (!next && !_hasContentBeforeTrial) return;
    if (!_trialGesture.allow) return;
    cb(next);
  }

  void _onHorizontalTrialSentinel() {
    _emitTrialBoundary(true);
    final last = _pages.length - 1;
    if (last < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = _pageController;
      if (c != null && c.hasClients) {
        c.jumpToPage(last);
      }
    });
  }

  bool _onVerticalScroll(ScrollNotification n) {
    if (widget.onTrialBoundaryReached == null) return false;
    if (n is! OverscrollNotification) return false;
    final towardNext = n.overscroll > 0;
    final towardPrev = n.overscroll < 0;
    if (!_scrollController.hasClients) return false;
    final pos = _scrollController.position;
    if (towardNext &&
        _hasContentAfterTrial &&
        pos.pixels >= pos.maxScrollExtent - 1) {
      _emitTrialBoundary(true);
    } else if (towardPrev &&
        _hasContentBeforeTrial &&
        pos.pixels <= pos.minScrollExtent + 1) {
      _emitTrialBoundary(false);
    }
    return false;
  }

  Future<_TextBook> _load() async {
    final version = ++_loadVersion;
    final kind = widget.kind;
    final raw = await _decoder.decodeBytes(
      widget.bytes,
      encoding: widget.encoding,
    );
    final content = _decoder.normalizeContent(raw, kind: kind);
    final paragraphs = content
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final chapters = _detectChapters(paragraphs);
    if (mounted && version == _loadVersion) {
      _paragraphs = paragraphs;
      _characterOffsets = [];
      _totalCharacters = 0;
      for (final paragraph in paragraphs) {
        _characterOffsets.add(_totalCharacters);
        _totalCharacters += paragraph.length;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && version == _loadVersion) {
          widget.onChaptersLoaded?.call(chapters);
        }
      });
    }
    return _TextBook(paragraphs: paragraphs);
  }

  List<NovelChapter> _detectChapters(List<String> paragraphs) {
    final chapterRe = RegExp(
      r'^(第[\d一二三四五六七八九十百千零两]+[章节回部卷]|Chapter\s+\d+|#\s+.+)',
      caseSensitive: false,
    );
    final out = <NovelChapter>[];
    for (var i = 0; i < paragraphs.length; i++) {
      final line = paragraphs[i].split('\n').first.trim();
      if (chapterRe.hasMatch(line)) {
        out.add(NovelChapter(title: line, href: '', anchorIndex: i));
      }
    }
    return out;
  }

  void _ensureHorizontalPages(Size size) {
    if (_pagesReady && _layoutSize == size) return;
    _layoutSize = size;
    final style = _textStyle(widget.foregroundColor ?? const Color(0xFF222222));
    final margin = widget.typography.pageMargin;
    final readable = _paragraphs.sublist(
      _firstReadableParagraph,
      _lastReadableParagraph + 1,
    );
    _pages = paginateText(
      paragraphs: readable,
      pageSize: size,
      style: style,
      padding: _pagePadding(margin),
      textScaler: _scaler,
      textDirection: _direction,
      textAlign: _align,
      startIndex: _firstReadableParagraph,
    );
    final pageIndex = _pageIndexForParagraph(_currentParagraph);
    final old = _pageController;
    _pageController = PageController(initialPage: pageIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    _pagesReady = true;
  }

  int _pageIndexForParagraph(int paragraphIndex) {
    final i = _pages.indexWhere(
      (p) => p.any(
        (f) =>
            f.paragraphIndex == paragraphIndex &&
            f.endOffset > _currentTextOffset,
      ),
    );
    return i < 0 ? (_pages.isEmpty ? 0 : _pages.length - 1) : i;
  }

  int _paragraphForPage(int index) => _pages[index].first.paragraphIndex;

  EdgeInsets _pagePadding(double margin) => EdgeInsets.all(margin);

  void _ensureVerticalLayout(Size size, TextStyle style, double margin) {
    if (_layoutSize == size && _heights.length == _paragraphs.length) return;
    _layoutSize = size;
    _offsets = [];
    _heights = [];
    var offset = 0.0;
    for (var i = 0; i < _paragraphs.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: _paragraphs[i], style: style),
        textAlign: _align,
        textDirection: _direction,
        textScaler: _scaler,
      );
      painter.layout(
        maxWidth: (size.width - margin * 2).clamp(1.0, double.infinity),
      );
      final height = painter.height + widget.typography.fontSize * 0.8;
      painter.dispose();
      _offsets.add(offset);
      _heights.add(height);
      offset += height;
    }
    _restoreScroll = true;
  }

  double _offsetForParagraph(int i) =>
      _offsets[i] - _offsets[_firstReadableParagraph];

  void _reportVerticalPosition() {
    if (!_scrollController.hasClients || _offsets.isEmpty) return;
    final offset = _scrollController.offset + _offsets[_firstReadableParagraph];
    var lo = _firstReadableParagraph, hi = _lastReadableParagraph;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_offsets[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    if (_currentParagraph != lo) {
      _currentParagraph = lo;
      widget.onParagraphChanged?.call(lo);
    }
  }

  /// Continuous scrolling is awaited so auto-reading never overlaps animations.
  Future<bool> scrollBy(double pixels) async {
    if (!_scrollController.hasClients) return false;
    final position = _scrollController.position;
    final target = (position.pixels + pixels).clamp(
      0.0,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 0.1) return false;
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 80),
      curve: Curves.linear,
    );
    return true;
  }

  Future<void> jumpToParagraph(int index) async {
    if (_paragraphs.isEmpty ||
        _firstReadableParagraph > _lastReadableParagraph) {
      return;
    }
    final i = index.clamp(_firstReadableParagraph, _lastReadableParagraph);
    _currentParagraph = i;
    _currentTextOffset = 0;
    widget.onParagraphChanged?.call(i);
    if (widget.readingMode == NovelReadingMode.horizontal) {
      final page = _pageIndexForParagraph(i);
      if (_pageController?.hasClients ?? false) {
        await _pageController!.animateToPage(
          page,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    if (_scrollController.hasClients && _offsets.isNotEmpty) {
      await _scrollController.animateTo(
        _offsetForParagraph(i)
            .clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<bool> nextPage() async {
    if (widget.readingMode == NovelReadingMode.horizontal) {
      if (_pageController?.hasClients ?? false) {
        final page = _pageController!.page?.round() ?? 0;
        if (page >= _pages.length - 1) return false;
        await _pageController!.nextPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      return true;
    }
    if (_paragraphs.isEmpty) return false;
    if (_currentParagraph >= _lastReadableParagraph) return false;
    await jumpToParagraph(_currentParagraph + 1);
    return true;
  }

  Future<void> prevPage() async {
    if (widget.readingMode == NovelReadingMode.horizontal) {
      if (_pageController?.hasClients ?? false) {
        await _pageController!.previousPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    if (_paragraphs.isEmpty) return;
    await jumpToParagraph(
      (_currentParagraph - 1).clamp(0, _paragraphs.length - 1),
    );
  }

  List<NovelSearchHit> search(String query, {List<NovelChapter>? chapters}) {
    return searchParagraphs(_paragraphs, query: query, chapters: chapters);
  }

  TextStyle _textStyle(Color fg) {
    return DefaultTextStyle.of(context).style.copyWith(
      fontSize: widget.typography.fontSize,
      height: widget.typography.lineHeight,
      fontFamily: widget.typography.fontFamily,
      letterSpacing: widget.typography.letterSpacing,
      color: fg,
    );
  }

  TextAlign get _align => widget.typography.textAlign == TextAlignOption.justify
      ? TextAlign.justify
      : TextAlign.left;

  Widget _buildHorizontalPage(
    int index,
    TextStyle style,
    double margin,
    Color bg,
  ) {
    return ColoredBox(
      color: bg,
      child: Padding(
        padding: _pagePadding(margin),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < _pages[index].length; j++) ...[
                if (j > 0) SizedBox(height: widget.typography.fontSize * 0.8),
                ColoredBox(
                  color:
                      widget.highlightParagraphs.contains(
                        _pages[index][j].paragraphIndex,
                      )
                      ? const Color(0x66FFEB3B)
                      : Colors.transparent,
                  child: Text(
                    _pages[index][j].text,
                    style: style,
                    textAlign: _align,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrapFontPinch(Widget child) {
    final onChanged = widget.onFontSizeChanged;
    if (onChanged == null) return child;
    return ReaderFontPinchGesture(
      fontSize: widget.typography.fontSize,
      onFontSizeChanged: onChanged,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? const Color(0xFFFFF8E7);
    final fg = widget.foregroundColor ?? const Color(0xFF222222);
    final style = _textStyle(fg);
    final margin = widget.typography.pageMargin;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    if (_scaler != scaler || _direction != direction) {
      _scaler = scaler;
      _direction = direction;
      _layoutSize = null;
      _pagesReady = false;
    }

    return ColoredBox(
      color: bg,
      child: FutureBuilder<_TextBook>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Load failed: ${snapshot.error}'));
          }
          final book = snapshot.data!;
          if (book.paragraphs.isEmpty) {
            return const Center(child: Text('Empty document'));
          }
          _paragraphs = book.paragraphs;

          final visibleStart = _firstReadableParagraph;
          final visibleCount = (_lastReadableParagraph - visibleStart + 1)
              .clamp(0, _paragraphs.length);
          if (visibleCount == 0) {
            return const Center(child: Text('No readable content'));
          }

          _currentParagraph = _currentParagraph.clamp(
            _firstReadableParagraph,
            _lastReadableParagraph,
          );

          if (widget.readingMode == NovelReadingMode.horizontal) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                if (size.width <= 0 || size.height <= 0) {
                  return const Center(child: CircularProgressIndicator());
                }
                _ensureHorizontalPages(size);
                if (!_pagesReady || _pages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final pageCount = trialPageViewCount(
                  _pages.length,
                  _hasContentAfterTrial,
                );
                return _wrapFontPinch(
                  CurlPageView(
                    key: ValueKey(Object.hash(pageCount, _layoutSize)),
                    controller: _pageController,
                    reverse: widget.rtl,
                    effect: widget.pageTurnEffect,
                    itemCount: pageCount,
                    onPageChanged: (page) {
                      if (isTrialNextSentinel(
                        index: page,
                        readableCount: _pages.length,
                        hasMoreBeyond: _hasContentAfterTrial,
                      )) {
                        _onHorizontalTrialSentinel();
                        return;
                      }
                      final p = _paragraphForPage(page);
                      _currentParagraph = p;
                      _currentTextOffset = _pages[page].first.startOffset;
                      widget.onParagraphChanged?.call(p);
                    },
                    itemBuilder: (context, index) {
                      if (isTrialNextSentinel(
                        index: index,
                        readableCount: _pages.length,
                        hasMoreBeyond: _hasContentAfterTrial,
                      )) {
                        return ColoredBox(color: bg);
                      }
                      return _buildHorizontalPage(index, style, margin, bg);
                    },
                  ),
                );
              },
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              _ensureVerticalLayout(
                Size(constraints.maxWidth, constraints.maxHeight),
                style,
                margin,
              );
              if (_restoreScroll) {
                _restoreScroll = false;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_scrollController.hasClients) return;
                  final i = _currentParagraph.clamp(
                    _firstReadableParagraph,
                    _lastReadableParagraph,
                  );
                  _scrollController.jumpTo(
                    _offsetForParagraph(i)
                        .clamp(0.0, _scrollController.position.maxScrollExtent),
                  );
                });
              }
              return _wrapFontPinch(
                NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollUpdateNotification) {
                      _reportVerticalPosition();
                    }
                    return _onVerticalScroll(n);
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: margin),
                    itemCount: visibleCount,
                    itemExtentBuilder: (i, _) => _heights[visibleStart + i],
                    itemBuilder: (context, i) {
                      final index = visibleStart + i;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: widget.typography.fontSize * 0.8,
                        ),
                        child: ColoredBox(
                          color: widget.highlightParagraphs.contains(index)
                              ? const Color(0x66FFEB3B)
                              : Colors.transparent,
                          child: SelectableText(
                            book.paragraphs[index],
                            style: style,
                            textAlign: _align,
                            onTap: () {
                              _currentParagraph = index;
                              widget.onParagraphChanged?.call(index);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TextBook {
  const _TextBook({required this.paragraphs});
  final List<String> paragraphs;
}
