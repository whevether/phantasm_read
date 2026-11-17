import 'package:flutter_test/flutter_test.dart';
import 'package:phantasm_read/phantasm_read.dart';
import 'package:phantasm_read/src/common/reader_kv.dart';
import 'package:tostore/tostore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ToStore db;

  setUp(() async {
    db = await ToStore.memory(dbName: 'reader_kv_test', reinitialize: true);
    ReaderKv.useDatabaseForTesting(db);
  });
  tearDown(() async {
    await ReaderKv.useMemoryForTesting();
    await db.close(flush: false);
  });

  test('Progress, bookmarks and settings round-trip through ToStore', () async {
    await ReaderProgressStore.instance.save(
      const ReaderProgress(bookId: 'b', pageIndex: 3, percentage: 0.5),
    );
    expect((await ReaderProgressStore.instance.load('b'))!.pageIndex, 3);
    await ReaderProgressStore.instance.clear('b');
    expect(await ReaderProgressStore.instance.load('b'), isNull);

    await ReaderBookmarkStore.instance.addBookmark(
      const ReaderBookmark(id: '1', bookId: 'b', title: 't', pageIndex: 2),
    );
    expect(await ReaderBookmarkStore.instance.listBookmarks('b'), hasLength(1));

    await ReaderSettingsStore.instance.save(
      const ReaderSettings(comicAutoCrop: true),
    );
    expect((await ReaderSettingsStore.instance.load())!.comicAutoCrop, isTrue);
  });

  test('Ink export finds keys by prefix', () async {
    await ReaderInkStore.instance.save('b', 'p1', const []);
    expect((await ReaderInkStore.instance.exportJson('b')).keys, ['p1']);
  });
}
