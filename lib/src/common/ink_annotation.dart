import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import 'package:material_ui/material_ui.dart';

/// A freehand ink stroke for annotations.
class InkStroke {
  const InkStroke({
    required this.points,
    this.color = 0xFFE53935,
    this.width = 3,
    this.normalized = false,
  });

  final List<Offset> points;
  final int color;
  final double width;
  final bool normalized;

  Map<String, dynamic> toJson() => {
    'normalized': normalized,
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
          (e) => Offset((e['x'] as num).toDouble(), (e['y'] as num).toDouble()),
        )
        .toList();
    return InkStroke(
      points: pts,
      normalized: json['normalized'] as bool? ?? false,
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
  Size _canvasSize = Size.zero;

  @override
  void didUpdateWidget(covariant InkAnnotationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStrokes != widget.initialStrokes) {
      _strokes = List.of(widget.initialStrokes);
      _current.clear();
    }
  }

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          _canvasSize = constraints.biggest;
          return GestureDetector(
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
                    normalized: true,
                    points: _current
                        .map(
                          (p) => Offset(
                            p.dx / _canvasSize.width,
                            p.dy / _canvasSize.height,
                          ),
                        )
                        .toList(),
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
          );
        },
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
      _draw(
        canvas,
        s.normalized
            ? s.points
                  .map((p) => Offset(p.dx * size.width, p.dy * size.height))
                  .toList()
            : s.points,
        Color(s.color),
        s.width,
      );
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
    if (pts.isEmpty) return;
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

/// Storage and JSON export for page/CFI anchored ink.
class ReaderInkStore {
  ReaderInkStore._();
  static final instance = ReaderInkStore._();
  final _writes = Lock();
  String _key(String bookId, String location) =>
      'phantasm_ink_${jsonEncode([bookId, location])}';
  Future<List<InkStroke>> load(String bookId, String location) =>
      _writes.synchronized(() async {
        try {
          final raw = (await SharedPreferences.getInstance()).getString(
            _key(bookId, location),
          );
          if (raw == null) return <InkStroke>[];
          return (jsonDecode(raw) as List)
              .map(
                (e) => InkStroke.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        } catch (_) {
          return <InkStroke>[];
        }
      });
  Future<void> save(String bookId, String location, List<InkStroke> strokes) {
    final raw = jsonEncode(strokes.map((s) => s.toJson()).toList());
    return _writes.synchronized(() async {
      await (await SharedPreferences.getInstance()).setString(
        _key(bookId, location),
        raw,
      );
    });
  }

  Future<Map<String, dynamic>> exportJson(String bookId) =>
      _writes.synchronized(() async {
        final prefs = await SharedPreferences.getInstance();
        final result = <String, dynamic>{};
        for (final key in prefs.getKeys().where(
          (k) => k.startsWith('phantasm_ink_'),
        )) {
          try {
            final pair =
                jsonDecode(key.substring('phantasm_ink_'.length)) as List;
            if (pair.length == 2 && pair[0] == bookId) {
              result[pair[1] as String] = jsonDecode(prefs.getString(key)!);
            }
          } catch (_) {
            /* Leave unrelated or invalid legacy keys unchanged. */
          }
        }
        return result;
      });
}

/// Persists page-anchored normalized ink and exposes undo/clear while editing.
class ReaderInk extends StatefulWidget {
  const ReaderInk({
    super.key,
    required this.bookId,
    required this.location,
    required this.enabled,
  });
  final String bookId;
  final String location;
  final bool enabled;
  @override
  State<ReaderInk> createState() => _ReaderInkState();
}

class _ReaderInkState extends State<ReaderInk> {
  final _layer = GlobalKey<InkAnnotationLayerState>();
  List<InkStroke> _strokes = const [];
  bool _ready = false;
  int _version = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReaderInk oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId ||
        oldWidget.location != widget.location) {
      _ready = false;
      _strokes = [];
      _load();
    }
  }

  Future<void> _load() async {
    final version = ++_version;
    final loaded = await ReaderInkStore.instance.load(
      widget.bookId,
      widget.location,
    );
    if (mounted && version == _version) {
      setState(() {
        _strokes = loaded;
        _ready = true;
      });
    }
  }

  void _save(List<InkStroke> strokes) {
    ReaderInkStore.instance.save(widget.bookId, widget.location, strokes);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !_ready) return const SizedBox.shrink();
    return Positioned.fill(
      child: Stack(
        children: [
          InkAnnotationLayer(
            key: _layer,
            enabled: true,
            initialStrokes: _strokes,
            onChanged: _save,
          ),
          Positioned(
            top: 24,
            right: 12,
            child: Material(
              color: Colors.black54,
              child: Row(
                children: [
                  IconButton(
                    tooltip: '撤销笔迹',
                    onPressed: () => _layer.currentState?.undo(),
                    icon: const Icon(Icons.undo, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: '清空笔迹',
                    onPressed: () => _layer.currentState?.clear(),
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
