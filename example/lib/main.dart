import 'dart:io';

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
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('漫画阅读器'),
            subtitle: const Text('extended_image + 亮度 / 不熄屏'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const _ComicDemoPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('小说阅读器（文本）'),
            subtitle: const Text('txt + 字体 / 亮度 / 不熄屏'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const _TextNovelDemoPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ComicDemoPage extends StatefulWidget {
  const _ComicDemoPage();

  @override
  State<_ComicDemoPage> createState() => _ComicDemoPageState();
}

class _ComicDemoPageState extends State<_ComicDemoPage> {
  ReaderSettings _settings = const ReaderSettings(brightness: 0.85);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comic')),
      body: ComicReader(
        pages: ComicPages.fromUrls(const [
          'https://picsum.photos/seed/phantasm1/800/1200',
          'https://picsum.photos/seed/phantasm2/800/1200',
          'https://picsum.photos/seed/phantasm3/800/1200',
          'https://picsum.photos/seed/phantasm4/800/1200',
        ]),
        readingMode: ComicReadingMode.vertical,
        settings: _settings,
        onSettingsChanged: (s) => setState(() => _settings = s),
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
  ReaderSettings _settings = const ReaderSettings(
    brightness: 0.9,
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
''';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/phantasm_sample.txt');
    await file.writeAsString(sample);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novel (text)')),
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
            source: NovelSource.text(snapshot.data!),
            settings: _settings,
            onSettingsChanged: (s) => setState(() => _settings = s),
          );
        },
      ),
    );
  }
}
