import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:phantasm_read/phantasm_read.dart';

import 'example_options.dart';
import 'example_settings_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PhantasmReadExampleApp());
}

class PhantasmReadExampleApp extends StatelessWidget {
  const PhantasmReadExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'phantasm_read example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4D3E)),
        useMaterial3: true,
      ),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final ExampleReaderOptions _options = ExampleReaderOptions();

  @override
  void dispose() {
    _options.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _options,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('phantasm_read')),
          body: ListView(
            children: [
              const ListTile(
                title: Text('0.0.1 演示'),
                subtitle: Text('常用功能默认开启 · 扩展能力见下方设置'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('漫画阅读器'),
                subtitle: Text(_comicSubtitle),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ComicDemoPage(options: _options),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('小说阅读器（文本）'),
                subtitle: Text(_novelSubtitle),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _TextNovelDemoPage(options: _options),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF 阅读器'),
                subtitle: Text(_pdfSubtitle),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _PdfDemoPage(options: _options),
                    ),
                  );
                },
              ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('示例设置'),
                subtitle: const Text('水印 / 手绘 / 高亮 / 同步 / 试读 / RTL 等'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showExampleSettingsSheet(context, _options),
              ),
              if (_options.comicInk ||
                  _options.novelInk ||
                  _options.novelHighlight ||
                  _options.comicSync ||
                  _options.novelSync)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '已启用：${_enabledLabels.join(' · ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String get _comicSubtitle {
    final tags = <String>['翻页', '缩放', '书签'];
    if (_options.comicInk) tags.add('手绘');
    if (_options.comicWatermark) tags.add('水印');
    if (_options.comicTrial) tags.add('试读');
    return tags.join(' · ');
  }

  String get _novelSubtitle {
    final tags = <String>['排版', '目录', 'TTS'];
    if (_options.novelHighlight) tags.add('高亮');
    if (_options.novelInk) tags.add('手绘');
    if (_options.novelWatermark) tags.add('水印');
    return tags.join(' · ');
  }

  String get _pdfSubtitle {
    final tags = <String>['pdf 3.13', '翻页'];
    if (_options.pdfWatermark) tags.add('水印');
    if (_options.pdfTrial) tags.add('试读');
    return tags.join(' · ');
  }

  List<String> get _enabledLabels {
    final out = <String>[];
    if (_options.comicInk) out.add('漫画手绘');
    if (_options.novelInk) out.add('小说手绘');
    if (_options.novelHighlight) out.add('段落高亮');
    if (_options.comicSync) out.add('漫画同步');
    if (_options.novelSync) out.add('小说同步');
    return out;
  }
}

