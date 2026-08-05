import 'package:flutter/material.dart';

import '../../common/novel_typography.dart';
import 'text_decoder.dart';

class TextReader extends StatefulWidget {
  const TextReader({
    super.key,
    required this.filePath,
    required this.kind,
    required this.typography,
    this.encoding,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String filePath;
  final String kind; // text | markdown | html
  final NovelTypography typography;
  final String? encoding;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  State<TextReader> createState() => _TextReaderState();
}

class _TextReaderState extends State<TextReader> {
  final _decoder = const NovelTextDecoder();
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant TextReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.encoding != widget.encoding ||
        oldWidget.kind != widget.kind) {
      _future = _load();
    }
  }

  Future<String> _load() async {
    final raw = await _decoder.decodeFile(
      widget.filePath,
      encoding: widget.encoding,
    );
    return _decoder.normalizeContent(raw, kind: widget.kind);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? const Color(0xFFFFF8E7);
    final fg = widget.foregroundColor ?? const Color(0xFF222222);

    return ColoredBox(
      color: bg,
      child: FutureBuilder<String>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Load failed: ${snapshot.error}'));
          }
          final text = snapshot.data ?? '';
          final paragraphs = text
              .split(RegExp(r'\n\s*\n'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                sliver: SliverList.separated(
                  itemCount: paragraphs.length,
                  separatorBuilder: (_, _) => SizedBox(
                    height: widget.typography.fontSize * 0.8,
                  ),
                  itemBuilder: (context, index) {
                    return Text(
                      paragraphs[index],
                      style: TextStyle(
                        fontSize: widget.typography.fontSize,
                        height: widget.typography.lineHeight,
                        fontFamily: widget.typography.fontFamily,
                        color: fg,
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
