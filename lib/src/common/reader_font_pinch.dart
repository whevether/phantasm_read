import 'package:material_ui/material_ui.dart';

/// Pinch gesture that adjusts novel font size (not page scale).
///
/// Uses a two-finger scale recognizer so single-finger scroll / page-turn
/// gestures on the child are unaffected.
class ReaderFontPinchGesture extends StatefulWidget {
  const ReaderFontPinchGesture({
    super.key,
    required this.child,
    required this.fontSize,
    required this.onFontSizeChanged,
    this.minFontSize = 12,
    this.maxFontSize = 36,
  });

  final Widget child;
  final double fontSize;
  final ValueChanged<double> onFontSizeChanged;
  final double minFontSize;
  final double maxFontSize;

  @override
  State<ReaderFontPinchGesture> createState() => _ReaderFontPinchGestureState();
}

class _ReaderFontPinchGestureState extends State<ReaderFontPinchGesture> {
  double? _pinchBaseFontSize;

  void _onScaleStart(ScaleStartDetails details) {
    if (details.pointerCount < 2) return;
    _pinchBaseFontSize = widget.fontSize;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 || _pinchBaseFontSize == null) return;
    final next = (_pinchBaseFontSize! * details.scale).clamp(
      widget.minFontSize,
      widget.maxFontSize,
    );
    if ((next - widget.fontSize).abs() >= 0.05) {
      widget.onFontSizeChanged(next);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _pinchBaseFontSize = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: widget.child,
    );
  }
}
