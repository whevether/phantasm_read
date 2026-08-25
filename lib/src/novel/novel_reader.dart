import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../audio/novel_tts.dart';
import '../common/ink_annotation.dart';
import '../common/novel_reading_mode.dart';
import '../common/novel_typography.dart';
import '../common/page_curl.dart';
import '../common/reader_bookmark.dart';
import '../common/reader_brightness.dart';
import '../common/reader_lifecycle.dart';
import '../common/reader_progress.dart';
import '../common/reader_settings.dart';
import '../common/reader_settings_store.dart';
import '../common/reader_sync.dart';
import '../common/reader_trial_limit.dart';
import '../common/reader_wake_lock.dart';
import '../common/reader_watermark.dart';
import '../common/tap_zones.dart';
import '../common/trial_gesture_boundary.dart';
import '../audio/media_overlay.dart';
import 'epub/epub_viewer.dart';
import 'novel_chapter.dart';
import 'novel_search.dart';
import 'novel_source.dart';
import 'text/text_reader.dart';

/// Novel reader for EPUB and common text formats.
class NovelReader extends StatefulWidget {
  const NovelReader({
    super.key,
    required this.source,
    this.bookId,
    this.settings = const ReaderSettings(),
    this.encoding,
    this.initialCfi,
    this.persistProgress = true,
    this.persistSettings = true,
    this.trialLimit,
    this.onTrialLimitReached,
    this.watermarkText,
    this.enableInk = false,
    this.enableHighlights = true,
    this.mediaOverlayCues = const [],
    this.mediaOverlaySource,
    this.onSettingsChanged,
    this.onLocationChanged,
    this.onChaptersLoaded,
    this.onChapterChanged,
    this.onSessionTick,
    this.onSync,
    this.onKaraokeCue,
    this.showToolbar = true,
    this.rtl = false,
    this.pageTurnEffect = PageTurnEffect.curl,
    this.ttsEngine,
  });

  final NovelSource source;
  final String? bookId;
  final ReaderSettings settings;
  final String? encoding;
  final String? initialCfi;
  final bool persistProgress;
  final bool persistSettings;
  final ReaderTrialLimit? trialLimit;
  final ReaderTrialLimitCallback? onTrialLimitReached;
  final String? watermarkText;
  final bool enableInk;
  final bool enableHighlights;
  final List<MediaOverlayCue> mediaOverlayCues;
  final Source? mediaOverlaySource;
  final ValueChanged<ReaderSettings>? onSettingsChanged;
  final ValueChanged<String?>? onLocationChanged;
  final ValueChanged<List<NovelChapter>>? onChaptersLoaded;
  final ValueChanged<int>? onChapterChanged;
  final ValueChanged<Duration>? onSessionTick;
  final ReaderSyncCallback? onSync;
  final ValueChanged<MediaOverlayCue?>? onKaraokeCue;
  final bool showToolbar;
  final bool rtl;
  final PageTurnEffect pageTurnEffect;
  final NovelTtsEngine? ttsEngine;

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
  List<ReaderBookmark> _bookmarks = const [];
  List<ReaderHighlight> _highlights = const [];
  int? _jumpToParagraph;
  int _paragraphIndex = 0;
  int _chapterIndex = 0;
  String? _cfi;
  Uint8List? _bytes;
  Object? _loadError;
  bool _loading = true;
  Timer? _autoScroll;
  Timer? _sessionTimer;
  DateTime? _sessionStarted;
  final TrialGestureNotifier _trialGesture = TrialGestureNotifier();
  bool _ttsSpeaking = false;
  MediaOverlayPlayer? _overlay;
  int? _karaokeParagraph;

  String get _bookId =>
      widget.bookId ?? 'novel_${widget.source.bytes.displayName.hashCode}';

  bool get _isEpub => widget.source.format == NovelFormat.epub;

