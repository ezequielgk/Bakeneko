import 'dart:convert';

/// Modelos inmutables de la app. Reflejan los DTOs del daemon pero en
/// Dart nativo. El [blob] guarda el JSON opaco que el daemon necesita
/// para reconstruir el modelo del parser al hacer round-trip.
class Manga {
  const Manga({
    required this.source,
    required this.url,
    required this.title,
    this.publicUrl,
    this.rating = 0,
    this.isNsfw = false,
    this.coverUrl,
    this.largeCoverUrl,
    this.description,
    this.authors = const [],
    this.state,
    this.chapters = const [],
    this.blob,
  });

  final String source;
  final String url;
  final String title;
  final String? publicUrl;
  final double rating;
  final bool isNsfw;
  final String? coverUrl;
  final String? largeCoverUrl;
  final String? description;
  final List<String> authors;
  final String? state;
  final List<Chapter> chapters;
  final Map<String, dynamic>? blob;

  factory Manga.fromJson(Map<String, dynamic> j) => Manga(
        source: j['source'] as String,
        url: j['url'] as String,
        title: j['title'] as String? ?? '',
        publicUrl: j['publicUrl'] as String?,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        isNsfw: j['isNsfw'] as bool? ?? false,
        coverUrl: j['coverUrl'] as String?,
        largeCoverUrl: j['largeCoverUrl'] as String?,
        description: j['description'] as String?,
        authors: (j['authors'] as List?)?.cast<String>() ?? const [],
        state: j['state'] as String?,
        chapters: (j['chapters'] as List?)?.map((c) => Chapter.fromJson(c as Map<String, dynamic>)).toList() ?? const [],
        blob: j,
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'url': url,
        'title': title,
        if (publicUrl != null) 'publicUrl': publicUrl,
        'rating': rating,
        'isNsfw': isNsfw,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (largeCoverUrl != null) 'largeCoverUrl': largeCoverUrl,
        if (description != null) 'description': description,
        'authors': authors,
        if (state != null) 'state': state,
        'chapters': chapters.map((c) => c.toJson()).toList(),
      };

  /// Identificador compuesto (lo mismo que usa el UNIQUE de la DB).
  String get key => '$source|$url';

  Manga copyWith({List<Chapter>? chapters}) => Manga(
        source: source,
        url: url,
        title: title,
        publicUrl: publicUrl,
        rating: rating,
        isNsfw: isNsfw,
        coverUrl: coverUrl,
        largeCoverUrl: largeCoverUrl,
        description: description,
        authors: authors,
        state: state,
        chapters: chapters ?? this.chapters,
        blob: blob,
      );
}

class Chapter {
  const Chapter({
    required this.source,
    required this.url,
    required this.title,
    this.number = 0,
    this.volume = 0,
    this.scanlator,
    this.uploadDate,
    this.branch,
    this.read = false,
    this.blob,
  });

  final String source;
  final String url;
  final String title;
  final double number;
  final int volume;
  final String? scanlator;
  final int? uploadDate;
  final String? branch;
  final bool read;
  final Map<String, dynamic>? blob;

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        source: j['source'] as String,
        url: j['url'] as String,
        title: j['title'] as String? ?? '',
        number: (j['number'] as num?)?.toDouble() ?? 0,
        volume: j['volume'] as int? ?? 0,
        scanlator: j['scanlator'] as String?,
        uploadDate: j['uploadDate'] as int?,
        branch: j['branch'] as String?,
        blob: j,
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'url': url,
        'title': title,
        'number': number,
        'volume': volume,
        if (scanlator != null) 'scanlator': scanlator,
        if (uploadDate != null) 'uploadDate': uploadDate,
        if (branch != null) 'branch': branch,
      };
}

class Page {
  const Page({required this.source, required this.url, this.preview});
  final String source;
  final String url;
  final String? preview;

  factory Page.fromJson(Map<String, dynamic> j) => Page(
        source: j['source'] as String,
        url: j['url'] as String,
        preview: j['preview'] as String?,
      );
  Map<String, dynamic> toJson() => {
        'source': source,
        'url': url,
        if (preview != null) 'preview': preview,
      };
}

class Source {
  const Source({required this.id, required this.name});
  final String id;
  final String name;
  factory Source.fromJson(Map<String, dynamic> j) =>
      Source(id: j['id'] as String, name: j['name'] as String);
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// Estado de la cola de descargas, persistido en tabla `download`.
enum DownloadState { idle, queued, downloading, done, error }

class DownloadEntry {
  const DownloadEntry({
    required this.mangaId,
    required this.chapterUrl,
    required this.state,
    this.totalPages = 0,
    this.donePages = 0,
  });
  final int mangaId;
  final String chapterUrl;
  final DownloadState state;
  final int totalPages;
  final int donePages;

  factory DownloadEntry.fromRow(Map<String, dynamic> r) => DownloadEntry(
        mangaId: r['manga_id'] as int,
        chapterUrl: r['chapter_url'] as String,
        state: DownloadState.values.byName(r['state'] as String),
        totalPages: r['total_pages'] as int,
        donePages: r['done_pages'] as int,
      );
}

class Category {
  const Category({
    this.id,
    required this.name,
    required this.color,
    this.autoDownload = false,
    this.createdAt = 0,
  });
  final int? id;
  final String name;
  final String color;
  final bool autoDownload;
  final int createdAt;

  factory Category.fromRow(Map<String, dynamic> r) => Category(
        id: r['id'] as int?,
        name: r['name'] as String,
        color: r['color'] as String,
        autoDownload: (r['auto_download'] as int) == 1,
        createdAt: r['created_at'] as int? ?? 0,
      );
}

class HistoryEntry {
  const HistoryEntry({
    required this.manga,
    required this.chapterIndex,
    this.pageIndex = 0,
    this.updatedAt = 0,
  });
  final Manga manga;
  final int chapterIndex;
  final int pageIndex;
  final int updatedAt;
}

/// Codifica/decodifica un blob a texto JSON para persistir en DB.
String encodeBlob(Map<String, dynamic>? blob) =>
    blob == null ? '{}' : jsonEncode(blob);