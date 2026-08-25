import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Simple page-curl / book-flip style transition.
class PageCurl extends StatelessWidget {
  const PageCurl({
    super.key,
    required this.progress,
    required this.child,
    this.backChild,
    this.hinge = Alignment.centerLeft,
  });

  /// 0 = flat, 1 = fully turned away.
  final double progress;
  final Widget child;
  final Widget? backChild;
  final Alignment hinge;

  bool get _fromLeft => hinge.x <= 0;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    if (t <= 0.001) return child;
    final angle = t * math.pi / 2 * (_fromLeft ? -1 : 1);
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (backChild != null)
          Positioned.fill(child: backChild!)
        else
          const SizedBox.expand(),
        Transform(
          alignment: hinge,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18 + t * 0.22),
                  blurRadius: 8 + t * 18,
                  offset: Offset(_fromLeft ? 4 + t * 10 : -(4 + t * 10), 0),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

enum PageTurnEffect { none, curl }

/// Horizontal page view with optional book-curl effect while swiping.
class CurlPageView extends StatefulWidget {
  const CurlPageView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.onPageChanged,
    this.reverse = false,
    this.effect = PageTurnEffect.curl,
    this.physics,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;
  final bool reverse;
  final PageTurnEffect effect;
  final ScrollPhysics? physics;

  @override
  State<CurlPageView> createState() => _CurlPageViewState();
}

class _CurlPageViewState extends State<CurlPageView> {
  late PageController _controller;
  double _page = 0;
  bool _ownsController = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
  }

  void _attachController(PageController? controller) {
    if (_listening) {
      _controller.removeListener(_onScroll);
      _listening = false;
    }
    if (_ownsController) {
      _controller.dispose();
    }
    _ownsController = controller == null;
    _controller = controller ?? PageController();
    _page = _controller.initialPage.toDouble();
    _controller.addListener(_onScroll);
    _listening = true;
  }

  @override
  void didUpdateWidget(covariant CurlPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _attachController(widget.controller);
    }
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    setState(() => _page = _controller.page ?? _page);
  }

  @override
  void dispose() {
    if (_listening) {
      _controller.removeListener(_onScroll);
      _listening = false;
    }
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Widget _wrapPage(int index) {
    final child = widget.itemBuilder(context, index);
    if (widget.effect == PageTurnEffect.none) return child;

    final page = _page;

    // Turning forward: page [index] curls left, reveals index + 1.
    if (page > index && page < index + 1) {
      final t = page - index;
      final back = index + 1 < widget.itemCount
          ? widget.itemBuilder(context, index + 1)
          : null;
      return PageCurl(
        progress: t,
        backChild: back,
        child: child,
      );
    }

    // Turning backward: page [index] curls right, reveals index - 1.
    if (page < index && page > index - 1) {
      final t = index - page;
      final back = index - 1 >= 0
          ? widget.itemBuilder(context, index - 1)
          : null;
      return PageCurl(
        progress: t,
        backChild: back,
        hinge: Alignment.centerRight,
        child: child,
      );
    }

    return child;
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.itemCount,
      reverse: widget.reverse,
      physics: widget.physics,
      onPageChanged: widget.onPageChanged,
      itemBuilder: (context, index) => _wrapPage(index),
    );
  }
}
