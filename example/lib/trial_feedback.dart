import 'package:material_ui/material_ui.dart';
import 'package:phantasm_read/phantasm_read.dart';

/// How the example app reacts when [onTrialLimitReached] fires.
enum ExampleTrialFeedback {
  dialog,
  snackbar,
  none,
}

String trialLimitMessage(ReaderTrialLimitEvent event) {
  final limit = event.limit;
  final unit = limit.unit == ReaderTrialUnit.chapter ? '章' : '页';
  final from = limit.startIndex + 1;
  final to = limit.startIndex + limit.maxCount;
  final action = switch (event.action) {
    ReaderTrialLimitAction.next => '继续阅读',
    ReaderTrialLimitAction.seek => '跳转',
    ReaderTrialLimitAction.chapterSelect => '打开章节',
    ReaderTrialLimitAction.search => '搜索结果',
  };
  return '$action 已超出试读范围（可读 $from–$to $unit，共 ${event.totalCount} $unit）';
}

void handleTrialLimit(
  BuildContext context,
  ExampleTrialFeedback mode,
  ReaderTrialLimitEvent event,
) {
  if (mode == ExampleTrialFeedback.none) return;
  final message = trialLimitMessage(event);
  switch (mode) {
    case ExampleTrialFeedback.snackbar:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
    case ExampleTrialFeedback.dialog:
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('试读限制'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    case ExampleTrialFeedback.none:
      break;
  }
}
