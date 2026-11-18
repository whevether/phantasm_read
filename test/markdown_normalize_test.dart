import 'package:flutter_test/flutter_test.dart';
import 'package:phantasm_read/src/novel/text/text_decoder.dart';

void main() {
  const decoder = NovelTextDecoder();
  String md(String s) => decoder.normalizeContent(s, kind: 'markdown');

  test('inline: links, images, emphasis, strike, code', () {
    expect(md('see [docs](http://a.b/c) now'), 'see docs now');
    expect(md('![cover](x.png) end'), 'cover end');
    expect(md('**b** *i* ~~s~~ `c` __u__ _v_'), 'b i s c u v');
    expect(md('snake_case_name stays'), 'snake_case_name stays');
  });

  test('blocks: headings, lists, quotes, rules, fences, tasks', () {
    final out = md(
      '# Title\n\n- one\n* two\n+ [x] three\n\n> quoted\n\n---\n\n'
      '```dart\nfinal a = 1;\n```\n\n1. first',
    );
    expect(out, contains('Title'));
    expect(out, isNot(contains('#')));
    expect(out, contains('\u2022 one'));
    expect(out, contains('\u2022 two'));
    expect(out, contains('\u2022 three'));
    expect(out, contains('quoted'));
    expect(out, isNot(contains('>')));
    expect(out, isNot(contains('---')));
    expect(out, isNot(contains('```')));
    expect(out, contains('final a = 1;'));
    expect(out, contains('1. first'));
  });

  test('setext headings and tables lose their syntax', () {
    final out = md('Heading\n=======\n\n| a | b |\n| --- | --- |\n| 1 | 2 |');
    expect(out, contains('Heading'));
    expect(out, isNot(contains('===')));
    expect(out, isNot(contains('---')));
    expect(out, contains('a  b'));
    expect(out, contains('1  2'));
  });

  test('heading extraction ignores link syntax', () {
    expect(
      decoder.extractHeadings('# [Intro](x) to **it**', kind: 'markdown'),
      ['Intro to it'],
    );
  });
}
