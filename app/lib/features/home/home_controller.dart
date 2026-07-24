import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/models.dart';

/// Estado inmutable de la pantalla Home.
class HomeState {
  const HomeState({this.continueReading = const [], this.recentlyAdded = const []});
  final List<HistoryEntry> continueReading;
  final List<Manga> recentlyAdded;
}

class HomeController extends Notifier<HomeState> {
  @override
  HomeState build() {
    // Refresca al cambiar favoritos/historial.
    ref.watch(libraryVersionProvider);
    return HomeState(
      continueReading: ref.read(historyDaoProvider).list(),
      recentlyAdded: ref.read(mangaDaoProvider).favorites(),
    );
  }
}

final homeProvider = NotifierProvider<HomeController, HomeState>(HomeController.new);
