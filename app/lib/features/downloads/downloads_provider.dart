import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models.dart';
import '../../app.dart';

class DownloadsState {
  const DownloadsState({
    required this.entries,
    required this.isPaused,
  });
  final List<DownloadEntry> entries;
  final bool isPaused;

  DownloadsState copyWith({
    List<DownloadEntry>? entries,
    bool? isPaused,
  }) =>
      DownloadsState(
        entries: entries ?? this.entries,
        isPaused: isPaused ?? this.isPaused,
      );
}

class DownloadsNotifier extends StateNotifier<DownloadsState> {
  DownloadsNotifier(this.ref) : super(const DownloadsState(entries: [], isPaused: false)) {
    final manager = ref.read(downloadManagerProvider);
    state = state.copyWith(
      entries: manager.snapshot(),
      isPaused: manager.isPaused,
    );
    _sub = manager.progress.listen((_) {
      state = state.copyWith(entries: manager.snapshot());
    });
  }

  final Ref ref;
  StreamSubscription? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void togglePause() {
    final manager = ref.read(downloadManagerProvider);
    if (manager.isPaused) {
      manager.resume();
    } else {
      manager.pause();
    }
    state = state.copyWith(isPaused: manager.isPaused);
  }

  Future<void> cancel(int mangaId, String chapterUrl) async {
    await ref.read(downloadManagerProvider).cancel(mangaId, chapterUrl);
    // el stream emitirá progreso, no necesitamos actualizar estado manual aquí
  }
}

final downloadsProvider = StateNotifierProvider<DownloadsNotifier, DownloadsState>((ref) {
  return DownloadsNotifier(ref);
});
