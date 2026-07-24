import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/models.dart';

/// Estado inmutable de la pantalla Biblioteca.
class LibraryState {
  const LibraryState({
    this.categories = const [],
    this.mangas = const [],
  });

  /// Categorías existentes (sin incluir la implícita "Todas").
  final List<Category> categories;
  final List<Manga> mangas;

  LibraryState copyWith({List<Category>? categories, List<Manga>? mangas}) => LibraryState(
        categories: categories ?? this.categories,
        mangas: mangas ?? this.mangas,
      );
}

/// Categoría activa de la biblioteca (null = "Todas"). Vive en un provider
/// aparte para sobrevivir a los rebuilds de [libraryProvider] tras mutaciones
/// desde otras pantallas (ej. marcar favorito en Detalles).
final libraryActiveCategoryProvider = StateProvider<int?>((_) => null);

class LibraryController extends Notifier<LibraryState> {
  @override
  LibraryState build() {
    // Refresca cuando la versión de biblioteca cambia (favoritos/categorías).
    ref.watch(libraryVersionProvider);
    // Y cuando la categoría activa cambia (vía StateProvider separado).
    final activeId = ref.watch(libraryActiveCategoryProvider);
    final categories = ref.read(categoryDaoProvider).list();
    // Si la activa dejó de existir, caer a "Todas".
    final resolved = (activeId == null || categories.any((c) => c.id == activeId)) ? activeId : null;
    return LibraryState(
      categories: categories,
      mangas: _mangasFor(resolved),
    );
  }

  List<Manga> _mangasFor(int? categoryId) {
    final mangaDao = ref.read(mangaDaoProvider);
    return categoryId == null ? mangaDao.favorites() : mangaDao.byCategory(categoryId);
  }

  void selectCategory(int? id) =>
      ref.read(libraryActiveCategoryProvider.notifier).state = id;

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

  void _bump() => ref.read(libraryVersionProvider.notifier).state++;
}

final libraryProvider = NotifierProvider<LibraryController, LibraryState>(LibraryController.new);
