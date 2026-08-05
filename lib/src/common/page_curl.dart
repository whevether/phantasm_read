import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Simple page-curl style transition between two pages.
class PageCurl extends StatelessWidget {
  const PageCurl({
    super.key,
    required this.progress,
    required this.child,
    this.backChild,
  });

  /// 0 = fully shown, 1 = fully curled away.
  final double progress;
  final Widget child;
  final Widget? backChild;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final angle = t * math.pi / 2;
    return Stack(
      fit: StackFit.expand,
      children: [
        ?backChild,
        Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(-angle),
          child: child,
        ),
      ],
    );
  }
}

enum PageTurnEffect { none, curl }

/// Horizontal page view with optional curl effect on swipe.
class CurlPageView extends StatefulWidget {
  const CurlPageView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.onPageChanged,
    this.reverse = false,
    this.effect = PageTurnEffect.curl,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;
  final bool reverse;
  final PageTurnEffect effect;

  @override
  State<CurlPageView> createState() => _CurlPageViewState();
}

class _CurlPageViewState extends State<CurlPageView> {
  late PageController _controller;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PageController();
    _page = _controller.initialPage.toDouble();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    setState(() => _page = _controller.page ?? _page);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.effect == PageTurnEffect.none) {
      return PageView.builder(
        controller: _controller,
        itemCount: widget.itemCount,
        reverse: widget.reverse,
        onPageChanged: widget.onPageChanged,
        itemBuilder: widget.itemBuilder,
      );
    }

    return PageView.builder(
      controller: _controller,
      itemCount: widget.itemCount,
      reverse: widget.reverse,
      onPageChanged: widget.onPageChanged,
      itemBuilder: (context, index) {
        final delta = (_page - index).abs().clamp(0.0, 1.0);
        final child = widget.itemBuilder(context, index);
        if (delta < 0.001) return child;
        return PageCurl(progress: delta, child: child);
      },
    );
  }
}
