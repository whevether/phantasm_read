import 'package:flutter/material.dart';

import '../common/reader_brightness.dart';
import '../common/reader_lifecycle.dart';
import '../common/reader_settings.dart';
import '../common/reader_wake_lock.dart';
import 'epub/epub_viewer.dart';
import 'novel_source.dart';
import 'text/text_reader.dart';

/// Novel reader for EPUB and common text formats.
class NovelReader extends StatefulWidget {
  const NovelReader({
    super.key,
    required this.source,
    this.settings = const ReaderSettings(),
    this.encoding,
    this.initialCfi,
    this.onSettingsChanged,
    this.onLocationChanged,
    this.showToolbar = true,
  });

  final NovelSource source;
  final ReaderSettings settings;
  final String? encoding;
  final String? initialCfi;
  final ValueChanged<ReaderSettings>? onSettingsChanged;
  final ValueChanged<String?>? onLocationChanged;
  final bool showToolbar;

  @override
  State<NovelReader> createState() => _NovelReaderState();
}

class _NovelReaderState extends State<NovelReader>
    with WidgetsBindingObserver {
  late final ReaderBrightness _brightness = ReaderBrightness();
  late ReaderSettings _settings;
  bool _toolbarVisible = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    WidgetsBinding.instance.addObserver(this);
    _enterReading();
  }

  Future<void> _enterReading() async {
    await _brightness.apply(_settings.brightness);
    if (_settings.keepScreenOn) {
      await ReaderWakeLock.enable();
    }
  }

  Future<void> _leaveReading() async {
    await _brightness.restore();
    await ReaderWakeLock.disable();
  }

  @override
  void didUpdateWidget(covariant NovelReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _settings = widget.settings;
      _brightness.apply(_settings.brightness);
      if (_settings.keepScreenOn) {
        ReaderWakeLock.enable();
      } else {
        ReaderWakeLock.disable();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ReaderWakeLock.disable();
    } else if (state == AppLifecycleState.resumed && _settings.keepScreenOn) {
      ReaderWakeLock.enable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _leaveReading();
    _brightness.dispose();
    super.dispose();
  }

  void _emitSettings(ReaderSettings next) {
    setState(() => _settings = next);
    _brightness.apply(next.brightness);
    if (next.keepScreenOn) {
      ReaderWakeLock.enable();
    } else {
      ReaderWakeLock.disable();
    }
    widget.onSettingsChanged?.call(next);
  }

  Color? _color(int? value) => value == null ? null : Color(value);

  Widget _buildContent() {
    final source = widget.source;
    final bg = _color(_settings.backgroundColor);
    final fg = _color(_settings.foregroundColor);

    return switch (source) {
      NovelSourceEpub(:final path) => EpubViewer(
          filePath: path,
          typography: _settings.typography,
          initialCfi: widget.initialCfi,
          backgroundColor: bg,
          foregroundColor: fg,
          onLocationChanged: widget.onLocationChanged,
        ),
      NovelSourceText(:final path) => TextReader(
          filePath: path,
          kind: 'text',
          typography: _settings.typography,
          encoding: widget.encoding,
          backgroundColor: bg,
          foregroundColor: fg,
        ),
      NovelSourceMarkdown(:final path) => TextReader(
          filePath: path,
          kind: 'markdown',
          typography: _settings.typography,
          encoding: widget.encoding,
          backgroundColor: bg,
          foregroundColor: fg,
        ),
      NovelSourceHtml(:final path) => TextReader(
          filePath: path,
          kind: 'html',
          typography: _settings.typography,
          encoding: widget.encoding,
          backgroundColor: bg,
          foregroundColor: fg,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _brightness,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (!widget.showToolbar) return;
                setState(() => _toolbarVisible = !_toolbarVisible);
              },
              child: _buildContent(),
            ),
            BrightnessOverlay(
              brightness: _brightness.value,
              mode: _brightness.mode,
            ),
            if (widget.showToolbar && _toolbarVisible)
              _NovelToolbar(
                settings: _settings,
                onSettingsChanged: _emitSettings,
              ),
          ],
        );
      },
    );
  }
}

class _NovelToolbar extends StatelessWidget {
  const _NovelToolbar({
    required this.settings,
    required this.onSettingsChanged,
  });

  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final t = settings.typography;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        color: Colors.black54,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    IconButton(
                      tooltip: 'Keep screen on',
                      onPressed: () => onSettingsChanged(
                        settings.copyWith(keepScreenOn: !settings.keepScreenOn),
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
                Row(
                  children: [
                    const Text('A-', style: TextStyle(color: Colors.white)),
                    Expanded(
                      child: Slider(
                        min: 12,
                        max: 36,
                        value: t.fontSize.clamp(12, 36),
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
