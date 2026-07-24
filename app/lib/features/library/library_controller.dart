import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/models.dart';

enum LibraryFilter { all, unread, read, downloaded, notDownloaded }

/// Estado inmutable de la pantalla Biblioteca.
class LibraryState {
  const LibraryState({
    this.categories = const [],
    this.mangas = const [],
    this.filter = LibraryFilter.all,
  });

  /// Categorías existentes (sin incluir la implícita "Todas").
  final List<Category> categories;
  final List<Manga> mangas;
  final LibraryFilter filter;

  LibraryState copyWith({List<Category>? categories, List<Manga>? mangas, LibraryFilter? filter}) => LibraryState(
        categories: categories ?? this.categories,
        mangas: mangas ?? this.mangas,
        filter: filter ?? this.filter,
      );
}

/// Categoría activa de la biblioteca (null = "Todas"). Vive en un provider
/// aparte para sobrevivir a los rebuilds de [libraryProvider] tras mutaciones
/// desde otras pantallas (ej. marcar favorito en Detalles).
final libraryActiveCategoryProvider = StateProvider<int?>((_) => null);

/// Filtro activo.
final libraryFilterProvider = StateProvider<LibraryFilter>((_) => LibraryFilter.all);




class LibraryController extends Notifier<LibraryState> {
  @override
  LibraryState build() {
    // Refresca cuando la versión de biblioteca cambia (favoritos/categorías).
    ref.watch(libraryVersionProvider);
    // Y cuando la categoría activa o el filtro cambian.
    final activeId = ref.watch(libraryActiveCategoryProvider);
    final filter = ref.watch(libraryFilterProvider);
    
    final categories = ref.read(categoryDaoProvider).list();
    // Si la activa dejó de existir, caer a "Todas".
    final resolved = (activeId == null || categories.any((c) => c.id == activeId)) ? activeId : null;
    
    return LibraryState(
      categories: categories,
      mangas: _mangasFor(resolved, filter),
      filter: filter,
    );
  }

  List<Manga> _mangasFor(int? categoryId, LibraryFilter filter) {
    final mangaDao = ref.read(mangaDaoProvider);
    var list = categoryId == null ? mangaDao.favorites() : mangaDao.byCategory(categoryId);
    
    if (filter != LibraryFilter.all) {
      final chapterDao = ref.read(chapterDaoProvider);
      final downloadDao = ref.read(downloadDaoProvider);
      
      list = list.where((m) {
        final id = mangaDao.getId(m.source, m.url);
        if (id == null) return false;
        
        switch (filter) {
          case LibraryFilter.unread:
            final chapters = chapterDao.forManga(id);
            return chapters.any((c) => !c.read);
          case LibraryFilter.read:
            final chapters = chapterDao.forManga(id);
            return chapters.isNotEmpty && chapters.every((c) => c.read);
          case LibraryFilter.downloaded:
            final dls = downloadDao.forManga(id);
            return dls.any((d) => d.state == DownloadState.done);
          case LibraryFilter.notDownloaded:
            final dls = downloadDao.forManga(id);
            return !dls.any((d) => d.state == DownloadState.done);
          case LibraryFilter.all:
            return true;
        }
      }).toList();
    }
    
    return list;
  }

  void selectCategory(int? id) =>
      ref.read(libraryActiveCategoryProvider.notifier).state = id;

  void setFilter(LibraryFilter filter) =>
      ref.read(libraryFilterProvider.notifier).state = filter;

  void createCategory(String name, String color) {
    ref.read(categoryDaoProvider).create(name, color);
    _bump();
  }

  void renameCategory(int id, String name) {
    ref.read(categoryDaoProvider).rename(id, name);
    _bump();
  }

  void deleteCategory(int id) {
    ref.read(categoryDaoProvider).delete(id);
    // No reseteamos libraryActiveCategoryProvider aquí: build() recalcula
    // `resolved` y, si la categoría activa dejó de existir, cae a "Todas".
    // (Leer el StateProvider aquí chocaría con la aserción de Riverpod sobre
    // providers dirty en el mismo ciclo síncrono.)
    _bump();
  }

  void toggleAutoDownload(int id) {
    final cat = state.categories.where((c) => c.id == id).firstOrNull;
    if (cat == null) return;
    ref.read(categoryDaoProvider).setAutoDownload(id, !cat.autoDownload);
    _bump();
  }

  void toggleCategoryForManga(Manga manga, int categoryId, bool assign) {
    final mangaDao = ref.read(mangaDaoProvider);
    final id = mangaDao.getId(manga.source, manga.url);
    if (id == null) return;
    
    final catDao = ref.read(categoryDaoProvider);
    if (assign) {
      catDao.assign(id, categoryId);
    } else {
      catDao.unassign(id, categoryId);
    }
    _bump();
  }

  List<int> getCategoriesForManga(Manga manga) {
    final mangaDao = ref.read(mangaDaoProvider);
    final id = mangaDao.getId(manga.source, manga.url);
    if (id == null) return [];
    return ref.read(categoryDaoProvider).forManga(id);
  }

  void _bump() => ref.read(libraryVersionProvider.notifier).state++;
}

final libraryProvider = NotifierProvider<LibraryController, LibraryState>(LibraryController.new);
