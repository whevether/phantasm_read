import 'package:flutter/material.dart';

import '../common/novel_reading_mode.dart';
import '../common/reader_brightness.dart';
import '../common/reader_lifecycle.dart';
import '../common/reader_settings.dart';
import '../common/reader_wake_lock.dart';
import 'epub/epub_viewer.dart';
import 'novel_chapter.dart';
import 'novel_source.dart';
import 'text/text_reader.dart';

/// Novel reader for EPUB and common text formats.
class NovelReader extends StatefulWidget {
  const NovelReader({
    super.key,
    required this.source,
    this.settings = const ReaderSettings(),
    this.encoding,
    this.initialCfi,
    this.onSettingsChanged,
    this.onLocationChanged,
    this.onChaptersLoaded,
    this.showToolbar = true,
  });

  final NovelSource source;
  final ReaderSettings settings;
  final String? encoding;
  final String? initialCfi;
  final ValueChanged<ReaderSettings>? onSettingsChanged;
  final ValueChanged<String?>? onLocationChanged;
  final ValueChanged<List<NovelChapter>>? onChaptersLoaded;
  final bool showToolbar;

  @override
  State<NovelReader> createState() => _NovelReaderState();
}

class _NovelReaderState extends State<NovelReader>
    with WidgetsBindingObserver {
  late final ReaderBrightness _brightness = ReaderBrightness();
  late ReaderSettings _settings;
  final EpubViewerController _epubController = EpubViewerController();
  final GlobalKey<TextReaderState> _textKey = GlobalKey<TextReaderState>();
  bool _toolbarVisible = false;
  List<NovelChapter> _chapters = const [];
  int? _jumpToParagraph;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    WidgetsBinding.instance.addObserver(this);
    _enterReading();
  }

  Future<void> _enterReading() async {
    await _brightness.apply(_settings.brightness);
    if (_settings.keepScreenOn) {
      await ReaderWakeLock.enable();
    }
  }

  Future<void> _leaveReading() async {
    await _brightness.restore();
    await ReaderWakeLock.disable();
  }

  @override
  void didUpdateWidget(covariant NovelReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _settings = widget.settings;
      _brightness.apply(_settings.brightness);
      if (_settings.keepScreenOn) {
        ReaderWakeLock.enable();
      } else {
        ReaderWakeLock.disable();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ReaderWakeLock.disable();
    } else if (state == AppLifecycleState.resumed && _settings.keepScreenOn) {
      ReaderWakeLock.enable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _leaveReading();
    _brightness.dispose();
    super.dispose();
  }

  void _emitSettings(ReaderSettings next) {
    setState(() => _settings = next);
    _brightness.apply(next.brightness);
    if (next.keepScreenOn) {
      ReaderWakeLock.enable();
    } else {
      ReaderWakeLock.disable();
    }
    widget.onSettingsChanged?.call(next);
  }

  Color? _color(int? value) => value == null ? null : Color(value);

  void _onChapters(List<NovelChapter> chapters) {
    setState(() => _chapters = chapters);
    widget.onChaptersLoaded?.call(chapters);
  }

  Future<void> _openChapterSheet() async {
    final chapters = _chapters.isNotEmpty
        ? _chapters
        : (widget.source is NovelSourceEpub
            ? await _epubController.getChapters()
            : _chapters);
    if (!mounted) return;
    if (chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无章节目录')),
      );
      return;
    }

    final flat = <NovelChapter>[];
    for (final c in chapters) {
      flat.addAll(c.flattened);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('选择章节', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: flat.length,
                    itemBuilder: (context, index) {
                      final chapter = flat[index];
                      return ListTile(
                        title: Text(chapter.title),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _goToChapter(chapter);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _goToChapter(NovelChapter chapter) async {
    if (widget.source is NovelSourceEpub) {
      if (chapter.href.isNotEmpty) {
        await _epubController.goToChapter(chapter.href);
      }
      return;
    }
    final index = chapter.anchorIndex;
    if (index == null) return;
    setState(() => _jumpToParagraph = index);
    await _textKey.currentState?.jumpToParagraph(index);
  }

  Widget _buildContent() {
    final source = widget.source;
    final bg = _color(_settings.backgroundColor);
    final fg = _color(_settings.foregroundColor);
    final mode = _settings.novelReadingMode;

    return switch (source) {
      NovelSourceEpub(:final path) => EpubViewer(
          filePath: path,
          controller: _epubController,
          typography: _settings.typography,
          initialCfi: widget.initialCfi,
          readingMode: mode,
          backgroundColor: bg,
          foregroundColor: fg,
          onLocationChanged: widget.onLocationChanged,
          onChaptersLoaded: _onChapters,
        ),
      NovelSourceText(:final path) => TextReader(
          key: _textKey,
          filePath: path,
          kind: 'text',
          typography: _settings.typography,
          encoding: widget.encoding,
          readingMode: mode,
          backgroundColor: bg,
          foregroundColor: fg,
          onChaptersLoaded: _onChapters,
          jumpToParagraph: _jumpToParagraph,
        ),
      NovelSourceMarkdown(:final path) => TextReader(
          key: _textKey,
          filePath: path,
          kind: 'markdown',
          typography: _settings.typography,
          encoding: widget.encoding,
          readingMode: mode,
          backgroundColor: bg,
          foregroundColor: fg,
          onChaptersLoaded: _onChapters,
          jumpToParagraph: _jumpToParagraph,
        ),
      NovelSourceHtml(:final path) => TextReader(
          key: _textKey,
          filePath: path,
          kind: 'html',
          typography: _settings.typography,
          encoding: widget.encoding,
          readingMode: mode,
          backgroundColor: bg,
          foregroundColor: fg,
          onChaptersLoaded: _onChapters,
          jumpToParagraph: _jumpToParagraph,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _brightness,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (!widget.showToolbar) return;
                setState(() => _toolbarVisible = !_toolbarVisible);
              },
              child: _buildContent(),
            ),
            BrightnessOverlay(
              brightness: _brightness.value,
              mode: _brightness.mode,
            ),
            if (widget.showToolbar && _toolbarVisible)
              _NovelToolbar(
                settings: _settings,
                hasChapters: _chapters.isNotEmpty || widget.source is NovelSourceEpub,
                onSettingsChanged: _emitSettings,
                onSelectChapter: _openChapterSheet,
              ),
          ],
        );
      },
    );
  }
}

