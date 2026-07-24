import 'package:bakeneko/core/db/dao/category_dao.dart';
import 'package:bakeneko/core/db/dao/manga_dao.dart';
import 'package:bakeneko/core/db/database.dart';
import 'package:bakeneko/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

Manga _m(String url, {String title = 'T', String source = 'MANGADEX'}) =>
    Manga(source: source, url: url, title: title, coverUrl: 'c', blob: {
      'source': source,
      'url': url,
      'title': title,
      'coverUrl': 'c',
    });

void main() {
  late AppDatabase db;
  late CategoryDao categories;
  late MangaDao manga;

  setUp(() {
    db = AppDatabase.memory();
    categories = CategoryDao(db);
    manga = MangaDao(db);
  });
  tearDown(() => db.close());

  test('CategoryDao create asigna id y persiste', () {
    final id = categories.create('Shonen', '#a3b19b', now: 1000);
    expect(id, greaterThan(0));
    final list = categories.list();
    expect(list.length, 1);
    expect(list.first.name, 'Shonen');
    expect(list.first.color, '#a3b19b');
    expect(list.first.autoDownload, isFalse);
  });

  test('CategoryDao list ordena por created_at ASC', () {
    categories.create('A', '#1', now: 3000);
    categories.create('B', '#2', now: 1000); // más antiguo → primero
    final list = categories.list();
    // created_at ASC: B (1000) antes que A (3000)
    expect(list.map((c) => c.name).toList(), ['B', 'A']);
  });

  test('CategoryDao rename y delete', () {
    final id = categories.create('X', '#1', now: 1000);
    categories.rename(id, 'Y');
    expect(categories.list().first.name, 'Y');
    categories.delete(id);
    expect(categories.list(), isEmpty);
  });

  test('CategoryDao setAutoDownload togglea el flag', () {
    final id = categories.create('X', '#1', now: 1000);
    expect(categories.list().first.autoDownload, isFalse);
    categories.setAutoDownload(id, true);
    expect(categories.list().first.autoDownload, isTrue);
    categories.setAutoDownload(id, false);
    expect(categories.list().first.autoDownload, isFalse);
  });

  test('CategoryDao assign/unassign son idempotentes y forManga devuelve ids', () {
    final cat = categories.create('C', '#1', now: 1000);
    final m1 = manga.upsert(_m('/a'));
    final m2 = manga.upsert(_m('/b'));

    categories.assign(m1, cat);
    categories.assign(m1, cat); // idempotente (INSERT OR IGNORE)
    categories.assign(m2, cat);

    expect(categories.forManga(m1), [cat]);
    expect(categories.forManga(m2), [cat]);
    expect(categories.mangasIn(categoryId: cat), containsAll([m1, m2]));

    categories.unassign(m1, cat);
    expect(categories.forManga(m1), isEmpty);
    expect(categories.mangasIn(categoryId: cat), [m2]);
  });

  test('CategoryDao mangasIn(null) devuelve toda la biblioteca ordenada DESC', () {
    // Sin favoritos → vacío
    expect(categories.mangasIn(), isEmpty);

    final m1 = manga.upsert(_m('/a', title: 'A'), now: 1000);
    final m2 = manga.upsert(_m('/b', title: 'B'), now: 2000);
    manga.setFavorite(m1, true);
    manga.setFavorite(m2, true);

    final all = categories.mangasIn();
    expect(all.length, 2);
    // added_at DESC: B (2000) primero
    expect(all.first, m2);
  });

  test('MangaDao byCategory devuelve solo mangas de esa categoría ordenados DESC', () {
    final cat = categories.create('C', '#1', now: 1000);
    final m1 = manga.upsert(_m('/a', title: 'A'), now: 1000);
    final m2 = manga.upsert(_m('/b', title: 'B'), now: 2000);
    manga.upsert(_m('/c', title: 'C'), now: 3000); // no asignado
    categories.assign(m1, cat);
    categories.assign(m2, cat);

    final list = manga.byCategory(cat);
    expect(list.map((m) => m.title).toList(), ['B', 'A']); // DESC por added_at
    expect(list.any((m) => m.title == 'C'), isFalse);
  });
}