void _showSyncSnack(BuildContext context, ReaderSyncPayload payload) {
  final n = payload.bookmarks.length;
  final page = payload.progress?.pageIndex;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'onSync · ${payload.bookId}'
        '${page != null ? ' · page $page' : ''}'
        '${n > 0 ? ' · bookmarks $n' : ''}',
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<void> _showExportDialog(BuildContext context, String bookId) async {
  final data = await ReaderBookmarkStore.instance.exportJson(bookId);
  if (!context.mounted) return;
  final pretty = const JsonEncoder.withIndent('  ').convert(data);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('exportJson · $bookId'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(child: SelectableText(pretty)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

class _ComicDemoPage extends StatefulWidget {
  const _ComicDemoPage({required this.options});

  final ExampleReaderOptions options;

  @override
  State<_ComicDemoPage> createState() => _ComicDemoPageState();
}

class _ComicDemoPageState extends State<_ComicDemoPage> {
  static const _bookId = 'demo_comic';

  ReaderSettings _settings = const ReaderSettings(
    brightness: 0.85,
    keepScreenOn: true,
  );

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    return AnimatedBuilder(
      animation: o,
      builder: (context, _) {
        final settings = _settings.copyWith(doublePage: o.comicDoublePage);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Comic'),
            actions: [
              IconButton(
                tooltip: '示例设置',
                icon: const Icon(Icons.tune),
                onPressed: () => showExampleSettingsSheet(context, o),
              ),
              IconButton(
                tooltip: '导出书签 JSON',
                icon: const Icon(Icons.ios_share_outlined),
                onPressed: () => _showExportDialog(context, _bookId),
              ),
            ],
          ),
          body: ComicReader(
            bookId: _bookId,
            pages: ComicPages.fromUrls(const [
              'https://picsum.photos/seed/phantasm1/800/1200',
              'https://picsum.photos/seed/phantasm2/800/1200',
              'https://picsum.photos/seed/phantasm3/800/1200',
              'https://picsum.photos/seed/phantasm4/800/1200',
              'https://picsum.photos/seed/phantasm5/800/1200',
            ]),
            readingMode: ComicReadingMode.vertical,
            settings: settings,
            rtl: o.comicRtl,
            persistSettings: false,
            maxReadablePages: o.comicMaxReadable,
            watermarkText: o.comicWatermarkText,
            enableInk: o.comicInk,
            pageTurnEffect: o.comicPageTurn,
            onSettingsChanged: (s) => setState(() => _settings = s),
            onSync: o.comicSync
                ? (payload) async {
                    if (!mounted) return;
                    _showSyncSnack(context, payload);
                  }
                : null,
          ),
        );
      },
    );
  }
}

String _buildSampleNovelText() {
  final buf = StringBuffer();
  const chapterTitles = [
    '启程',
    '林间',
    '溪畔',
    '山道',
    '驿站',
    '雨夜',
    '旧城',
    '集市',
    '塔楼',
    '渡口',
    '海风',
    '归途',
  ];
  for (var c = 0; c < chapterTitles.length; c++) {
    final n = c + 1;
    buf.writeln('第$n章 ${chapterTitles[c]}');
    buf.writeln();
    for (var p = 1; p <= 6; p++) {
      buf.writeln(
        '旅人沿着尘土飞扬的小路前行，靴底与碎石摩擦出细碎的声响。'
        '这是第$n章的第$p段：远处山峦在晨雾里起伏，像一页尚未写完的书。'
        '他想起昨夜篝火旁读过的句子，想起渡口老人说的那句「路还很长」。'
        '风从松林间穿过，带来潮湿的土腥与野花气息；他放慢脚步，'
        '把卷起的书页按平，继续向城门方向走去。',
      );
      buf.writeln();
      buf.writeln(
        '阳光渐渐升高，石板路上的影子缩短。偶尔有马车从身后驶过，'
        '扬起一阵灰，又很快落下。旅人抬头望向天空，云絮缓慢漂移，'
        '仿佛也在翻阅某种看不见的故事。他摸了摸行囊，确认书还在，'
        '便又低下头，把注意力放回脚下的每一步。',
      );
      buf.writeln();
    }
  }
  buf.writeln(
    '（示例文本共 ${chapterTitles.length} 章，可在工具栏切换竖读/横读测试翻页；'
    '首页「示例设置」可开启水印、手绘、高亮、同步等扩展能力。）',
  );
  return buf.toString();
}

class _TextNovelDemoPage extends StatefulWidget {
  const _TextNovelDemoPage({required this.options});

  final ExampleReaderOptions options;

  @override
  State<_TextNovelDemoPage> createState() => _TextNovelDemoPageState();
}

class _TextNovelDemoPageState extends State<_TextNovelDemoPage> {
  static const _bookId = 'demo_text_novel';

  ReaderSettings _settings = const ReaderSettings(
    brightness: 0.9,
    keepScreenOn: true,
    typography: NovelTypography(fontSize: 18, lineHeight: 1.7),
    backgroundColor: 0xFFFFF8E7,
    foregroundColor: 0xFF222222,
  );

  late final Uint8List _sampleBytes = Uint8List.fromList(
    utf8.encode(_buildSampleNovelText()),
  );

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    return AnimatedBuilder(
      animation: o,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Novel (text)'),
            actions: [
              IconButton(
                tooltip: '示例设置',
                icon: const Icon(Icons.tune),
                onPressed: () => showExampleSettingsSheet(context, o),
              ),
              IconButton(
                tooltip: '导出书签 JSON',
                icon: const Icon(Icons.ios_share_outlined),
                onPressed: () => _showExportDialog(context, _bookId),
              ),
            ],
          ),
          body: NovelReader(
            bookId: _bookId,
            source: NovelSource.textBytes(_sampleBytes, name: 'phantasm_sample.txt'),
            settings: _settings,
            persistSettings: false,
            maxReadablePages: o.novelMaxReadable,
            watermarkText: o.novelWatermarkText,
            enableInk: o.novelInk,
            enableHighlights: o.novelHighlight,
            rtl: o.novelRtl,
            onSettingsChanged: (s) => setState(() => _settings = s),
            onSync: o.novelSync
                ? (payload) async {
                    if (!mounted) return;
                    _showSyncSnack(context, payload);
                  }
                : null,
          ),
        );
      },
    );
  }
}

Uint8List _samplePdfBytes() {
  const objects = <String>[
    '1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj\n',
    '2 0 obj<< /Type /Pages /Kids [3 0 R 6 0 R 8 0 R] /Count 3 >>endobj\n',
    '3 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Contents 4 0 R /Resources<< /Font<< /F1 5 0 R >> >> >>endobj\n',
    '4 0 obj<< /Length 68 >>stream\n'
        'BT /F1 24 Tf 72 720 Td (phantasm_read PDF page 1) Tj ET\n'
        'endstream\nendobj\n',
    '5 0 obj<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>endobj\n',
    '6 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Contents 7 0 R /Resources<< /Font<< /F1 5 0 R >> >> >>endobj\n',
    '7 0 obj<< /Length 68 >>stream\n'
        'BT /F1 24 Tf 72 720 Td (phantasm_read PDF page 2) Tj ET\n'
        'endstream\nendobj\n',
    '8 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Contents 9 0 R /Resources<< /Font<< /F1 5 0 R >> >> >>endobj\n',
    '9 0 obj<< /Length 68 >>stream\n'
        'BT /F1 24 Tf 72 720 Td (phantasm_read PDF page 3) Tj ET\n'
        'endstream\nendobj\n',
  ];

  final body = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (final obj in objects) {
    offsets.add(body.length);
    body.write(obj);
  }
  final xref = body.length;
  body.write('xref\n0 ${objects.length + 1}\n');
  body.write('0000000000 65535 f \n');
  for (var i = 1; i < offsets.length; i++) {
    body.write('${offsets[i].toString().padLeft(10, '0')} 00000 n \n');
  }
  body.write(
    'trailer<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return Uint8List.fromList(utf8.encode(body.toString()));
}

class _PdfDemoPage extends StatelessWidget {
  const _PdfDemoPage({required this.options});

  final ExampleReaderOptions options;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: options,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('PDF'),
            actions: [
              IconButton(
                tooltip: '示例设置',
                icon: const Icon(Icons.tune),
                onPressed: () => showExampleSettingsSheet(context, options),
              ),
            ],
          ),
          body: PdfReader(
            bookId: 'demo_pdf',
            source: PdfSource.bytes(
              _samplePdfBytes(),
              name: 'phantasm_sample.pdf',
            ),
            maxReadablePages: options.pdfMaxReadable,
            watermarkText: options.pdfWatermarkText,
            rasterDpi: options.pdfRasterDpi,
            settings: const ReaderSettings(brightness: 0.9, keepScreenOn: true),
          ),
        );
      },
    );
  }
}
