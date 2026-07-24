import 'package:bakeneko/app.dart';
import 'package:bakeneko/core/db/dao/category_dao.dart';
import 'package:bakeneko/core/db/dao/manga_dao.dart';
import 'package:bakeneko/core/db/database.dart';
import 'package:bakeneko/core/models.dart';
import 'package:bakeneko/features/library/library_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.memory();
    final manga = MangaDao(db);
    final categories = CategoryDao(db);
    container = ProviderContainer(overrides: [
      mangaDaoProvider.overrideWithValue(manga),
      categoryDaoProvider.overrideWithValue(categories),
    ]);
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  LibraryState readState() => container.read(libraryProvider);

  test('build inicial sin categorías y con biblioteca vacía', () {
    final s = readState();
    expect(s.categories, isEmpty);
    expect(s.mangas, isEmpty);
    expect(container.read(libraryActiveCategoryProvider), isNull);
  });

  test('createCategory persiste y refresca el estado', () {
    readState(); // inicializa
    container.read(libraryProvider.notifier).createCategory('Seinen', '#a3b19b');
    final s = readState();
    expect(s.categories.length, 1);
    expect(s.categories.first.name, 'Seinen');
  });

  test('selectCategory filtra los mangas a la categoría activa', () {
    final mangaDao = container.read(mangaDaoProvider);
    final catDao = container.read(categoryDaoProvider);
    final m1 = mangaDao.upsert(_m('/a', title: 'A'));
    mangaDao.setFavorite(m1, true);
    final cat = catDao.create('C', '#1');

    // "Todas" muestra el favorito
    expect(readState().mangas.length, 1);

    // asignamos y seleccionamos la categoría (vacía)
    catDao.assign(m1, cat);
    container.read(libraryProvider.notifier).selectCategory(cat);
    expect(readState().mangas.map((m) => m.title), ['A']);

    // volvemos a "Todas"
    container.read(libraryProvider.notifier).selectCategory(null);
    expect(readState().mangas.length, 1);
  });

  test('deleteCategory cae a "Todas" si era la activa', () {
    final mangaDao = container.read(mangaDaoProvider);
    final catDao = container.read(categoryDaoProvider);
    final m1 = mangaDao.upsert(_m('/a', title: 'A'));
    mangaDao.setFavorite(m1, true);
    final cat = catDao.create('C', '#1');
    catDao.assign(m1, cat);

    // Seleccionamos la categoría (muestra A)
    container.read(libraryProvider.notifier).selectCategory(cat);
    expect(readState().mangas.map((m) => m.title), ['A']);

    // La borramos: build() detecta que ya no existe y cae a "Todas" (favoritos)
    container.read(libraryProvider.notifier).deleteCategory(cat);
    final s = readState();
    expect(s.categories, isEmpty);
    expect(s.mangas.map((m) => m.title), ['A']); // sigue visible, ahora vía favoritos
  });

  test('renameCategory y toggleAutoDownload refrescan', () {
    final catDao = container.read(categoryDaoProvider);
    final cat = catDao.create('C', '#1');
    container.read(libraryProvider.notifier).renameCategory(cat, 'Renombrada');
    expect(readState().categories.first.name, 'Renombrada');

    expect(readState().categories.first.autoDownload, isFalse);
    container.read(libraryProvider.notifier).toggleAutoDownload(cat);
    expect(readState().categories.first.autoDownload, isTrue);
  });
}
