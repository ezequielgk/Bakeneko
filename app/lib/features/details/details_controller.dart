import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/db/dao/manga_dao.dart';
import '../../core/models.dart';

/// Estado de la pantalla de Detalles para un manga concreto.
class DetailsState {
  const DetailsState({this.manga, this.loading = true, this.isFavorite = false, this.error});
  final Manga? manga;
  final bool loading;
  final bool isFavorite;
  final String? error;

  DetailsState copyWith({Manga? manga, bool? loading, bool? isFavorite, String? error}) =>
      DetailsState(manga: manga ?? this.manga, loading: loading ?? this.loading, isFavorite: isFavorite ?? this.isFavorite, error: error);
}

class DetailsController extends FamilyNotifier<DetailsState, MangaRef> {
  @override
  DetailsState build(MangaRef mangaRef) {
    _load(mangaRef);
    return const DetailsState();
  }

  Future<void> _load(MangaRef mangaRef) async {
    state = const DetailsState(loading: true);
    try {
      final daemon = ref.read(daemonClientProvider);
      final mangaDao = ref.read(mangaDaoProvider);

      final raw = await daemon.mangaDetails(mangaRef.source,
          {'source': mangaRef.source, 'url': mangaRef.url, 'title': mangaRef.title});
      final manga = Manga.fromJson(raw);

      final id = mangaDao.upsert(manga);
      final fav = mangaDao.isFavorite(id);

      state = DetailsState(manga: manga, loading: false, isFavorite: fav);
    } catch (e) {
      state = DetailsState(loading: false, error: e.toString());
    }
  }

  Future<void> toggleFavorite() async {
    final manga = state.manga;
    if (manga == null) return;
    final mangaDao = ref.read(mangaDaoProvider);
    final id = mangaDao.upsert(manga);
    final newFav = !state.isFavorite;
    mangaDao.setFavorite(id, newFav);
    state = state.copyWith(isFavorite: newFav);
  }

  void retry(MangaRef mangaRef) => _load(mangaRef);
}

final detailsProvider =
    NotifierProvider.family<DetailsController, DetailsState, MangaRef>(DetailsController.new);