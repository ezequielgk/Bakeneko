import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/daemon/daemon_client.dart';
import '../../core/models.dart';

/// Estado de la pantalla Explorar.
class BrowseState {
  const BrowseState({
    this.sourceId = 'MANGADEX',
    this.query = '',
    this.mangas = const [],
    this.offset = 0,
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final String sourceId;
  final String query;
  final List<Manga> mangas;
  final int offset;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  BrowseState copyWith({
    String? sourceId,
    String? query,
    List<Manga>? mangas,
    int? offset,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
  }) => BrowseState(
    sourceId: sourceId ?? this.sourceId,
    query: query ?? this.query,
    mangas: mangas ?? this.mangas,
    offset: offset ?? this.offset,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: error,
  );
}

class BrowseController extends StateNotifier<BrowseState> {
  BrowseController(this._daemon) : super(const BrowseState());

  final DaemonClient _daemon;

  void setSource(String sourceId) {
    state = BrowseState(sourceId: sourceId);
    loadFirst();
  }

  void setQuery(String q) {
    state = state.copyWith(query: q);
  }

  Future<void> loadFirst() async {
    state = state.copyWith(loading: true, error: null, mangas: const [], offset: 0, hasMore: true);
    try {
      final list = await _daemon.catalogList(source: state.sourceId, offset: 0, query: _effectiveQuery);
      state = state.copyWith(
        mangas: list.map(Manga.fromJson).toList(),
        offset: list.length,
        loading: false,
        hasMore: list.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.loading) return;
    state = state.copyWith(loadingMore: true);
    try {
      final list = await _daemon.catalogList(source: state.sourceId, offset: state.offset, query: _effectiveQuery);
      state = state.copyWith(
        mangas: [...state.mangas, ...list.map(Manga.fromJson)],
        offset: state.offset + list.length,
        loadingMore: false,
        hasMore: list.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, hasMore: false, error: e.toString());
    }
  }

  String? get _effectiveQuery => state.query.isEmpty ? null : state.query;
}

final browseProvider = StateNotifierProvider<BrowseController, BrowseState>((ref) {
  return BrowseController(ref.watch(daemonClientProvider));
});