import '../../core/models.dart';
import '../../core/settings.dart';

/// Argumento para el provider del lector: manga + capítulo inicial + settings.
class ReaderArg {
  const ReaderArg({required this.manga, required this.chapterIndex, required this.settings});
  final Manga manga;
  final int chapterIndex;
  final Settings settings;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderArg &&
          runtimeType == other.runtimeType &&
          manga.key == other.manga.key &&
          chapterIndex == other.chapterIndex;

  @override
  int get hashCode => manga.key.hashCode ^ chapterIndex.hashCode;
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
    this.showUI = true,
    this.error,
    this.mangaId,
  });

  final List<Chapter> chapters;
  final int currentChapter;
  final List<String> pageUrls;
  final bool loadingPages;
  final ReadMode readMode;
  final ColorFilterPreset colorFilter;
  final bool showUI;
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
    bool? showUI,
    String? error,
    int? mangaId,
  }) => ReaderState(
    chapters: chapters ?? this.chapters,
    currentChapter: currentChapter ?? this.currentChapter,
    pageUrls: pageUrls ?? this.pageUrls,
    loadingPages: loadingPages ?? this.loadingPages,
    readMode: readMode ?? this.readMode,
    colorFilter: colorFilter ?? this.colorFilter,
    showUI: showUI ?? this.showUI,
    error: error,
    mangaId: mangaId ?? this.mangaId,
  );

  bool get isLoading => loadingPages && pageUrls.isEmpty && error == null;
}