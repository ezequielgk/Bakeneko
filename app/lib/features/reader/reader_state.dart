import '../../core/models.dart';
import '../../core/settings.dart';

/// Argumento para el provider del lector: manga + capítulo inicial + settings.
class ReaderArg {
  const ReaderArg({required this.manga, required this.chapterIndex, required this.settings});
  final Manga manga;
  final int chapterIndex;
  final Settings settings;
}

/// Estado del lector: capítulos, páginas, modo, filtros.
class ReaderState {
  const ReaderState({
    this.chapters = const [],
    this.currentChapter = 0,
    this.pageUrls = const [],
    this.loadingPages = false,
    this.readMode = ReadMode.webtoon,
    this.colorFilter = ColorFilterPreset.none,
    this.error,
    this.mangaId,
  });

  final List<Chapter> chapters;
  final int currentChapter;
  final List<String> pageUrls;
  final bool loadingPages;
  final ReadMode readMode;
  final ColorFilterPreset colorFilter;
  final String? error;
  final int? mangaId;

  factory ReaderState.initial(ReadMode mode, ColorFilterPreset filter) =>
      ReaderState(readMode: mode, colorFilter: filter);

  ReaderState copyWith({
    List<Chapter>? chapters,
    int? currentChapter,
    List<String>? pageUrls,
    bool? loadingPages,
    ReadMode? readMode,
    ColorFilterPreset? colorFilter,
    String? error,
    int? mangaId,
  }) => ReaderState(
    chapters: chapters ?? this.chapters,
    currentChapter: currentChapter ?? this.currentChapter,
    pageUrls: pageUrls ?? this.pageUrls,
    loadingPages: loadingPages ?? this.loadingPages,
    readMode: readMode ?? this.readMode,
    colorFilter: colorFilter ?? this.colorFilter,
    error: error,
    mangaId: mangaId ?? this.mangaId,
  );

  bool get isLoading => loadingPages && pageUrls.isEmpty && error == null;
}