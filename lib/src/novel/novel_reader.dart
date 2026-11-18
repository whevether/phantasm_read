import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint, listEquals;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../audio/novel_tts.dart';
import '../common/ink_annotation.dart';
import '../common/novel_reading_mode.dart';
import '../common/novel_typography.dart';
import '../common/page_curl.dart';
import '../common/reader_bookmark.dart';
import '../common/reader_brightness.dart';
import '../common/reader_custom_font.dart';
import '../common/reader_lifecycle.dart';
import '../common/reader_progress.dart';
import '../common/reader_settings.dart';
import '../common/reader_settings_store.dart';
import '../common/reader_sync.dart';
import '../common/reader_stats.dart';
import '../common/reader_strings.dart';
import '../common/reader_trial_limit.dart';
import '../common/reader_identity.dart';
import '../common/reader_watermark.dart';
import '../common/tap_zones.dart';
import '../common/trial_gesture_boundary.dart';
import '../audio/media_overlay.dart';
import 'epub/epub_viewer.dart';
import 'novel_chapter.dart';
import 'novel_search.dart';
import 'novel_source.dart';
import 'text/text_reader.dart';

/// Highlight colors offered when selecting text (first = default yellow).
const _highlightPalette = <Color>[
  Color(0xFFFFEB3B),
  Color(0xFF81C784),
  Color(0xFF64B5F6),
  Color(0xFFF48FB1),
  Color(0xFFFFB74D),
];

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
    this.onStats,
    this.strings = ReaderStrings.auto,
    this.customFonts = const {},
    this.onKaraokeCue,
    this.showToolbar = true,
    this.rtl = false,
    this.pageTurnEffect = PageTurnEffect.curl,
    this.ttsEngine,
    this.ttsLanguage,
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

  /// Receives per-session reading stats (only readable positions are counted).
  final ReaderStatsCallback? onStats;

  /// Replaceable UI strings.
  final ReaderStrings strings;

  /// Host-provided fonts (family -> font file bytes). Use a family name as
  /// `NovelTypography.fontFamily`; text formats load it via [FontLoader] and
  /// EPUB injects it with `@font-face`.
  final Map<String, Uint8List> customFonts;
  final ValueChanged<MediaOverlayCue?>? onKaraokeCue;
  final bool showToolbar;
  final bool rtl;
  final PageTurnEffect pageTurnEffect;
  final NovelTtsEngine? ttsEngine;

  /// BCP-47 language tag for text-to-speech (needs an engine implementing
  /// [NovelTtsLanguageAware]). Defaults to the EPUB's `dc:language`.
  final String? ttsLanguage;

  @override
  State<NovelReader> createState() => _NovelReaderState();
}

class _NovelReaderState extends State<NovelReader> with WidgetsBindingObserver {
  ReaderStatsTracker? _stats;
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
  int _restoredTextOffset = 0;
  int _chapterIndex = 0;
  String? _cfi;
  Uint8List? _bytes;
  Object? _loadError;
  bool _loading = true;
  Timer? _autoScroll;
  Timer? _sessionTimer;
  DateTime? _sessionStarted;
  late final _session = ReaderSession(_brightness);
  int _loadVersion = 0;
  String? _identity;
  double _epubPercentage = 0;
  bool _autoBusy = false;
  List<NovelChapter> _flat = const [];
  final TrialGestureNotifier _trialGesture = TrialGestureNotifier();
  bool _ttsSpeaking = false;
  MediaOverlayPlayer? _overlay;
  Future<void> _overlayChain = Future<void>.value();
  int? _karaokeParagraph;

  /// Offset/percentage cache: `_textKey.currentState` is already null while
  /// the widget is being disposed, so saving must not read from it.
  int _cachedTextOffset = 0;
  double _cachedTextPercentage = 0;

  /// EPUB: the restored location has not been validated against the trial
  /// window until the viewer reports a location, so nothing is saved/stored.
  bool _epubLocationConfirmed = false;
  bool _recordBusy = false;
  int _fontEpoch = 0;
  final Map<String, Uint8List> _registeredFonts = {};

  String get _bookId =>
      widget.bookId ??
      (_identity ??=
          '${widget.source.format.name}_${widget.source.bytes.stableId}');

  bool get _isEpub => widget.source.format == NovelFormat.epub;

  String get _kind => switch (widget.source.format) {
    NovelFormat.text => 'text',
    NovelFormat.markdown => 'markdown',
    NovelFormat.html => 'html',
    NovelFormat.epub => 'epub',
  };

