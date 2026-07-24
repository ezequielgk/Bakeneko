import 'dart:convert';

import 'package:bakeneko/core/db/database.dart';
import 'package:bakeneko/core/models.dart';

class ChapterDao {
  ChapterDao(this.db);
  final AppDatabase db;

  /// Reemplaza los capítulos almacenados de un manga con la lista dada.
  /// (Los detalles se vuelven a pedir al daemon; no mergeamos.)
  void replaceChapters(int mangaId, List<Chapter> chapters) {
    db.db.execute('DELETE FROM chapter WHERE manga_id=?', [mangaId]);
    for (final c in chapters) {
      db.db.execute(
        'INSERT INTO chapter(manga_id, url, name, number, blob_json, read) '
        'VALUES (?, ?, ?, ?, ?, 0)',
        [mangaId, c.url, c.title, c.number, jsonEncode(c.blob ?? c.toJson())],
      );
    }
  }

  List<Chapter> forManga(int mangaId) {
    final rs = db.db.select(
      'SELECT blob_json FROM chapter WHERE manga_id=? ORDER BY number DESC',
      [mangaId],
    );
    return rs
        .map((r) => Chapter.fromJson(jsonDecode(r.columnAt(0) as String) as Map<String, dynamic>))
        .toList();
  }

  void setRead(int mangaId, String url, bool read) {
    db.db.execute(
      'UPDATE chapter SET read=? WHERE manga_id=? AND url=?',
      [read ? 1 : 0, mangaId, url],
    );
  }

  int unreadCount(int mangaId, String chapterUrl) {
    return db.db
        .select(
          'SELECT COUNT(*) FROM chapter WHERE manga_id=? AND url=? AND read=0',
          [mangaId, chapterUrl],
        )
        .first
        .columnAt(0) as int;
  }
}