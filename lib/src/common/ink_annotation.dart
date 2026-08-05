import 'package:flutter/material.dart';

/// A freehand ink stroke for annotations.
class InkStroke {
  const InkStroke({
    required this.points,
    this.color = 0xFFE53935,
    this.width = 3,
  });

  final List<Offset> points;
  final int color;
  final double width;

  Map<String, dynamic> toJson() => {
        'color': color,
        'width': width,
        'points': [
          for (final p in points) {'x': p.dx, 'y': p.dy},
        ],
      };

  factory InkStroke.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (e) => Offset(
            (e['x'] as num).toDouble(),
            (e['y'] as num).toDouble(),
          ),
        )
        .toList();
    return InkStroke(
      points: pts,
      color: json['color'] as int? ?? 0xFFE53935,
      width: (json['width'] as num?)?.toDouble() ?? 3,
    );
  }
}

/// Overlay canvas for pen annotations with undo.
class InkAnnotationLayer extends StatefulWidget {
  const InkAnnotationLayer({
    super.key,
    required this.enabled,
    this.initialStrokes = const [],
    this.onChanged,
    this.color = const Color(0xFFE53935),
    this.strokeWidth = 3,
  });

  final bool enabled;
  final List<InkStroke> initialStrokes;
  final ValueChanged<List<InkStroke>>? onChanged;
  final Color color;
  final double strokeWidth;

  @override
  State<InkAnnotationLayer> createState() => InkAnnotationLayerState();
}

class InkAnnotationLayerState extends State<InkAnnotationLayer> {
  late List<InkStroke> _strokes = List.of(widget.initialStrokes);
  final List<Offset> _current = [];

  List<InkStroke> get strokes => List.unmodifiable(_strokes);

  void undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes = _strokes.sublist(0, _strokes.length - 1));
    widget.onChanged?.call(_strokes);
  }

  void clear() {
    setState(() => _strokes = []);
    widget.onChanged?.call(_strokes);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          _current
            ..clear()
            ..add(d.localPosition);
          setState(() {});
        },
        onPanUpdate: (d) {
          _current.add(d.localPosition);
          setState(() {});
        },
        onPanEnd: (_) {
          if (_current.length >= 2) {
            _strokes = [
              ..._strokes,
              InkStroke(
                points: List.of(_current),
                color: _colorToArgb(widget.color),
                width: widget.strokeWidth,
              ),
            ];
            widget.onChanged?.call(_strokes);
          }
          _current.clear();
          setState(() {});
        },
        child: CustomPaint(
          painter: _InkPainter(
            strokes: _strokes,
            current: _current,
            color: widget.color,
            width: widget.strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter({
    required this.strokes,
    required this.current,
    required this.color,
    required this.width,
  });

  final List<InkStroke> strokes;
  final List<Offset> current;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      _draw(canvas, s.points, Color(s.color), s.width);
    }
    if (current.length >= 2) {
      _draw(canvas, current, color, width);
    }
  }

  void _draw(Canvas canvas, List<Offset> pts, Color c, double w) {
    final paint = Paint()
      ..color = c
      ..strokeWidth = w
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) => true;
}

int _colorToArgb(Color c) {
  return ((c.a * 255).round() << 24) |
      ((c.r * 255).round() << 16) |
      ((c.g * 255).round() << 8) |
      (c.b * 255).round();
}
