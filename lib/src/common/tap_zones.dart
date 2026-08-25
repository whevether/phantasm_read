import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// Hide system UI while reading; restore on exit.
class ReaderImmersive {
  const ReaderImmersive._();

  static Future<void> enter() {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static Future<void> leave() {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

/// Left / center / right tap zones for paging and toolbar.
enum TapZoneAction { previous, toggleToolbar, next }

class TapZoneDetector {
  const TapZoneDetector({this.enabled = true, this.rtl = false});

  final bool enabled;
  final bool rtl;

  TapZoneAction resolve(Offset local, Size size) {
    if (!enabled || size.width <= 0) return TapZoneAction.toggleToolbar;
    final x = local.dx / size.width;
    if (x < 1 / 3) {
      return rtl ? TapZoneAction.next : TapZoneAction.previous;
    }
    if (x > 2 / 3) {
      return rtl ? TapZoneAction.previous : TapZoneAction.next;
    }
    return TapZoneAction.toggleToolbar;
  }
}

/// Thin progress bar (0–1). Drag to seek when [onSeek] provided.
class ReaderProgressBar extends StatelessWidget {
  const ReaderProgressBar({
    super.key,
    required this.progress,
    this.onSeek,
    this.color = const Color(0xFF4CAF50),
  });

  final double progress;
  final ValueChanged<double>? onSeek;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onSeek == null
              ? null
              : (d) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final w = box.size.width;
                  if (w <= 0) return;
                  onSeek!((d.localPosition.dx / w).clamp(0.0, 1.0));
                },
          onHorizontalDragUpdate: onSeek == null
              ? null
              : (d) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final w = box.size.width;
                  if (w <= 0) return;
                  onSeek!((d.localPosition.dx / w).clamp(0.0, 1.0));
                },
          child: SizedBox(
            height: 12,
            child: Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                value: p,
                minHeight: 2,
                backgroundColor: Colors.black26,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
