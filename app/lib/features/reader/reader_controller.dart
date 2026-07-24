import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/db/dao/history_dao.dart';
import '../../core/models.dart';
import '../../core/settings.dart';
import 'reader_state.dart';

/// Carga y gestiona el estado del lector de un manga.
class ReaderController extends FamilyNotifier<ReaderState, ReaderArg> {
  @override
  ReaderState build(ReaderArg arg) {
    _load(arg);
    return ReaderState.initial(arg.settings.defaultReadMode, arg.settings.readerColorFilter);
  }

  Future<void> _load(ReaderArg arg) async {
    state = ReaderState.initial(arg.settings.defaultReadMode, arg.settings.readerColorFilter)
        .copyWith(loadingPages: true);
    try {
      final daemon = ref.read(daemonClientProvider);
      final manga = arg.manga;

      // Carga los capítulos del manga (si ya tiene chapters del details, usarlos).
      var chapters = manga.chapters;
      if (chapters.isEmpty) {
        final raw = await daemon.mangaDetails(manga.source,
            {'source': manga.source, 'url': manga.url, 'title': manga.title});
        chapters = Manga.fromJson(raw).chapters;
      }
      if (chapters.isEmpty || arg.chapterIndex >= chapters.length) {
        state = const ReaderState(error: 'No se encontraron capítulos.');
        return;
      }

      state = state.copyWith(chapters: chapters, currentChapter: arg.chapterIndex, loadingPages: true);

      await _loadPages(arg, chapters[arg.chapterIndex]);
    } catch (e) {
      state = ReaderState(error: e.toString());
    }
  }

  Future<void> _loadPages(ReaderArg arg, Chapter chapter) async {
    try {
      final manager = ref.read(downloadManagerProvider);
      final urls = <String>[];

      if (manager.isComplete(arg.manga, chapter)) {
        final files = manager.pagesFor(arg.manga, chapter);
        urls.addAll(files.map((f) => 'file://${f.path}'));
      } else {
        final daemon = ref.read(daemonClientProvider);
        final rawPages = await daemon.chapterPages(chapter.source,
            {'source': chapter.source, 'url': chapter.url, 'title': chapter.title});
        final pages = rawPages.map(Page.fromJson).toList();

        for (final p in pages) {
          urls.add(await daemon.pageUrl(p.source, p.toJson()));
        }
      }

      // Persiste historial.
      final mangaDao = ref.read(mangaDaoProvider);
      final historyDao = ref.read(historyDaoProvider);
      final id = mangaDao.upsert(arg.manga);
      historyDao.upsert(id, chapterIndex: state.currentChapter);
      // Refresca Home (historial cambió).
      ref.read(libraryVersionProvider.notifier).state++;

      state = state.copyWith(pageUrls: urls, loadingPages: false, mangaId: id);
    } catch (e) {
      state = state.copyWith(loadingPages: false, error: e.toString());
    }
  }

  void setReadMode(ReadMode mode) => state = state.copyWith(readMode: mode);

  void setColorFilter(ColorFilterPreset filter) => state = state.copyWith(colorFilter: filter);

  Future<void> nextChapter(ReaderArg arg) async {
    if (state.currentChapter < state.chapters.length - 1) {
      final idx = state.currentChapter + 1;
      state = state.copyWith(currentChapter: idx, pageUrls: const [], loadingPages: true);
      await _loadPages(arg, state.chapters[idx]);
    }
  }

  Future<void> prevChapter(ReaderArg arg) async {
    if (state.currentChapter > 0) {
      final idx = state.currentChapter - 1;
      state = state.copyWith(currentChapter: idx, pageUrls: const [], loadingPages: true);
      await _loadPages(arg, state.chapters[idx]);
    }
  }

  void retry(ReaderArg arg) => _load(arg);
}

final readerProvider =
    NotifierProvider.family<ReaderController, ReaderState, ReaderArg>(ReaderController.new);