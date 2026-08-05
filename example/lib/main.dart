import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phantasm_read/phantasm_read.dart';

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

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('phantasm_read')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('0.0.1 演示'),
            subtitle: Text('水印 / 试读 / 手绘 / 同步 / PDF'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('漫画阅读器'),
            subtitle: const Text('水印 · 试读 · 手绘 · onSync'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const _ComicDemoPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('小说阅读器（文本）'),
            subtitle: const Text('主题 · TTS · 导出 JSON · 同步'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _TextNovelDemoPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('PDF 阅读器'),
            subtitle: const Text('WebView · 水印 · 试读提示'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const _PdfDemoPage()),
              );
            },
          ),
        ],
      ),
    );
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
  const _ComicDemoPage();

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comic'),
        actions: [
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
        settings: _settings,
        maxReadablePages: 3,
        watermarkText: 'phantasm_read · demo',
        enableInk: true,
        onSettingsChanged: (s) => setState(() => _settings = s),
        onSync: (payload) async {
          if (!mounted) return;
          _showSyncSnack(context, payload);
        },
      ),
    );
  }
}

class _TextNovelDemoPage extends StatefulWidget {
  const _TextNovelDemoPage();

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
  Future<String>? _pathFuture;

  @override
  void initState() {
    super.initState();
    _pathFuture = _prepareSampleText();
  }

  Future<String> _prepareSampleText() async {
    const sample = '''
第一章 启程

晨光穿过薄雾，落在石板路上。旅人收紧斗篷，把一卷旧书塞进行囊。

「路还很长。」他低声说，迈出了第一步。

第二章 林间

风过松林，发出细碎的声响。他在溪边坐下，翻开书页——文字像溪水一样流淌。

夜色降临时，篝火旁的字号似乎也跟着跳动。他调亮灯火，继续读下去。

第三章 城门

城墙上旗帜翻飞。他把书收好，抬头望向开敞的城门。

（本示例演示水印、同步回调与书签导出。）
''';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/phantasm_sample.txt');
    await file.writeAsString(sample);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novel (text)'),
        actions: [
          IconButton(
            tooltip: '导出书签 JSON',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => _showExportDialog(context, _bookId),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _pathFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          return NovelReader(
            bookId: _bookId,
            source: NovelSource.text(snapshot.data!),
            settings: _settings,
            watermarkText: 'phantasm_read · novel',
            enableInk: true,
            onSettingsChanged: (s) => setState(() => _settings = s),
            onSync: (payload) async {
              if (!mounted) return;
              _showSyncSnack(context, payload);
            },
          );
        },
      ),
    );
  }
}

/// Minimal multi-page PDF for WebView demo (no asset file required).
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
  const _PdfDemoPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF')),
      body: PdfReader(
        bookId: 'demo_pdf',
        source: PdfSource.bytes(_samplePdfBytes(), name: 'phantasm_sample.pdf'),
        maxReadablePages: 2,
        watermarkText: 'phantasm_read · pdf',
        settings: const ReaderSettings(brightness: 0.9, keepScreenOn: true),
      ),
    );
  }
}
