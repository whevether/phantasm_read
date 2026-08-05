import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../common/novel_reading_mode.dart';
import '../../common/novel_typography.dart';
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
    this.readingMode = NovelReadingMode.vertical,
    this.backgroundColor,
    this.foregroundColor,
    this.onChaptersLoaded,
    this.jumpToParagraph,
    this.initialParagraph,
    this.onParagraphChanged,
    this.highlightParagraphs = const {},
    this.rtl = false,
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
  final ValueChanged<int>? onParagraphChanged;
  final Set<int> highlightParagraphs;
  final bool rtl;

  @override
  State<TextReader> createState() => TextReaderState();
}

class TextReaderState extends State<TextReader> {
  final _decoder = const NovelTextDecoder();
  late Future<_TextBook> _future;
  final ScrollController _scrollController = ScrollController();
  PageController? _pageController;
  List<GlobalKey> _paragraphKeys = [];
  List<String> _paragraphs = [];
  List<List<String>> _pages = [];
  int _currentParagraph = 0;
  bool _pagesReady = false;

  List<String> get paragraphs => _paragraphs;
  int get currentParagraph => _currentParagraph;

  @override
  void initState() {
    super.initState();
    _currentParagraph = widget.initialParagraph ?? 0;
    _future = _load();
  }

  @override
  void dispose() {
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
      _future = _load();
    }
    if (oldWidget.jumpToParagraph != widget.jumpToParagraph &&
        widget.jumpToParagraph != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        jumpToParagraph(widget.jumpToParagraph!);
      });
    }
    if (oldWidget.typography != widget.typography ||
        oldWidget.readingMode != widget.readingMode) {
      _pagesReady = false;
    }
  }

  Future<_TextBook> _load() async {
    final raw = await _decoder.decodeBytes(
      widget.bytes,
      encoding: widget.encoding,
    );
    final content = _decoder.normalizeContent(raw, kind: widget.kind);
    final paragraphs = content
        .split(RegExp(r'\n\s*\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final chapters = _detectChapters(paragraphs);
    _paragraphs = paragraphs;
    _paragraphKeys = List.generate(paragraphs.length, (_) => GlobalKey());
    widget.onChaptersLoaded?.call(chapters);
    return _TextBook(paragraphs: paragraphs, chapters: chapters);
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

  void _rebuildPages(BuildContext context) {
    if (widget.readingMode != NovelReadingMode.horizontal) {
      _pagesReady = true;
      return;
    }
    final size = MediaQuery.sizeOf(context);
    final style = _textStyle(
      widget.foregroundColor ?? const Color(0xFF222222),
    );
    final margin = widget.typography.pageMargin;
    _pages = paginateParagraphs(
      paragraphs: _paragraphs,
      pageSize: size,
      style: style,
      padding: EdgeInsets.all(margin),
    );
    final pageIndex = _pageIndexForParagraph(_currentParagraph);
    _pageController?.dispose();
    _pageController = PageController(initialPage: pageIndex);
    _pagesReady = true;
  }

  int _pageIndexForParagraph(int paragraphIndex) {
    var count = 0;
    for (var i = 0; i < _pages.length; i++) {
      final next = count + _pages[i].length;
      if (paragraphIndex < next) return i;
      count = next;
    }
    return (_pages.isEmpty ? 0 : _pages.length - 1);
  }

  int _paragraphForPage(int pageIndex) {
    var count = 0;
    for (var i = 0; i < pageIndex && i < _pages.length; i++) {
      count += _pages[i].length;
    }
    if (_paragraphs.isEmpty) return 0;
    return count.clamp(0, _paragraphs.length - 1);
  }

  Future<void> jumpToParagraph(int index) async {
    if (_paragraphs.isEmpty) return;
    final i = index.clamp(0, _paragraphs.length - 1);
    _currentParagraph = i;
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
    if (i >= _paragraphKeys.length) return;
    final ctx = _paragraphKeys[i].currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        alignment: 0.05,
      );
    }
  }

  Future<void> nextPage() async {
    if (widget.readingMode == NovelReadingMode.horizontal) {
      if (_pageController?.hasClients ?? false) {
        await _pageController!.nextPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    if (_paragraphs.isEmpty) return;
    await jumpToParagraph(
      (_currentParagraph + 1).clamp(0, _paragraphs.length - 1),
    );
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
    return TextStyle(
      fontSize: widget.typography.fontSize,
      height: widget.typography.lineHeight,
      fontFamily: widget.typography.fontFamily,
      letterSpacing: widget.typography.letterSpacing,
      color: fg,
    );
  }

  TextAlign get _align =>
      widget.typography.textAlign == TextAlignOption.justify
          ? TextAlign.justify
          : TextAlign.left;

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? const Color(0xFFFFF8E7);
    final fg = widget.foregroundColor ?? const Color(0xFF222222);
    final style = _textStyle(fg);
    final margin = widget.typography.pageMargin;

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

          if (widget.readingMode == NovelReadingMode.horizontal) {
            if (!_pagesReady) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _rebuildPages(context));
              });
              return const Center(child: CircularProgressIndicator());
            }
            return PageView.builder(
              controller: _pageController,
              reverse: widget.rtl,
              itemCount: _pages.length,
              onPageChanged: (page) {
                final p = _paragraphForPage(page);
                _currentParagraph = p;
                widget.onParagraphChanged?.call(p);
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.all(margin),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final para in _pages[index]) ...[
                          Text(para, style: style, textAlign: _align),
                          SizedBox(height: widget.typography.fontSize * 0.8),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          }

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(margin, 24, margin, 48),
                sliver: SliverList.separated(
                  itemCount: book.paragraphs.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: widget.typography.fontSize * 0.8),
                  itemBuilder: (context, index) {
                    final highlighted =
                        widget.highlightParagraphs.contains(index);
                    return KeyedSubtree(
                      key: _paragraphKeys[index],
                      child: Container(
                        color: highlighted
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
            ],
          );
        },
      ),
    );
  }
}

class _TextBook {
  const _TextBook({required this.paragraphs, required this.chapters});
  final List<String> paragraphs;
  final List<NovelChapter> chapters;
}
