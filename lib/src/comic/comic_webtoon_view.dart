import 'package:material_ui/material_ui.dart';

/// Height reserved for a webtoon page whose image has not loaded yet.
double comicWebtoonPlaceholderHeight(BuildContext context) =>
    MediaQuery.sizeOf(context).width * 1.4;

/// Imperative handle for [ComicWebtoonView].
class ComicWebtoonController {
  _ComicWebtoonViewState? _state;

  /// Scrolls so that item [index] is at the top of the viewport.
  void jumpToIndex(int index) => _state?._jumpTo(index);

  /// Whether the controller is attached to a mounted view.
  bool get isAttached => _state != null;
}

/// Continuous vertical strip (webtoon) list that reports the item at the viewport center.
class ComicWebtoonView extends StatefulWidget {
  const ComicWebtoonView({
    super.key,
    required this.count,
    required this.itemBuilder,
    required this.onIndexChanged,
    this.initialIndex = 0,
    this.controller,
    this.onReachedEnd,
    this.onReachedStart,
    this.placeholderAspect = 1.4,
    this.gap = 0,
    this.cacheExtent,
  });

  final int count;
  final Widget Function(int index) itemBuilder;
  final ValueChanged<int> onIndexChanged;
  final int initialIndex;

  /// Lets the host scroll to an item (slider seek, bookmarks, thumbnails).
  final ComicWebtoonController? controller;

  /// Called when the user scrolls to (or past) the end of the strip.
  final VoidCallback? onReachedEnd;

  /// Called when the user scrolls to (or past) the start of the strip.
  final VoidCallback? onReachedStart;

  /// Height/width ratio assumed for items that were never laid out; used to
  /// estimate the scroll offset when jumping to a far away item. Item builders
  /// should reserve a similar height while their image loads (see
  /// [comicWebtoonPlaceholderHeight]) so the lazy list does not build every
  /// item at once.
  final double placeholderAspect;

  /// Empty space (logical pixels) between pages.
  final double gap;

  /// How far beyond the viewport pages are built/preloaded (logical pixels);
  /// `null` keeps the framework default.
  final double? cacheExtent;

  @override
  State<ComicWebtoonView> createState() => _ComicWebtoonViewState();
}

class _ComicWebtoonViewState extends State<ComicWebtoonView> {
  late final ScrollController _controller;
  final Map<int, GlobalKey> _keys = {};
  final Map<int, double> _heights = {};
  int _last = -1;
  bool _atEnd = false;
  bool _atStart = true;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    widget.controller?._state = this;
    final start = widget.initialIndex.clamp(
      0,
      widget.count > 0 ? widget.count - 1 : 0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(start));
  }

  @override
  void didUpdateWidget(covariant ComicWebtoonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
    if (oldWidget.count != widget.count) {
      // The readable window changed: drop stale per-item state.
      _keys.removeWhere((i, _) => i >= widget.count);
      _heights.removeWhere((i, _) => i >= widget.count);
      _last = -1;
      final target = widget.initialIndex.clamp(
        0,
        widget.count > 0 ? widget.count - 1 : 0,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(target));
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    _controller.dispose();
    super.dispose();
  }

  double _placeholderHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).width * widget.placeholderAspect;

  double _estimatedOffset(int index) {
    var offset = 0.0;
    final fallback = _placeholderHeight(context);
    for (var i = 0; i < index; i++) {
      offset += _heights[i] ?? fallback;
    }
    return offset;
  }

  void _jumpTo(int index) {
    if (!mounted || widget.count <= 0) return;
    final target = index.clamp(0, widget.count - 1);
    final ctx = _keys[target]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx);
      return;
    }
    if (!_controller.hasClients) return;
    final position = _controller.position;
    position.jumpTo(
      _estimatedOffset(target).clamp(0.0, position.maxScrollExtent),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _keys[target]?.currentContext;
      if (mounted && c != null) Scrollable.ensureVisible(c);
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n is! ScrollUpdateNotification &&
        n is! ScrollEndNotification &&
        n is! OverscrollNotification) {
      return false;
    }
    // Notifications fire before relayout; measure after the frame is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportCenter());
    final m = n.metrics;
    final end = m.pixels >= m.maxScrollExtent - 1;
    final start = m.pixels <= m.minScrollExtent + 1;
    if (end && (!_atEnd || n is OverscrollNotification)) {
      widget.onReachedEnd?.call();
    }
    if (start && (!_atStart || n is OverscrollNotification)) {
      widget.onReachedStart?.call();
    }
    _atEnd = end;
    _atStart = start;
    return false;
  }

  void _reportCenter() {
    if (!mounted) return;
    final viewport = context.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.attached) return;
    final mid =
        viewport.localToGlobal(Offset.zero).dy + viewport.size.height / 2;
    int? hit;
    for (final e in _keys.entries) {
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      _heights[e.key] = box.size.height;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= mid && mid < top + box.size.height) {
        hit = e.key;
      }
    }
    if (hit != null && hit != _last) {
      _last = hit;
      widget.onIndexChanged(hit);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.builder(
        controller: _controller,
        itemCount: widget.count,
        scrollCacheExtent: widget.cacheExtent == null
            ? null
            : ScrollCacheExtent.pixels(widget.cacheExtent!),
        itemBuilder: (context, i) => KeyedSubtree(
          key: _keys.putIfAbsent(i, GlobalKey.new),
          child: widget.gap > 0 && i < widget.count - 1
              ? Padding(
                  padding: EdgeInsets.only(bottom: widget.gap),
                  child: widget.itemBuilder(i),
                )
              : widget.itemBuilder(i),
        ),
      ),
    );
  }
}
