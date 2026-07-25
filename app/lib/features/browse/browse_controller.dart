import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/daemon/daemon_client.dart';
import '../../core/models.dart';
import '../../core/settings.dart';

class BrowseState {
  const BrowseState({
    this.query = '',
    this.mangasBySource = const {},
    this.loading = false,
    this.error,
  });

  final String query;
  final Map<String, List<Manga>> mangasBySource;
  final bool loading;
  final String? error;

  BrowseState copyWith({
    String? query,
    Map<String, List<Manga>>? mangasBySource,
    bool? loading,
    String? error,
  }) => BrowseState(
    query: query ?? this.query,
    mangasBySource: mangasBySource ?? this.mangasBySource,
    loading: loading ?? this.loading,
    error: error,
  );
}

class BrowseController extends StateNotifier<BrowseState> {
  BrowseController(this._daemon, this._settings, this.lockedSourceId) : super(const BrowseState());

  final DaemonClient _daemon;
  final Settings _settings;
  final String lockedSourceId;

  void setQuery(String q) {
    state = state.copyWith(query: q);
  }

  Future<void> loadFirst() async {
    state = state.copyWith(loading: true, error: null, mangasBySource: const {});
    try {
      final effectiveNsfw = _settings.browseNsfwOverride ?? _settings.showNsfwContent;
      
      // Determine sources to query
      List<String> targets = [];
      if (lockedSourceId.isNotEmpty) {
        targets = [lockedSourceId];
      } else {
        targets = _settings.browseSelectedSources.isNotEmpty 
            ? _settings.browseSelectedSources 
            : _settings.enabledSources;
      }

      // We should also filter out sources based on language or NSFW in a real scenario,
      // but here we just fetch them all and then filter results, or rely on daemon.
      // Wait, we need to know if the source itself is NSFW or matches the language.
      final allSources = await _daemon.listSources().then((list) => list.map(Source.fromJson).toList());
      
      final activeSources = allSources.where((s) {
        if (!targets.contains(s.id)) return false;
        if (s.isNsfw && !effectiveNsfw) return false;
        if (_settings.browseSelectedLangs.isNotEmpty && !_settings.browseSelectedLangs.contains(s.lang)) return false;
        return true;
      }).toList();

      if (activeSources.isEmpty) {
        state = state.copyWith(loading: false, mangasBySource: {});
        return;
      }

      final Map<String, List<Manga>> newMangas = {};
      await Future.wait(activeSources.map((source) async {
        try {
          final list = await _daemon.catalogList(source: source.id, offset: 0, query: _effectiveQuery);
          final typedList = list.cast<Map<String, dynamic>>();
          final filteredList = effectiveNsfw ? typedList : typedList.where((m) => !Manga.fromJson(m).isNsfw).toList();
          if (filteredList.isNotEmpty) {
            newMangas[source.name] = filteredList.map(Manga.fromJson).toList();
          }
        } catch (e) {
          // Ignore individual source errors during multi-search
          print("Error fetching ${source.id}: $e");
        }
      }));

      state = state.copyWith(mangasBySource: newMangas, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  String? get _effectiveQuery => state.query.isEmpty ? null : state.query;
}

final browseProvider = StateNotifierProvider.autoDispose.family<BrowseController, BrowseState, String>((ref, lockedSourceId) {
  return BrowseController(ref.watch(daemonClientProvider), ref.watch(settingsProvider), lockedSourceId);
});