class _NovelToolbar extends StatelessWidget {
  const _NovelToolbar({
    required this.settings,
    required this.hasChapters,
    required this.onSettingsChanged,
    required this.onSelectChapter,
  });

  final ReaderSettings settings;
  final bool hasChapters;
  final ValueChanged<ReaderSettings> onSettingsChanged;
  final VoidCallback onSelectChapter;

  @override
  Widget build(BuildContext context) {
    final t = settings.typography;
    final mode = settings.novelReadingMode;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Colors.black54,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.brightness_6, color: Colors.white, size: 18),
                    Expanded(
                      child: Slider(
                        value: settings.brightness,
                        onChanged: (v) =>
                            onSettingsChanged(settings.copyWith(brightness: v)),
                      ),
                    ),
                    IconButton(
                      tooltip: '阅读方向',
                      onPressed: () => onSettingsChanged(
                        settings.copyWith(
                          novelReadingMode: mode == NovelReadingMode.vertical
                              ? NovelReadingMode.horizontal
                              : NovelReadingMode.vertical,
                        ),
                      ),
                      icon: Icon(
                        mode == NovelReadingMode.vertical
                            ? Icons.swap_vert
                            : Icons.swap_horiz,
                        color: Colors.white,
                      ),
                    ),
                    if (hasChapters)
                      IconButton(
                        tooltip: '选择章节',
                        onPressed: onSelectChapter,
                        icon: const Icon(Icons.list_alt, color: Colors.white),
                      ),
                    IconButton(
                      tooltip: 'Keep screen on',
                      onPressed: () => onSettingsChanged(
                        settings.copyWith(keepScreenOn: !settings.keepScreenOn),
                      ),
                      icon: Icon(
                        settings.keepScreenOn
                            ? Icons.phonelink_lock
                            : Icons.phonelink_erase,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('A-', style: TextStyle(color: Colors.white)),
                    Expanded(
                      child: Slider(
                        min: 12,
                        max: 36,
                        value: t.fontSize.clamp(12, 36),
                        onChanged: (v) => onSettingsChanged(
                          settings.copyWith(
                            typography: t.copyWith(fontSize: v),
                          ),
                        ),
                      ),
                    ),
                    const Text('A+', style: TextStyle(color: Colors.white)),
                  ],
                ),
                Row(
                  children: [
                    const Text('行距', style: TextStyle(color: Colors.white, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        min: 1.2,
                        max: 2.4,
                        value: t.lineHeight.clamp(1.2, 2.4),
                        onChanged: (v) => onSettingsChanged(
                          settings.copyWith(
                            typography: t.copyWith(lineHeight: v),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '背景',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final preset in NovelThemePreset.defaults)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => onSettingsChanged(
                              settings.copyWith(
                                backgroundColor: preset.background,
                                foregroundColor: preset.foreground,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Color(preset.background),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: settings.backgroundColor == preset.background
                                      ? Colors.white
                                      : Colors.white54,
                                  width: settings.backgroundColor == preset.background
                                      ? 2
                                      : 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