  /// Strings resolved against the ambient locale when `strings` is
  /// [ReaderStrings.auto] (the default).
  ReaderStrings get _strings =>
      widget.strings.resolveFor(Localizations.maybeLocaleOf(context));

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    WidgetsBinding.instance.addObserver(this);
    _registerCustomFonts();
    _bootstrap();
  }

  /// Loads fonts that are new or changed; the text reader re-paginates once a
  /// font is ready (the epoch invalidates its cached layout).
  void _registerCustomFonts() {
    for (final entry in widget.customFonts.entries) {
      if (identical(_registeredFonts[entry.key], entry.value)) continue;
      _registeredFonts[entry.key] = entry.value;
      loadReaderCustomFont(entry.key, entry.value)
          .then((_) {
            if (mounted) setState(() => _fontEpoch++);
          })
          .catchError((Object _) {});
    }
  }

  Future<void> _bootstrap() async {
    final version = ++_loadVersion;
    final source = widget.source;
    final bookId = _bookId;
    try {
      var settings = widget.settings;
      if (widget.persistSettings) {
        settings = await ReaderSettingsStore.instance.load() ?? settings;
      }
      if (!mounted || version != _loadVersion) return;
      final bytes = await source.bytes.load();
      final bookmarks = await ReaderBookmarkStore.instance.listBookmarks(
        bookId,
      );
      final highlights = await ReaderBookmarkStore.instance.listHighlights(
        bookId,
      );
      final progress = widget.persistProgress
          ? await ReaderProgressStore.instance.load(bookId)
          : null;
      if (!mounted || version != _loadVersion) return;
      _settings = settings;
      _bytes = bytes;
      _bookmarks = bookmarks;
      _highlights = highlights;
      _cfi = progress?.cfi ?? widget.initialCfi;
      _epubPercentage = progress?.percentage ?? 0;
      _paragraphIndex = progress?.paragraphIndex ?? 0;
      _restoredTextOffset = progress?.textOffset ?? 0;
      _cachedTextOffset = _restoredTextOffset;
      _cachedTextPercentage = progress?.percentage ?? 0;
      _epubLocationConfirmed = false;
      _jumpToParagraph = _paragraphIndex;
      await _session.apply(_settings);
      if (!mounted || version != _loadVersion) return;
      // A broken overlay must never prevent the book from opening.
      await _loadOverlay(version);
      if (!mounted || version != _loadVersion) return;
      _sessionStarted = DateTime.now();
      _stats = ReaderStatsTracker(
        bookId,
        minDwell: const Duration(milliseconds: 800),
      );
      _sessionTimer?.cancel();
      _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          widget.onSessionTick?.call(
            DateTime.now().difference(_sessionStarted!),
          );
          _emitStats();
        }
      });
      setState(() => _loading = false);
    } catch (e) {
      if (mounted && version == _loadVersion) {
        setState(() {
          _loadError = e;
          _loading = false;
        });
      }
    }
  }

  /// Overlay (re)loads are serialised so two quick prop changes can never
  /// interleave and leak a player; failures are swallowed.
  Future<void> _loadOverlay(int version) {
    final run = _overlayChain
        .then((_) => _loadOverlayNow(version))
        .catchError((Object _) {});
    _overlayChain = run;
    return run;
  }

  Future<void> _loadOverlayNow(int version) async {
    final old = _overlay;
    _overlay = null;
    await old?.dispose();
    if (!mounted ||
        version != _loadVersion ||
        widget.mediaOverlaySource == null) {
      return;
    }
    final overlay = MediaOverlayPlayer(
      onCueChanged: (cue) {
        if (!mounted || version != _loadVersion) return;
        final paragraph = cue?.paragraphIndex;
        if (paragraph != null && !_isParagraphReadable(paragraph)) {
          // Never leak cues (or move the view) outside the trial window:
          // stop the audio and raise the trial event instead.
          _overlay?.pause();
          setState(() => _karaokeParagraph = null);
          _onTextTrialBoundary(next: true);
          return;
        }
        widget.onKaraokeCue?.call(cue);
        setState(() => _karaokeParagraph = paragraph);
        if (paragraph != null) {
          _textKey.currentState?.jumpToParagraph(paragraph);
        }
        if (cue?.cfi != null) {
          // The EPUB shell refuses locations outside the trial window.
          _epubController.goToChapter(cue!.cfi!).catchError((Object _) {});
        }
      },
    );
    _overlay = overlay;
    await overlay.load(
      source: widget.mediaOverlaySource!,
      cues: widget.mediaOverlayCues,
    );
  }

  Future<void> _leaveReading() async {
    _autoScroll?.cancel();
    final overlay = _overlay;
    _overlay = null;
    widget.ttsEngine?.setCompletionHandler(null);
    try {
      await widget.ttsEngine?.stop();
    } catch (e) {
      debugPrint('NovelReader: tts stop failed: $e');
    }
    await overlay?.dispose();
  }

  double get _percentage {
    if (_isEpub) return _epubPercentage.clamp(0, 1);
    return _cachedTextPercentage;
  }

  /// Refreshes the cached text position while the text reader is alive.
  void _syncTextCache() {
    final state = _textKey.currentState;
    if (state == null) return;
    _cachedTextOffset = state.currentTextOffset;
    _cachedTextPercentage = state.characterProgress;
  }

  /// Counts the current, readable position in the session stats.
  void _recordVisit() {
    final stats = _stats;
    if (stats == null) return;
    if (_isEpub) {
      if (_epubLocationConfirmed) stats.visit(_chapterIndex);
    } else {
      final paragraphs = _textKey.currentState?.paragraphs;
      if (paragraphs == null ||
          _paragraphIndex < 0 ||
          _paragraphIndex >= paragraphs.length ||
          !_isParagraphReadable(_paragraphIndex)) {
        return;
      }
      stats.visit(_paragraphIndex, chars: paragraphs[_paragraphIndex].length);
    }
  }

  /// Stats are independent of progress persistence.
  void _emitStats() {
    final stats = _stats;
    if (stats == null) return;
    widget.onStats?.call(stats.snapshot());
  }

  Future<void> _saveProgress() async {
    if (_loading || _bytes == null) return;
    if (!_isEpub) _syncTextCache();
    _emitStats();
    if (!widget.persistProgress) return;
    // An unconfirmed (restored) EPUB location may lie outside the trial
    // window; never persist it.
    if (_isEpub && !_epubLocationConfirmed) return;
    final progress = ReaderProgress(
      bookId: _bookId,
      cfi: _cfi,
      paragraphIndex: _paragraphIndex,
      textOffset: _isEpub ? null : _cachedTextOffset,
      percentage: _percentage,
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

  List<NovelChapter> get _flatChapters => _flat;

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
    if (flat.isEmpty) return -1;
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
    if (flat.isEmpty) return 0;
    if (limit.startIndex >= flat.length) {
      return _textKey.currentState?.paragraphs.length ?? 0;
    }
    return flat[limit.startIndex].anchorIndex;
  }

  int? get _trialMaxParagraphIndex {
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive) return null;
    final flat = _flatChapters;
    final endChapter = limit.startIndex + limit.maxCount;
    if (flat.isEmpty || limit.startIndex >= flat.length) return -1;
    if (flat.length <= endChapter) return null;
    final blocked = flat[endChapter];
    final anchor = blocked.anchorIndex;
    // Fail closed: an unknown anchor must not expose the blocked chapters.
    if (anchor == null || anchor <= 0) return -1;
    return anchor - 1;
  }

  /// Whether text paragraph [index] lies inside the trial window.
  bool _isParagraphReadable(int index) {
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive) return true;
    final min = _trialMinParagraphIndex;
    final max = _trialMaxParagraphIndex;
    if (max != null && max < 0) return false;
    if (min != null && index < min) return false;
    if (max != null && index > max) return false;
    return true;
  }

  /// Clamps a restored/remembered position into the trial window. Called
  /// once chapters are known and whenever the trial limit changes.
  void _clampToTrialWindow() {
    final limit = widget.trialLimit;
    if (limit == null || !limit.isActive || _isEpub || _flat.isEmpty) return;
    final min = _trialMinParagraphIndex ?? 0;
    final max = _trialMaxParagraphIndex;
    if (max != null && max < min) return;
    var paragraph = _paragraphIndex;
    if (paragraph < min) paragraph = min;
    if (max != null && paragraph > max) paragraph = max;
    if (paragraph != _paragraphIndex) {
      _paragraphIndex = paragraph;
      _restoredTextOffset = 0;
      _cachedTextOffset = 0;
      _jumpToParagraph = paragraph;
    }
    final start = limit.startIndex;
    final last = _maxReadableChapterIndex;
    if (last >= start) {
      _chapterIndex = _chapterIndexForParagraph(paragraph).clamp(start, last);
    }
  }

  void _stopAutoScroll() {
    if (_autoScroll == null) return;
    _autoScroll?.cancel();
    _autoScroll = null;
    if (_isEpub) {
      _epubController.setAutoScroll(false).catchError((Object _) {});
    }
    if (mounted) setState(() {});
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
    // Auto page-turning must never keep running into the paywall.
    _stopAutoScroll();
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
    if (oldWidget.source.format != widget.source.format ||
        oldWidget.source.bytes.stableId != widget.source.bytes.stableId ||
        oldWidget.bookId != widget.bookId ||
        oldWidget.encoding != widget.encoding) {
      _autoScroll?.cancel();
      _autoScroll = null;
      _sessionTimer?.cancel();
      _leaveReading();
      _identity = null;
      _loading = true;
      _loadError = null;
      _bytes = null;
      _chapters = [];
      _flat = [];
      _chapterIndex = 0;
      _paragraphIndex = 0;
      _cfi = null;
      _cachedTextOffset = 0;
      _cachedTextPercentage = 0;
      _epubLocationConfirmed = false;
      _registerCustomFonts();
      _bootstrap();
      return;
    }
    if (oldWidget.settings != widget.settings) {
      _settings = widget.settings;
      _session.apply(_settings);
    }
    if (oldWidget.customFonts != widget.customFonts) {
      _registerCustomFonts();
    }
    if (oldWidget.trialLimit != widget.trialLimit) {
      // A new window invalidates whatever was remembered: clamp the text
      // position now; the EPUB shell re-validates its own location on reopen.
      _autoScroll?.cancel();
      _autoScroll = null;
      _epubLocationConfirmed = false;
      _clampToTrialWindow();
    }
    if (oldWidget.ttsEngine != widget.ttsEngine) {
      oldWidget.ttsEngine?.setCompletionHandler(null);
      oldWidget.ttsEngine?.stop();
      _ttsSpeaking = false;
    }
    if (oldWidget.mediaOverlaySource != widget.mediaOverlaySource ||
        !listEquals(oldWidget.mediaOverlayCues, widget.mediaOverlayCues)) {
      _loadOverlay(_loadVersion).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stats?.pause();
      _saveProgress();
    } else if (state == AppLifecycleState.resumed) {
      _stats?.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _saveProgress();
    _loadVersion++;
    _leaveReading();
    _session.dispose();
    super.dispose();
  }

  void _emitSettings(ReaderSettings next) {
    setState(() => _settings = next);
    _session.apply(next);
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
    if (!mounted) return;
    setState(() {
      _chapters = chapters;
      _flat = chapters.expand((c) => c.flattened).toList();
      _clampToTrialWindow();
    });
    widget.onChaptersLoaded?.call(chapters);
  }

  Future<void> _goChapter(int delta) async {
    final flat = _flatChapters;
    if (flat.isEmpty || _readableChapterCount == 0) return;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_strings.noToc)));
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
              title: _strings.selectChapter,
              onSelect: (c) async {
                Navigator.pop(context);
                final flat = <NovelChapter>[];
                for (final root in chapters) {
                  flat.addAll(root.flattened);
                }
                var target = flat.indexWhere((e) => identical(e, c));
                if (target < 0) target = 0;
                if (!_isChapterReadable(target)) {
                  _notifyTrialLimit(
                    ReaderTrialLimitAction.chapterSelect,
                    target,
                  );
                  return;
                }
                _chapterIndex = target;
                widget.onChapterChanged?.call(_chapterIndex);
                await _goToChapter(c);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBookmarkSheet() async {
    _bookmarks = await ReaderBookmarkStore.instance.listBookmarks(_bookId);
    _highlights = await ReaderBookmarkStore.instance.listHighlights(_bookId);
    if (!mounted) return;
    Future<void> jump(String? cfi, int? paragraph) async {
      if (cfi != null && cfi.isNotEmpty && _isEpub) {
        await _epubController.goToChapter(cfi);
      } else if (paragraph != null) {
        if (!_isParagraphReadable(paragraph)) {
          _notifyTrialLimit(
            ReaderTrialLimitAction.seek,
            _chapterIndexForParagraph(paragraph),
          );
          return;
        }
        await _textKey.currentState?.jumpToParagraph(paragraph);
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.6,
            child: ListView(
              children: [
                ListTile(title: Text(_strings.bookmarks)),
                for (final b in _bookmarks)
                  ListTile(
                    leading: const Icon(Icons.bookmark),
                    title: Text(
                      b.title.isNotEmpty
                          ? b.title
                          : (b.paragraphIndex != null
                                ? _strings.pageN(b.paragraphIndex! + 1)
                                : _strings.bookmarks),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      jump(b.cfi, b.paragraphIndex);
                    },
                    trailing: IconButton(
                      tooltip: _strings.delete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ReaderBookmarkStore.instance.removeBookmark(
                          _bookId,
                          b.id,
                        );
                        _bookmarks = await ReaderBookmarkStore.instance
                            .listBookmarks(_bookId);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                if (_highlights.isNotEmpty)
                  ListTile(title: Text(_strings.highlight)),
                for (final h in _highlights)
                  ListTile(
                    leading: Icon(Icons.highlight, color: Color(h.color)),
                    title: Text(
                      h.excerpt.startsWith('epubcfi(')
                          ? _strings.highlight
                          : h.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: h.note == null || h.note!.isEmpty
                        ? null
                        : Text(
                            h.note!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      jump(h.cfi, h.paragraphIndex);
                    },
                    onLongPress: () {
                      Navigator.pop(sheetContext);
                      _openHighlightSheet(h);
                    },
                    trailing: IconButton(
                      tooltip: _strings.delete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ReaderBookmarkStore.instance.removeHighlight(
                          _bookId,
                          h.id,
                        );
                        _highlights = await ReaderBookmarkStore.instance
                            .listHighlights(_bookId);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (mounted) setState(() {});
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

  Future<void> _openSearch() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SearchSheet(
        strings: _strings,
        search: _runSearch,
        onSelect: (h) async {
          Navigator.pop(context);
          if (h.cfi != null && h.cfi!.isNotEmpty) {
            await _epubController.goToChapter(h.cfi!);
          } else if (h.paragraphIndex != null) {
            if (!_isParagraphReadable(h.paragraphIndex!)) {
              _notifyTrialLimit(
                ReaderTrialLimitAction.search,
                _chapterIndexForParagraph(h.paragraphIndex!),
              );
              return;
            }
            await _textKey.currentState?.jumpToParagraph(h.paragraphIndex!);
          }
        },
      ),
    );
  }

  Future<NovelSearchResult> _runSearch(String q) async {
    if (q.trim().isEmpty) return const NovelSearchResult();
    if (_isEpub) {
      // The EPUB shell only searches inside the trial window.
      final raw = await _epubController.search(q);
      return NovelSearchResult(
        hits: [
          for (final m in raw)
            NovelSearchHit(excerpt: m['excerpt'] ?? '', cfi: m['cfi']),
        ],
      );
    }
    final state = _textKey.currentState;
    if (state == null) return const NovelSearchResult();
    var result = state.searchInWindow(q, chapters: _chapters);
    if (result.hits.isEmpty && result.hiddenCount == 0) {
      // Accent-insensitive retry (Vietnamese tone marks, Latin accents).
      result = state.searchInWindow(
        q,
        chapters: _chapters,
        ignoreDiacritics: true,
      );
    }
    return result;
  }

  /// Whether the current location may be bookmarked / highlighted / spoken.
  bool get _currentLocationReadable {
    if (_isEpub) return _epubLocationConfirmed;
    return _isParagraphReadable(_paragraphIndex);
  }

  Future<void> _toggleBookmark() async {
    if (_recordBusy || !_currentLocationReadable) return;
    _recordBusy = true;
    try {
      final existing = _bookmarks.where((b) {
        if (_isEpub) return b.cfi == _cfi;
        return b.paragraphIndex == _paragraphIndex;
      });
      if (existing.isNotEmpty) {
        await ReaderBookmarkStore.instance.removeBookmark(
          _bookId,
          existing.first.id,
        );
      } else {
        // The title is intentionally empty: it is derived (and localised) at
        // display time from the position, never stored in one language.
        await ReaderBookmarkStore.instance.addBookmark(
          ReaderBookmark(
            id: readerRecordId(),
            bookId: _bookId,
            title: '',
            cfi: _isEpub ? _cfi : null,
            paragraphIndex: _isEpub ? null : _paragraphIndex,
          ),
        );
      }
      _bookmarks = await ReaderBookmarkStore.instance.listBookmarks(_bookId);
      if (mounted) setState(() {});
    } finally {
      _recordBusy = false;
    }
  }

  /// Toolbar highlight button. EPUB highlights the text currently selected in
  /// the book; text formats highlight the paragraph being read.
  Future<void> _addHighlight() async {
    if (!widget.enableHighlights || _recordBusy || !_currentLocationReadable) {
      return;
    }
    if (_isEpub) {
      final selection = _epubSelection;
      if (selection == null) {
        _toast(_strings.selectTextFirst);
        return;
      }
      await _openSelectionSheet(selection);
      return;
    }
    final paras = _textKey.currentState?.paragraphs;
    final excerpt =
        paras != null && _paragraphIndex >= 0 && _paragraphIndex < paras.length
        ? paras[_paragraphIndex]
        : '';
    if (excerpt.isEmpty) return;
    await _openSelectionSheet(
      EpubSelection(cfi: '', text: excerpt),
      paragraph: _paragraphIndex,
    );
  }

  /// Last text selection reported by the EPUB view (cleared when handled).
  EpubSelection? _epubSelection;

  void _onEpubSelection(EpubSelection selection) {
    if (!mounted || !_currentLocationReadable) return;
    _epubSelection = selection;
    _openSelectionSheet(selection);
  }

  Future<void> _saveHighlight({
    required String excerpt,
    String? cfi,
    int? paragraph,
    required Color color,
    String? note,
  }) async {
    if (_recordBusy) return;
    _recordBusy = true;
    try {
      await ReaderBookmarkStore.instance.addHighlight(
        ReaderHighlight(
          id: readerRecordId(),
          bookId: _bookId,
          excerpt: excerpt.length > 120 ? excerpt.substring(0, 120) : excerpt,
          cfi: cfi,
          paragraphIndex: paragraph,
          color: color.toARGB32(),
          note: (note == null || note.isEmpty) ? null : note,
        ),
      );
      _highlights = await ReaderBookmarkStore.instance.listHighlights(_bookId);
      if (mounted) setState(() {});
    } finally {
      _recordBusy = false;
    }
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast(_strings.copied);
  }

  /// Short message; hosts without a [Scaffold] simply get none.
  void _toast(String message) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    } on Object catch (e) {
      debugPrint('NovelReader: cannot show message: $e');
    }
  }

  Future<String?> _promptNote({String? initial}) {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_strings.note),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(_strings.save),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Widget _colorChips(
    BuildContext sheetContext,
    ValueChanged<Color> onPick, {
    int? selected,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final c in _highlightPalette)
          Semantics(
            button: true,
            label: _strings.highlight,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onPick(c),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: selected == c.toARGB32() ? 3 : 1,
                    color: Theme.of(sheetContext).colorScheme.outline,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Copy / highlight (5 colors) / note for a selected range or paragraph.
  Future<void> _openSelectionSheet(
    EpubSelection selection, {
    int? paragraph,
  }) async {
    final highlightable = widget.enableHighlights;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                selection.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy),
                    label: Text(_strings.copy),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _copyText(selection.text);
                    },
                  ),
                  if (highlightable)
                    TextButton.icon(
                      icon: const Icon(Icons.edit_note),
                      label: Text(_strings.note),
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        final note = await _promptNote();
                        if (note == null) return;
                        await _saveHighlight(
                          excerpt: selection.text,
                          cfi: paragraph == null ? selection.cfi : null,
                          paragraph: paragraph,
                          color: _highlightPalette.first,
                          note: note,
                        );
                      },
                    ),
                ],
              ),
              if (highlightable) ...[
                const SizedBox(height: 8),
                _colorChips(sheetContext, (color) async {
                  Navigator.pop(sheetContext);
                  await _saveHighlight(
                    excerpt: selection.text,
                    cfi: paragraph == null ? selection.cfi : null,
                    paragraph: paragraph,
                    color: color,
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
    _epubSelection = null;
    if (_isEpub) _epubController.clearSelection().catchError((Object _) {});
  }

  /// Sheet for an existing highlight: copy, note, recolor, delete.
  Future<void> _openHighlightSheet(ReaderHighlight h) async {
    Future<void> reload() async {
      _highlights = await ReaderBookmarkStore.instance.listHighlights(_bookId);
      if (mounted) setState(() {});
    }

    final isLocation = h.excerpt.startsWith('epubcfi(');
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isLocation)
                Text(h.excerpt, maxLines: 4, overflow: TextOverflow.ellipsis),
              if (h.note != null && h.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  h.note!,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!isLocation)
                    TextButton.icon(
                      icon: const Icon(Icons.copy),
                      label: Text(_strings.copy),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _copyText(h.excerpt);
                      },
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit_note),
                    label: Text(_strings.note),
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      final note = await _promptNote(initial: h.note);
                      if (note == null) return;
                      await ReaderBookmarkStore.instance.updateHighlightNote(
                        _bookId,
                        h.id,
                        note,
                      );
                      await reload();
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: Text(_strings.delete),
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await ReaderBookmarkStore.instance.removeHighlight(
                        _bookId,
                        h.id,
                      );
                      await reload();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _colorChips(sheetContext, (color) async {
                Navigator.pop(sheetContext);
                await ReaderBookmarkStore.instance.updateHighlightColor(
                  _bookId,
                  h.id,
                  color.toARGB32(),
                );
                await reload();
              }, selected: h.color),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleAutoScroll() {
    if (_autoScroll != null) {
      _stopAutoScroll();
      return;
    }
    if (_isEpub) {
      // The WebView drives scrolling; this timer is only the active marker.
      _autoScroll = Timer.periodic(const Duration(hours: 1), (_) {});
      _epubController.setAutoScroll(true).catchError((Object e) {
        debugPrint('NovelReader: EPUB auto scroll failed: $e');
        _stopAutoScroll();
      });
      setState(() {});
      return;
    }
    _autoScroll = Timer.periodic(
      Duration(
        milliseconds:
            _isEpub || _settings.novelReadingMode == NovelReadingMode.horizontal
            ? 4000
            : 100,
      ),
      (_) async {
        if (_autoBusy || !mounted) return;
        _autoBusy = true;
        try {
          if (!_isEpub &&
              _settings.novelReadingMode == NovelReadingMode.vertical) {
            final moved = await _textKey.currentState?.scrollBy(3) ?? false;
            if (!moved) {
              // End of the readable range: stop, and report the paywall.
              _stopAutoScroll();
              if (_hasMoreBeyondTrial) _onTextTrialBoundary(next: true);
            }
          } else {
            final advanced = await _page(1);
            if (!advanced) _stopAutoScroll();
          }
        } catch (e) {
          debugPrint('NovelReader: auto scroll failed: $e');
          _stopAutoScroll();
        } finally {
          _autoBusy = false;
        }
      },
    );
    setState(() {});
  }

  Future<void> _toggleTts() async {
    final engine = widget.ttsEngine;
    if (engine == null) return;
    if (_ttsSpeaking) {
      await engine.stop();
      if (mounted) setState(() => _ttsSpeaking = false);
      return;
    }
    if (!_currentLocationReadable) return;
    final paras = _textKey.currentState?.paragraphs;
    final text = _isEpub
        ? await _epubController.currentText()
        : (paras != null &&
                  _paragraphIndex >= 0 &&
                  _paragraphIndex < paras.length
              ? paras[_paragraphIndex]
              : '');
    if (!mounted || text.trim().isEmpty) return;
    final language =
        widget.ttsLanguage ??
        (_isEpub ? await _epubController.language() : null);
    if (!mounted) return;
    if (engine is NovelTtsLanguageAware && language != null) {
      try {
        await (engine as NovelTtsLanguageAware).setLanguage(language);
      } catch (_) {
        // An unsupported language must not prevent reading aloud.
      }
    }
    // Engines limit the utterance length: read a long chapter in chunks.
    final chunks = chunkForTts(text);
    var next = 0;
    Future<void> speakNext() async {
      if (!mounted || !_ttsSpeaking) return;
      if (next >= chunks.length) {
        setState(() => _ttsSpeaking = false);
        return;
      }
      try {
        await engine.speak(chunks[next++]);
      } catch (e) {
        debugPrint('NovelReader: tts speak failed: $e');
        if (mounted) setState(() => _ttsSpeaking = false);
      }
    }

    setState(() => _ttsSpeaking = true);
    engine.setCompletionHandler(() {
      speakNext();
    });
    await speakNext();
  }

  /// Turns one page. Returns `false` when nothing more could be shown (end of
  /// the readable range), which stops auto page-turning.
  Future<bool> _page(int delta) async {
    if (_isEpub) {
      if (delta > 0) {
        await _epubController.next();
      } else {
        await _epubController.prev();
      }
      return true;
    }
    if (delta > 0) {
      final advanced = await _textKey.currentState?.nextPage() ?? false;
      if (!advanced && _hasMoreBeyondTrial) {
        _onTextTrialBoundary(next: true);
      }
      return advanced;
    }
    await _textKey.currentState?.prevPage();
    return true;
  }

  Widget _buildContent() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${_strings.loadFailed}: $_loadError',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final bytes = _bytes;
    if (bytes == null) {
      return Center(child: Text(_strings.noContent));
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
        key: ValueKey(_bookId),
        strings: _strings,
        rtl: widget.rtl,
        customFonts: widget.customFonts,
        bytes: bytes,
        trialLimit: widget.trialLimit,
        onTrialBoundaryReached: (next) => _onTextTrialBoundary(next: next),
        onPositionChanged: (index, percentage) {
          if (!mounted) return;
          final changed = _chapterIndex != index;
          // The shell only reports locations inside the trial window.
          _epubLocationConfirmed = true;
          setState(() {
            _chapterIndex = index;
            _epubPercentage = percentage;
          });
          _recordVisit();
          if (changed) widget.onChapterChanged?.call(index);
        },
        controller: _epubController,
        typography: _settings.typography,
        initialCfi: _cfi,
        readingMode: mode,
        backgroundColor: bg,
        foregroundColor: fg,
        onLocationChanged: (cfi) {
          _cfi = cfi;
          _epubLocationConfirmed = true;
          widget.onLocationChanged?.call(cfi);
          _saveProgress();
        },
        onChaptersLoaded: _onChapters,
        onFontSizeChanged: _onFontSizeChanged,
        highlights: [
          for (final h in _highlights)
            // Range CFIs only (legacy highlights stored a single point).
            if (h.cfi != null &&
                h.cfi!.startsWith('epubcfi(') &&
                h.cfi!.contains(','))
              EpubHighlightMark(id: h.id, cfi: h.cfi!, color: Color(h.color)),
        ],
        onTextSelected: _onEpubSelection,
        onHighlightTapped: (id) {
          final matches = _highlights.where((h) => h.id == id);
          if (matches.isNotEmpty) _openHighlightSheet(matches.first);
        },
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
      initialTextOffset: _restoredTextOffset,
      minParagraphIndex: _trialMinParagraphIndex,
      maxParagraphIndex: _trialMaxParagraphIndex,
      swipeSensitivity: _settings.swipeSensitivity,
      highlightParagraphs: {?_karaokeParagraph},
      highlightColors: {
        for (final h in _highlights)
          if (h.paragraphIndex != null) h.paragraphIndex!: Color(h.color),
      },
      rtl: widget.rtl,
      pageTurnEffect: widget.pageTurnEffect,
      strings: _strings,
      fontEpoch: _fontEpoch,
      onParagraphChanged: (i) {
        _paragraphIndex = i;
        _syncTextCache();
        _recordVisit();
        final chapter = _chapterIndexForParagraph(i);
        if (_chapterIndex != chapter) {
          _chapterIndex = chapter;
          widget.onChapterChanged?.call(chapter);
        }
        if (mounted) setState(() {});
        _saveProgress();
      },
      onTrialBoundaryReached:
          _hasMoreBeyondTrial || (widget.trialLimit?.startIndex ?? 0) > 0
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
    final readable = _readableChapterCount;
    final progress = _percentage;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        final key = event.logicalKey;
        final volume =
            _settings.volumeKeyPaging &&
            (key == LogicalKeyboardKey.audioVolumeUp ||
                key == LogicalKeyboardKey.audioVolumeDown);
        // Swallow volume-key repeats too (no system volume change).
        if (event is KeyRepeatEvent && volume) return KeyEventResult.handled;
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if ((volume && key == LogicalKeyboardKey.audioVolumeUp) ||
            key == LogicalKeyboardKey.arrowRight) {
          _page(widget.rtl ? -1 : 1);
          return KeyEventResult.handled;
        }
        if ((volume && key == LogicalKeyboardKey.audioVolumeDown) ||
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
                child: Semantics(
                  label: _strings.toggleToolbar,
                  onTap: widget.showToolbar
                      ? () => setState(() => _toolbarVisible = !_toolbarVisible)
                      : null,
                  child: _buildContent(),
                ),
              ),
              BrightnessOverlay(
                brightness: _brightness.value,
                mode: _brightness.mode,
              ),
              if (widget.watermarkText != null)
                ReaderWatermark(text: widget.watermarkText!),
              ReaderInk(
                key: ValueKey(
                  '$_bookId:${_isEpub ? _cfi : '$_paragraphIndex:${_textKey.currentState?.currentTextOffset ?? 0}'}',
                ),
                bookId: _bookId,
                location: _isEpub
                    ? _cfi ?? 'start'
                    : '$_paragraphIndex:${_textKey.currentState?.currentTextOffset ?? 0}',
                enabled: widget.enableInk,
                strings: _strings,
              ),
              if (!_toolbarVisible)
                ReaderProgressBar(
                  semanticsLabel: _strings.progress,
                  progress: progress.clamp(0.0, 1.0),
                  onSeek: (v) {
                    if (!_isEpub) {
                      final total =
                          _textKey.currentState?.paragraphs.length ?? 0;
                      if (total == 0) return;
                      final first = _trialMinParagraphIndex ?? 0;
                      final last = _trialMaxParagraphIndex ?? total - 1;
                      if (first > last) return;
                      _textKey.currentState?.jumpToParagraph(
                        first + (v * (last - first)).round(),
                      );
                      return;
                    }
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
                  strings: _strings,
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
                  onBookmarkList: _openBookmarkSheet,
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
    required this.title,
  });

  final String title;
  final List<NovelChapter> chapters;
  final int depth;
  final ValueChanged<NovelChapter> onSelect;

  @override
  Widget build(BuildContext context) {
    final rows = <(NovelChapter, int)>[];
    void visit(List<NovelChapter> items, int level) {
      for (final item in items) {
        rows.add((item, level));
        visit(item.children, level + 1);
      }
    }

    visit(chapters, depth);
    return ListView.builder(
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return ListTile(title: Text(title));
        final (chapter, level) = rows[i - 1];
        return ListTile(
          contentPadding: EdgeInsetsDirectional.only(
            start: 16.0 + level * 16,
            end: 16,
          ),
          title: Text(chapter.title),
          onTap: () => onSelect(chapter),
        );
      },
    );
  }
}

class _NovelToolbar extends StatelessWidget {
  const _NovelToolbar({
    required this.strings,
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
    required this.onBookmarkList,
    required this.onHighlight,
    required this.enableHighlights,
    required this.onAutoScroll,
    this.onTts,
    this.onOverlayPlay,
    this.onOverlayPause,
  });

  final ReaderStrings strings;
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
  final VoidCallback onBookmarkList;
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
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
                          tooltip: strings.previousChapter,
                          onPressed: onPrevChapter,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.skip_previous,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: strings.previousPage,
                          onPressed: onPrevPage,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: strings.nextPage,
                          onPressed: onNextPage,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: strings.nextChapter,
                          onPressed: onNextChapter,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.skip_next,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: strings.search,
                          onPressed: onSearch,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.search, color: Colors.white),
                        ),
                        if (hasChapters)
                          IconButton(
                            tooltip: strings.toc,
                            onPressed: onSelectChapter,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.list_alt,
                              color: Colors.white,
                            ),
                          ),
                        IconButton(
                          tooltip: strings.addBookmark,
                          onPressed: onBookmark,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.bookmark_border,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: strings.bookmarks,
                          onPressed: onBookmarkList,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.collections_bookmark,
                            color: Colors.white,
                          ),
                        ),
                        if (enableHighlights)
                          IconButton(
                            tooltip: strings.highlight,
                            onPressed: onHighlight,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.highlight,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.brightness_6,
                        color: Colors.white,
                        size: 18,
                      ),
                      Expanded(
                        child: Slider(
                          value: settings.brightness,
                          label: '${(settings.brightness * 100).round()}%',
                          semanticFormatterCallback: (v) =>
                              '${strings.brightness} ${(v * 100).round()}%',
                          onChanged: (v) => onSettingsChanged(
                            settings.copyWith(brightness: v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: strings.orientation,
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
                          tooltip: strings.autoScroll,
                          visualDensity: VisualDensity.compact,
                          onPressed: onAutoScroll,
                          icon: Icon(
                            Icons.vertical_align_bottom,
                            color: autoScroll ? Colors.amber : Colors.white,
                          ),
                        ),
                        if (onTts != null)
                          IconButton(
                            tooltip: strings.tts,
                            visualDensity: VisualDensity.compact,
                            onPressed: onTts,
                            icon: Icon(
                              Icons.record_voice_over,
                              color: ttsOn ? Colors.amber : Colors.white,
                            ),
                          ),
                        if (onOverlayPlay != null)
                          IconButton(
                            tooltip: strings.audioPlay,
                            visualDensity: VisualDensity.compact,
                            onPressed: onOverlayPlay,
                            icon: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                            ),
                          ),
                        if (onOverlayPause != null)
                          IconButton(
                            tooltip: strings.audioPause,
                            visualDensity: VisualDensity.compact,
                            onPressed: onOverlayPause,
                            icon: const Icon(Icons.pause, color: Colors.white),
                          ),
                        IconButton(
                          tooltip: strings.keepScreenOn,
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
                          label: t.fontSize.toStringAsFixed(0),
                          semanticFormatterCallback: (v) =>
                              '${strings.fontSize} ${v.round()}',
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
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 72),
                        child: Text(
                          strings.lineHeight,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          min: 1.2,
                          max: 2.4,
                          value: t.lineHeight.clamp(1.2, 2.4),
                          label: t.lineHeight.toStringAsFixed(1),
                          semanticFormatterCallback: (v) =>
                              '${strings.lineHeight} ${v.toStringAsFixed(1)}',
                          onChanged: (v) => onSettingsChanged(
                            settings.copyWith(
                              typography: t.copyWith(lineHeight: v),
                            ),
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 72),
                        child: Text(
                          strings.pageMargin,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          min: 8,
                          max: 40,
                          value: t.pageMargin.clamp(8, 40),
                          label: t.pageMargin.toStringAsFixed(0),
                          semanticFormatterCallback: (v) =>
                              '${strings.pageMargin} ${v.round()}',
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
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 72),
                        child: Text(
                          strings.swipeSensitivity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          min: 0.5,
                          max: 2.0,
                          value: settings.swipeSensitivity.clamp(0.5, 2.0),
                          label: settings.swipeSensitivity.toStringAsFixed(1),
                          semanticFormatterCallback: (v) =>
                              '${strings.swipeSensitivity} ${v.toStringAsFixed(1)}',
                          onChanged: (v) => onSettingsChanged(
                            settings.copyWith(swipeSensitivity: v),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 72),
                        child: Text(
                          strings.letterSpacing,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          min: 0,
                          max: 4,
                          value: t.letterSpacing.clamp(0, 4),
                          label: t.letterSpacing.toStringAsFixed(1),
                          semanticFormatterCallback: (v) =>
                              '${strings.letterSpacing} ${v.toStringAsFixed(1)}',
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
                          t.textAlign == TextAlignOption.justify
                              ? strings.alignJustify
                              : strings.alignLeft,
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
                              label: Text(
                                f.family == null ? strings.systemFont : f.label,
                              ),
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
                            child: Semantics(
                              button: true,
                              selected:
                                  settings.backgroundColor == preset.background,
                              label: preset.name,
                              excludeSemantics: true,
                              onTap: () => onSettingsChanged(
                                settings.copyWith(
                                  backgroundColor: preset.background,
                                  foregroundColor: preset.foreground,
                                ),
                              ),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => onSettingsChanged(
                                  settings.copyWith(
                                    backgroundColor: preset.background,
                                    foregroundColor: preset.foreground,
                                  ),
                                ),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Center(
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Color(preset.background),
                                      child:
                                          settings.backgroundColor ==
                                              preset.background
                                          ? const Icon(Icons.check, size: 14)
                                          : null,
                                    ),
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
      ),
    );
  }
}

/// Search panel. Owns its controller and result future so rebuilds (keyboard,
/// animations) never re-run the search or dispose a live controller.
class _SearchSheet extends StatefulWidget {
  const _SearchSheet({
    required this.strings,
    required this.search,
    required this.onSelect,
  });

  final ReaderStrings strings;
  final Future<NovelSearchResult> Function(String query) search;
  final Future<void> Function(NovelSearchHit hit) onSelect;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Future<NovelSearchResult>? _future;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final future = widget.search(_controller.text);
    setState(() {
      _future = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: strings.searchHint,
                  suffixIcon: IconButton(
                    tooltip: strings.search,
                    icon: const Icon(Icons.search),
                    onPressed: _submit,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            Expanded(
              child: FutureBuilder<NovelSearchResult>(
                future: _future,
                builder: (context, snap) {
                  if (_future == null) return const SizedBox.shrink();
                  if (snap.hasError) {
                    return Center(
                      child: Text('${strings.searchFailed}: ${snap.error}'),
                    );
                  }
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final result = snap.data ?? const NovelSearchResult();
                  final hits = result.hits;
                  if (hits.isEmpty && result.hiddenCount == 0) {
                    return Center(child: Text(strings.noResults));
                  }
                  return ListView.builder(
                    itemCount: hits.length + (result.hiddenCount > 0 ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == hits.length) {
                        return ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: Text(strings.outsideTrial(result.hiddenCount)),
                        );
                      }
                      final h = hits[i];
                      return ListTile(
                        title: Text(h.excerpt),
                        subtitle: h.chapterTitle == null
                            ? null
                            : Text(h.chapterTitle!),
                        onTap: () => widget.onSelect(h),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
