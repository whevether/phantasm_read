import 'package:flutter/material.dart';

import '../../common/novel_reading_mode.dart';
import '../../common/novel_typography.dart';
import '../novel_chapter.dart';
import 'text_decoder.dart';

class TextReader extends StatefulWidget {
  const TextReader({
    super.key,
    required this.filePath,
    required this.kind,
    required this.typography,
    this.encoding,
    this.readingMode = NovelReadingMode.vertical,
    this.backgroundColor,
    this.foregroundColor,
    this.onChaptersLoaded,
    this.jumpToParagraph,
  });

  final String filePath;
  final String kind; // text | markdown | html
  final NovelTypography typography;
  final String? encoding;
  final NovelReadingMode readingMode;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final ValueChanged<List<NovelChapter>>? onChaptersLoaded;
  final int? jumpToParagraph;

  @override
  State<TextReader> createState() => TextReaderState();
}

class TextReaderState extends State<TextReader> {
  final _decoder = const NovelTextDecoder();
  late Future<_TextBook> _future;
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  List<GlobalKey> _paragraphKeys = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TextReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.encoding != widget.encoding ||
        oldWidget.kind != widget.kind) {
      _future = _load();
    }
    if (oldWidget.jumpToParagraph != widget.jumpToParagraph &&
        widget.jumpToParagraph != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        jumpToParagraph(widget.jumpToParagraph!);
      });
    }
  }

  Future<_TextBook> _load() async {
    final raw = await _decoder.decodeFile(
      widget.filePath,
      encoding: widget.encoding,
    );
    final content = _decoder.normalizeContent(raw, kind: widget.kind);
    final paragraphs = content
        .split(RegExp(r'\n\s*\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final chapters = _detectChapters(paragraphs);
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

  Future<void> jumpToParagraph(int index) async {
    if (index < 0) return;
    if (widget.readingMode == NovelReadingMode.horizontal) {
      if (_pageController.hasClients) {
        await _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    if (index >= _paragraphKeys.length) return;
    final ctx = _paragraphKeys[index].currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        alignment: 0.05,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? const Color(0xFFFFF8E7);
    final fg = widget.foregroundColor ?? const Color(0xFF222222);
    final style = TextStyle(
      fontSize: widget.typography.fontSize,
      height: widget.typography.lineHeight,
      fontFamily: widget.typography.fontFamily,
      color: fg,
    );

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

          if (widget.readingMode == NovelReadingMode.horizontal) {
            return PageView.builder(
              controller: _pageController,
              itemCount: book.paragraphs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                  child: SingleChildScrollView(
                    child: Text(book.paragraphs[index], style: style),
                  ),
                );
              },
            );
          }

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                sliver: SliverList.separated(
                  itemCount: book.paragraphs.length,
                  separatorBuilder: (_, _) => SizedBox(
                    height: widget.typography.fontSize * 0.8,
                  ),
                  itemBuilder: (context, index) {
                    return KeyedSubtree(
                      key: _paragraphKeys[index],
                      child: Text(book.paragraphs[index], style: style),
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
