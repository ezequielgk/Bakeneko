import 'dart:convert';

import 'package:bakeneko/core/db/database.dart';
import 'package:bakeneko/core/models.dart';

/// CRUD de la tabla `manga` + favoritos (relación simple; categories van
/// aparte). Una acción por método, SQL explícito.
class MangaDao {
  MangaDao(this.db);
  final AppDatabase db;

  /// Upsert del manga. Devuelve su id autocalculado (consultando tras INSERT).
  int upsert(Manga manga, {int now = 0}) {
    final at = now == 0 ? DateTime.now().millisecondsSinceEpoch : now;
    db.db.execute(
      'INSERT INTO manga(source, url, title, cover_url, description, blob_json, added_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(source, url) DO UPDATE SET '
      'title=excluded.title, cover_url=excluded.cover_url, '
      'description=excluded.description, blob_json=excluded.blob_json',
      [
        manga.source,
        manga.url,
        manga.title,
        manga.coverUrl,
        manga.description,
        jsonEncode(manga.blob ?? manga.toJson()),
        at,
      ],
    );
    return _byUrl(manga.source, manga.url)?.id ?? -1;
  }


  _MangaRow? _byUrl(String source, String url) {
    final rs = db.db.select(
      'SELECT id, source, url, title, cover_url, description, blob_json FROM manga WHERE source=? AND url=?',
      [source, url],
    );
    if (rs.rows.isEmpty) return null;
    final r = AppDatabase.rowToMap(rs[0]);
    return _MangaRow(
      id: r['id'] as int,
      source: r['source'] as String,
      url: r['url'] as String,
      title: r['title'] as String,
      coverUrl: r['cover_url'] as String?,
      description: r['description'] as String?,
      blobJson: r['blob_json'] as String,
    );
  }

  /// Obtiene el ID numérico local del manga.
  int? getId(String source, String url) {
    final rs = db.db.select('SELECT id FROM manga WHERE source=? AND url=?', [source, url]);
    return rs.rows.isEmpty ? null : rs.first.columnAt(0) as int;
  }


  Manga? byId(int id) {
    final rs = db.db.select(
      'SELECT blob_json FROM manga WHERE id=?',
      [id],
    );
    if (rs.rows.isEmpty) return null;
    return Manga.fromJson(jsonDecode(rs.first.columnAt(0) as String) as Map<String, dynamic>);
  }

  /// Manga reconstruido desde su blob persistido (incluye chapters del blob
  /// si vinieron en el momento del upsert; normalmente vacío).
  Manga? mangaByUrl(String source, String url) {
    final row = _byUrl(source, url);
    if (row == null) return null;
    final blob = jsonDecode(row.blobJson) as Map<String, dynamic>;
    return Manga.fromJson(blob);
  }

  List<Manga> all() => db.db
      .select('SELECT blob_json FROM manga ORDER BY added_at DESC')
      .map((r) => Manga.fromJson(jsonDecode(r.columnAt(0) as String) as Map<String, dynamic>))
      .toList();

  // — Biblioteca / favorito: flag `library` en la propia tabla manga. —

  bool isFavorite(int mangaId) {
    final n = db.db
        .select('SELECT library FROM manga WHERE id=?', [mangaId])
        .first
        .columnAt(0) as int;
    return n == 1;
  }

  void setFavorite(int mangaId, bool fav) {
    db.db.execute('UPDATE manga SET library=? WHERE id=?', [fav ? 1 : 0, mangaId]);
  }

  List<Manga> favorites() => db.db
      .select('SELECT blob_json FROM manga WHERE library=1 ORDER BY added_at DESC')
      .map((r) => Manga.fromJson(jsonDecode(r.columnAt(0) as String) as Map<String, dynamic>))
      .toList();

  /// Mangas asignados a una categoría, ordenados por `added_at DESC`.
  List<Manga> byCategory(int categoryId) => db.db
      .select(
        'SELECT m.blob_json FROM manga m '
        'JOIN manga_category mc ON mc.manga_id=m.id '
        'WHERE mc.category_id=? ORDER BY m.added_at DESC',
        [categoryId],
      )
      .map((r) => Manga.fromJson(jsonDecode(r.columnAt(0) as String) as Map<String, dynamic>))
      .toList();
}

class _MangaRow {
  const _MangaRow({
    required this.id,
    required this.source,
    required this.url,
    required this.title,
    required this.coverUrl,
    required this.description,
    required this.blobJson,
  });
  final int id;
  final String source;
  final String url;
  final String title;
  final String? coverUrl;
  final String? description;
  final String blobJson;
}