  String get _kind => switch (widget.source.format) {
        NovelFormat.text => 'text',
        NovelFormat.markdown => 'markdown',
        NovelFormat.html => 'html',
        NovelFormat.epub => 'epub',
      };

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      if (widget.persistSettings) {
        final saved = await ReaderSettingsStore.instance.load();
        if (saved != null) _settings = saved;
      }
      _bytes = await widget.source.bytes.load();
      _bookmarks = await ReaderBookmarkStore.instance.listBookmarks(_bookId);
      _highlights = await ReaderBookmarkStore.instance.listHighlights(_bookId);
      if (widget.persistProgress) {
        final progress = await ReaderProgressStore.instance.load(_bookId);
        if (progress != null) {
          _cfi = progress.cfi ?? widget.initialCfi;
          _paragraphIndex = progress.paragraphIndex ?? 0;
          _jumpToParagraph = progress.paragraphIndex;
        } else {
          _cfi = widget.initialCfi;
        }
      } else {
        _cfi = widget.initialCfi;
      }
    } catch (e) {
      _loadError = e;
    }

    if (mounted) setState(() => _loading = false);

    if (_settings.immersive) await ReaderImmersive.enter();
    await _enterReading();
    _sessionStarted = DateTime.now();
    _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final s = _sessionStarted;
      if (s != null) widget.onSessionTick?.call(DateTime.now().difference(s));
    });
  }

  Future<void> _enterReading() async {
    await _brightness.apply(_settings.brightness);
    if (_settings.keepScreenOn) await ReaderWakeLock.enable();
    if (widget.mediaOverlaySource != null) {
      _overlay = MediaOverlayPlayer(
        onCueChanged: (cue) {
          widget.onKaraokeCue?.call(cue);
          if (cue?.paragraphIndex != null) {
            final idx = cue!.paragraphIndex!;
            setState(() => _karaokeParagraph = idx);
            _textKey.currentState?.jumpToParagraph(idx);
          }
        },
      );
      await _overlay!.load(
        source: widget.mediaOverlaySource!,
        cues: widget.mediaOverlayCues,
      );
    }
  }

  Future<void> _leaveReading() async {
    _autoScroll?.cancel();
    await widget.ttsEngine?.stop();
    await _overlay?.dispose();
    await _brightness.restore();
    await ReaderWakeLock.disable();
    await ReaderImmersive.leave();
  }

  Future<void> _saveProgress() async {
    if (!widget.persistProgress) return;
    final flat = _flatChapters;
    final pct = flat.isEmpty
        ? 0.0
        : ((_chapterIndex + 1) / flat.length).clamp(0.0, 1.0);
    final progress = ReaderProgress(
      bookId: _bookId,
      cfi: _cfi,
      paragraphIndex: _paragraphIndex,
      percentage: pct,
    );
    await ReaderProgressStore.instance.save(progress);
    await ReaderSyncHub(onSync: widget.onSync).emit(
      ReaderSyncPayload(
        bookId: _bookId,
        progress: progress,
        bookmarks: _bookmarks,
        highlights: _highlights,
      ),
    );
  }

  List<NovelChapter> get _flatChapters {
    final out = <NovelChapter>[];
    for (final c in _chapters) {
      out.addAll(c.flattened);
    }
    return out;
  }

  int get _readableChapterCount {
    final limit = widget.trialLimit;
    final flat = _flatChapters;
    if (flat.isEmpty) return 0;
    if (limit == null || !limit.isActive) return flat.length;
    return limit.visibleCount(flat.length);
  }

  int get _maxReadableChapterIndex {
    final limit = widget.trialLimit;
    final flat = _flatChapters;
    if (flat.isEmpty) return 0;
    if (limit == null || !limit.isActive) return flat.length - 1;
    return limit.maxReadableIndex(flat.length);
  }

  bool get _hasMoreBeyondTrial {
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive) return false;
    return limit.hasMoreBeyond(_flatChapters.length);
  }

  int? get _trialMinParagraphIndex {
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive || limit.startIndex <= 0) {
      return null;
    }
    final flat = _flatChapters;
    if (limit.startIndex >= flat.length) return null;
    return flat[limit.startIndex].anchorIndex;
  }

  int? get _trialMaxParagraphIndex {
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive) return null;
    final flat = _flatChapters;
    final endChapter = limit.startIndex + limit.maxCount;
    if (flat.length <= endChapter) return null;
    final blocked = flat[endChapter];
    final anchor = blocked.anchorIndex;
    if (anchor == null || anchor <= 0) return null;
    return anchor - 1;
  }

  void _notifyTrialLimit(ReaderTrialLimitAction action, int targetIndex) {
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive) return;
    widget.onTrialLimitReached?.call(
      ReaderTrialLimitEvent(
        limit: limit,
        currentIndex: _chapterIndex,
        targetIndex: targetIndex,
        totalCount: _flatChapters.length,
        action: action,
      ),
    );
  }

  void _onTextTrialBoundary({required bool next}) {
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive) return;
    if (next) {
      if (!_hasMoreBeyondTrial) return;
      _trialGesture.call(
        widget.onTrialLimitReached,
        limit: limit,
        currentIndex: _chapterIndex,
        targetIndex: _maxReadableChapterIndex + 1,
        totalCount: _flatChapters.length,
        action: ReaderTrialLimitAction.next,
      );
      return;
    }
    final start = limit.startIndex;
    if (start > 0) {
      _trialGesture.call(
        widget.onTrialLimitReached,
        limit: limit,
        currentIndex: _chapterIndex,
        targetIndex: start - 1,
        totalCount: _flatChapters.length,
        action: ReaderTrialLimitAction.seek,
      );
    }
  }

  int _chapterIndexForParagraph(int paragraphIndex) {
    final flat = _flatChapters;
    if (flat.isEmpty) return 0;
    var chapter = 0;
    for (var i = 0; i < flat.length; i++) {
      final anchor = flat[i].anchorIndex;
      if (anchor != null && anchor <= paragraphIndex) {
        chapter = i;
      }
    }
    return chapter;
  }

  bool _isChapterReadable(int chapterIndex) {
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive) return true;
    return limit.isReadable(chapterIndex, _flatChapters.length);
  }

  @override
  void didUpdateWidget(covariant NovelReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _settings = widget.settings;
      _brightness.apply(_settings.brightness);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ReaderWakeLock.disable();
      _saveProgress();
    } else if (state == AppLifecycleState.resumed && _settings.keepScreenOn) {
      ReaderWakeLock.enable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _saveProgress();
    _leaveReading();
    _brightness.dispose();
    super.dispose();
  }

  void _emitSettings(ReaderSettings next) {
    final brightnessChanged = next.brightness != _settings.brightness;
    setState(() => _settings = next);
    if (brightnessChanged) {
      _brightness.apply(next.brightness);
    }
    if (next.keepScreenOn) {
      ReaderWakeLock.enable();
    } else {
      ReaderWakeLock.disable();
    }
    if (next.immersive) {
      ReaderImmersive.enter();
    } else {
      ReaderImmersive.leave();
    }
    if (widget.persistSettings) ReaderSettingsStore.instance.save(next);
    widget.onSettingsChanged?.call(next);
  }

  void _onFontSizeChanged(double fontSize) {
    _emitSettings(
      _settings.copyWith(
        typography: _settings.typography.copyWith(
          fontSize: fontSize.clamp(12, 36),
        ),
      ),
    );
  }

  void _onChapters(List<NovelChapter> chapters) {
    setState(() => _chapters = chapters);
    widget.onChaptersLoaded?.call(chapters);
  }

  Future<void> _goChapter(int delta) async {
    final flat = _flatChapters;
    if (flat.isEmpty) return;
    final start = widget.trialLimit?.startIndex ?? 0;
    final maxIdx = _maxReadableChapterIndex;
    if (delta > 0 && _chapterIndex >= maxIdx && _hasMoreBeyondTrial) {
      _notifyTrialLimit(ReaderTrialLimitAction.next, _chapterIndex + 1);
      return;
    }
    final next = (_chapterIndex + delta).clamp(start, maxIdx);
    _chapterIndex = next;
    widget.onChapterChanged?.call(next);
    await _goToChapter(flat[next]);
  }

  Future<void> _goToChapter(NovelChapter chapter) async {
    if (_isEpub) {
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

  Future<void> _openChapterSheet() async {
    final chapters = _chapters.isNotEmpty
        ? _chapters
        : (_isEpub ? await _epubController.getChapters() : _chapters);
    if (!mounted) return;
    if (chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无章节目录')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.65,
            child: _ChapterTree(
              chapters: chapters,
              depth: 0,
              onSelect: (c) async {
                Navigator.pop(context);
                final flat = <NovelChapter>[];
                for (final root in chapters) {
                  flat.addAll(root.flattened);
                }
                _chapterIndex = flat.indexWhere(
                  (e) => e.title == c.title && e.href == c.href,
                );
                if (_chapterIndex < 0) _chapterIndex = 0;
                if (!_isChapterReadable(_chapterIndex)) {
                  _notifyTrialLimit(
                    ReaderTrialLimitAction.chapterSelect,
                    _chapterIndex,
                  );
                  return;
                }
                widget.onChapterChanged?.call(_chapterIndex);
                await _goToChapter(c);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSearch() async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: '搜索…',
                          suffixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => setModal(() {}),
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<NovelSearchHit>>(
                        future: _runSearch(controller.text),
                        builder: (context, snap) {
                          final hits = snap.data ?? const [];
                          return ListView.builder(
                            itemCount: hits.length,
                            itemBuilder: (context, i) {
                              final h = hits[i];
                              return ListTile(
                                title: Text(h.excerpt),
                                subtitle: h.chapterTitle == null
                                    ? null
                                    : Text(h.chapterTitle!),
                                onTap: () async {
                                  Navigator.pop(context);
                                  if (h.cfi != null && h.cfi!.isNotEmpty) {
                                    await _epubController.goToChapter(h.cfi!);
                                  } else if (h.paragraphIndex != null) {
                                    final max = _trialMaxParagraphIndex;
                                    if (max != null && h.paragraphIndex! > max) {
                                      _notifyTrialLimit(
                                        ReaderTrialLimitAction.search,
                                        _chapterIndexForParagraph(
                                          h.paragraphIndex!,
                                        ),
                                      );
                                      return;
                                    }
                                    await _textKey.currentState
                                        ?.jumpToParagraph(h.paragraphIndex!);
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<List<NovelSearchHit>> _runSearch(String q) async {
    if (q.trim().isEmpty) return const [];
    if (_isEpub) {
      final raw = await _epubController.search(q);
      return [
        for (final m in raw)
          NovelSearchHit(excerpt: m['excerpt'] ?? '', cfi: m['cfi']),
      ];
    }
    return _textKey.currentState?.search(q, chapters: _chapters) ?? const [];
  }

  Future<void> _toggleBookmark() async {
    final title = _isEpub
        ? (_cfi ?? 'EPUB')
        : 'Para ${_paragraphIndex + 1}';
    final existing = _bookmarks.where((b) {
      if (_isEpub) return b.cfi == _cfi;
      return b.paragraphIndex == _paragraphIndex;
    });
    if (existing.isNotEmpty) {
      await ReaderBookmarkStore.instance
          .removeBookmark(_bookId, existing.first.id);
    } else {
      await ReaderBookmarkStore.instance.addBookmark(
        ReaderBookmark(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          bookId: _bookId,
          title: title,
          cfi: _cfi,
          paragraphIndex: _isEpub ? null : _paragraphIndex,
        ),
      );
    }
    _bookmarks = await ReaderBookmarkStore.instance.listBookmarks(_bookId);
    if (mounted) setState(() {});
  }

  Future<void> _addHighlight() async {
    if (!widget.enableHighlights) return;
    final paras = _textKey.currentState?.paragraphs;
    final excerpt = _isEpub
        ? (_cfi ?? '')
        : (paras != null &&
                _paragraphIndex >= 0 &&
                _paragraphIndex < paras.length
            ? paras[_paragraphIndex]
            : '');
    if (excerpt.isEmpty) return;
    await ReaderBookmarkStore.instance.addHighlight(
      ReaderHighlight(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        bookId: _bookId,
        excerpt: excerpt.length > 120 ? excerpt.substring(0, 120) : excerpt,
        cfi: _cfi,
        paragraphIndex: _isEpub ? null : _paragraphIndex,
      ),
    );
    _highlights = await ReaderBookmarkStore.instance.listHighlights(_bookId);
    if (mounted) setState(() {});
  }

  void _toggleAutoScroll() {
    if (_autoScroll != null) {
      _autoScroll!.cancel();
      _autoScroll = null;
      setState(() {});
      return;
    }
    _autoScroll = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final state = _textKey.currentState;
      // For text vertical, nudge scroll; for epub call next occasionally
      if (_isEpub) return;
      state?.nextPage();
    });
    setState(() {});
  }

  Future<void> _toggleTts() async {
    final engine = widget.ttsEngine;
    if (engine == null) return;
    if (_ttsSpeaking) {
      await engine.stop();
      setState(() => _ttsSpeaking = false);
      return;
    }
    final paras = _textKey.currentState?.paragraphs;
    final text = _isEpub
        ? 'EPUB text-to-speech uses current chapter position.'
        : (paras != null &&
                _paragraphIndex >= 0 &&
                _paragraphIndex < paras.length
            ? paras[_paragraphIndex]
            : '');
    if (text.isEmpty) return;
    setState(() => _ttsSpeaking = true);
    engine.setCompletionHandler(() {
      if (mounted) setState(() => _ttsSpeaking = false);
    });
    await engine.speak(text);
  }

  Future<void> _page(int delta) async {
    if (_isEpub) {
      if (delta > 0 && _hasMoreBeyondTrial &&
          _chapterIndex >= _maxReadableChapterIndex) {
        _notifyTrialLimit(ReaderTrialLimitAction.next, _chapterIndex + 1);
        return;
      }
      if (delta > 0) {
        await _epubController.next();
      } else {
        await _epubController.prev();
      }
      return;
    }
    if (delta > 0) {
      final advanced = await _textKey.currentState?.nextPage() ?? false;
      if (!advanced && _hasMoreBeyondTrial) {
        _notifyTrialLimit(ReaderTrialLimitAction.next, _chapterIndex + 1);
      }
    } else {
      await _textKey.currentState?.prevPage();
    }
  }

  Widget _buildContent() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Load failed: $_loadError', textAlign: TextAlign.center),
        ),
      );
    }
    final bytes = _bytes;
    if (bytes == null) {
      return const Center(child: Text('No content'));
    }
    final bg = _settings.backgroundColor == null
        ? null
        : Color(_settings.backgroundColor!);
    final fg = _settings.foregroundColor == null
        ? null
        : Color(_settings.foregroundColor!);
    final mode = _settings.novelReadingMode;

    if (_isEpub) {
      return EpubViewer(
        bytes: bytes,
        controller: _epubController,
        typography: _settings.typography,
        initialCfi: _cfi,
        readingMode: mode,
        backgroundColor: bg,
        foregroundColor: fg,
        onLocationChanged: (cfi) {
          _cfi = cfi;
          widget.onLocationChanged?.call(cfi);
          _saveProgress();
        },
        onChaptersLoaded: _onChapters,
        onFontSizeChanged: _onFontSizeChanged,
      );
    }

    return TextReader(
      key: _textKey,
      bytes: bytes,
      kind: _kind,
      typography: _settings.typography,
      encoding: widget.encoding,
      readingMode: mode,
      backgroundColor: bg,
      foregroundColor: fg,
      onChaptersLoaded: _onChapters,
      jumpToParagraph: _jumpToParagraph,
      initialParagraph: _paragraphIndex,
      minParagraphIndex: _trialMinParagraphIndex,
      maxParagraphIndex: _trialMaxParagraphIndex,
      highlightParagraphs: {
        for (final h in _highlights)
          if (h.paragraphIndex != null) h.paragraphIndex!,
        ?_karaokeParagraph,
      },
      rtl: widget.rtl,
      pageTurnEffect: widget.pageTurnEffect,
      onParagraphChanged: (i) {
        _paragraphIndex = i;
        _chapterIndex = _chapterIndexForParagraph(i);
        _saveProgress();
      },
      onTrialBoundaryReached: _hasMoreBeyondTrial ||
              (widget.trialLimit?.startIndex ?? 0) > 0
          ? (next) => _onTextTrialBoundary(next: next)
          : null,
      onFontSizeChanged: _onFontSizeChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final flat = _flatChapters;
    final readable = _readableChapterCount;
    final progress = flat.isEmpty
        ? (_paragraphIndex + 1) / 100.0
        : readable == 0
            ? 0.0
            : ((_chapterIndex - (widget.trialLimit?.startIndex ?? 0) + 1) /
                    readable)
                .clamp(0.0, 1.0);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.audioVolumeUp ||
            key == LogicalKeyboardKey.arrowRight) {
          _page(widget.rtl ? -1 : 1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.audioVolumeDown ||
            key == LogicalKeyboardKey.arrowLeft) {
          _page(widget.rtl ? 1 : -1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ListenableBuilder(
        listenable: _brightness,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (_) {
                  if (widget.showToolbar) {
                    setState(() => _toolbarVisible = !_toolbarVisible);
                  }
                },
                child: _buildContent(),
              ),
              BrightnessOverlay(
                brightness: _brightness.value,
                mode: _brightness.mode,
              ),
              if (widget.watermarkText != null)
                ReaderWatermark(text: widget.watermarkText!),
              InkAnnotationLayer(enabled: widget.enableInk),
              if (!_toolbarVisible)
                ReaderProgressBar(
                  progress: progress.clamp(0.0, 1.0),
                  onSeek: (v) {
                    final chapters = _flatChapters;
                    if (chapters.isEmpty || readable == 0) return;
                    final start = widget.trialLimit?.startIndex ?? 0;
                    final i = start + (v * (readable - 1)).round();
                    if (!_isChapterReadable(i)) {
                      _notifyTrialLimit(ReaderTrialLimitAction.seek, i);
                      return;
                    }
                    _chapterIndex = i;
                    _goToChapter(chapters[i]);
                  },
                ),
              if (widget.showToolbar && _toolbarVisible)
                _NovelToolbar(
                  settings: _settings,
                  hasChapters: _chapters.isNotEmpty || _isEpub,
                  autoScroll: _autoScroll != null,
                  ttsOn: _ttsSpeaking,
                  onSettingsChanged: _emitSettings,
                  onSelectChapter: _openChapterSheet,
                  onSearch: _openSearch,
                  onPrevChapter: () => _goChapter(-1),
                  onNextChapter: () => _goChapter(1),
                  onPrevPage: () => _page(-1),
                  onNextPage: () => _page(1),
                  onBookmark: _toggleBookmark,
                  onHighlight: _addHighlight,
                  enableHighlights: widget.enableHighlights,
                  onAutoScroll: _toggleAutoScroll,
                  onTts: widget.ttsEngine == null ? null : _toggleTts,
                  onOverlayPlay: _overlay == null
                      ? null
                      : () => _overlay!.play(),
                  onOverlayPause: _overlay == null
                      ? null
                      : () => _overlay!.pause(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ChapterTree extends StatelessWidget {
  const _ChapterTree({
    required this.chapters,
    required this.depth,
    required this.onSelect,
  });

  final List<NovelChapter> chapters;
  final int depth;
  final ValueChanged<NovelChapter> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (depth == 0)
          const ListTile(
            title: Text('选择章节', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        for (final c in chapters) ...[
          ListTile(
            contentPadding: EdgeInsets.only(left: 16.0 + depth * 16, right: 16),
            title: Text(c.title),
            onTap: () => onSelect(c),
          ),
          if (c.children.isNotEmpty)
            _ChapterTree(
              chapters: c.children,
              depth: depth + 1,
              onSelect: onSelect,
            ),
        ],
      ],
    );
  }
}

class _NovelToolbar extends StatelessWidget {
  const _NovelToolbar({
    required this.settings,
    required this.hasChapters,
    required this.autoScroll,
    required this.ttsOn,
    required this.onSettingsChanged,
    required this.onSelectChapter,
    required this.onSearch,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.onPrevPage,
    required this.onNextPage,
    required this.onBookmark,
    required this.onHighlight,
    required this.enableHighlights,
    required this.onAutoScroll,
    this.onTts,
    this.onOverlayPlay,
    this.onOverlayPause,
  });

  final ReaderSettings settings;
  final bool hasChapters;
  final bool autoScroll;
  final bool ttsOn;
  final ValueChanged<ReaderSettings> onSettingsChanged;
  final VoidCallback onSelectChapter;
  final VoidCallback onSearch;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final VoidCallback onBookmark;
  final VoidCallback onHighlight;
  final bool enableHighlights;
  final VoidCallback onAutoScroll;
  final VoidCallback? onTts;
  final VoidCallback? onOverlayPlay;
  final VoidCallback? onOverlayPause;

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onPrevChapter,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.skip_previous,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: onPrevPage,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: onNextPage,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: onNextChapter,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.skip_next, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: onSearch,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.search, color: Colors.white),
                      ),
                      if (hasChapters)
                        IconButton(
                          onPressed: onSelectChapter,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.list_alt, color: Colors.white),
                        ),
                      IconButton(
                        onPressed: onBookmark,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.bookmark_border,
                          color: Colors.white,
                        ),
                      ),
                      if (enableHighlights)
                        IconButton(
                          onPressed: onHighlight,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.highlight, color: Colors.white),
                        ),
                    ],
                  ),
                ),
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
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '方向',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onSettingsChanged(
                          settings.copyWith(
                            novelReadingMode:
                                mode == NovelReadingMode.vertical
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
                      IconButton(
                        tooltip: '自动滚屏',
                        visualDensity: VisualDensity.compact,
                        onPressed: onAutoScroll,
                        icon: Icon(
                          Icons.vertical_align_bottom,
                          color: autoScroll ? Colors.amber : Colors.white,
                        ),
                      ),
                      if (onTts != null)
                        IconButton(
                          tooltip: '朗读',
                          visualDensity: VisualDensity.compact,
                          onPressed: onTts,
                          icon: Icon(
                            Icons.record_voice_over,
                            color: ttsOn ? Colors.amber : Colors.white,
                          ),
                        ),
                      if (onOverlayPlay != null)
                        IconButton(
                          tooltip: '有声播放',
                          visualDensity: VisualDensity.compact,
                          onPressed: onOverlayPlay,
                          icon: const Icon(Icons.play_arrow, color: Colors.white),
                        ),
                      if (onOverlayPause != null)
                        IconButton(
                          tooltip: '有声暂停',
                          visualDensity: VisualDensity.compact,
                          onPressed: onOverlayPause,
                          icon: const Icon(Icons.pause, color: Colors.white),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onSettingsChanged(
                          settings.copyWith(
                            keepScreenOn: !settings.keepScreenOn,
                          ),
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
                          settings.copyWith(typography: t.copyWith(fontSize: v)),
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
                    const Text('边距', style: TextStyle(color: Colors.white, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        min: 8,
                        max: 40,
                        value: t.pageMargin.clamp(8, 40),
                        onChanged: (v) => onSettingsChanged(
                          settings.copyWith(
                            typography: t.copyWith(pageMargin: v),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('字距', style: TextStyle(color: Colors.white, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 4,
                        value: t.letterSpacing.clamp(0, 4),
                        onChanged: (v) => onSettingsChanged(
                          settings.copyWith(
                            typography: t.copyWith(letterSpacing: v),
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => onSettingsChanged(
                        settings.copyWith(
                          typography: t.copyWith(
                            textAlign: t.textAlign == TextAlignOption.left
                                ? TextAlignOption.justify
                                : TextAlignOption.left,
                          ),
                        ),
                      ),
                      child: Text(
                        t.textAlign == TextAlignOption.justify ? '两端' : '左齐',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in NovelFontOption.defaults)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f.label),
                            selected: t.fontFamily == f.family,
                            onSelected: (_) => onSettingsChanged(
                              settings.copyWith(
                                typography: t.copyWith(fontFamily: f.family),
                              ),
                            ),
                          ),
                        ),
                    ],
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
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(preset.background),
                              child: settings.backgroundColor == preset.background
                                  ? const Icon(Icons.check, size: 14)
                                  : null,
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
