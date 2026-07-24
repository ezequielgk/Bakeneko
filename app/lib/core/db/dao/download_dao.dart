import 'package:bakeneko/core/db/database.dart';
import 'package:bakeneko/core/models.dart';

class DownloadDao {
  DownloadDao(this.db);
  final AppDatabase db;

  void upsert({
    required int mangaId,
    required String chapterUrl,
    required DownloadState state,
    int totalPages = 0,
    int donePages = 0,
  }) {
    db.db.execute(
      'INSERT INTO download(manga_id, chapter_url, state, total_pages, done_pages) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(manga_id, chapter_url) DO UPDATE SET '
      'state=excluded.state, total_pages=excluded.total_pages, '
      'done_pages=excluded.done_pages',
      [mangaId, chapterUrl, state.name, totalPages, donePages],
    );
  }

  void setState(int mangaId, String chapterUrl, DownloadState state) =>
      db.db.execute(
        'UPDATE download SET state=? WHERE manga_id=? AND chapter_url=?',
        [state.name, mangaId, chapterUrl],
      );

  void setProgress(int mangaId, String chapterUrl, int done, int total) =>
      db.db.execute(
        'UPDATE download SET done_pages=?, total_pages=? WHERE manga_id=? AND chapter_url=?',
        [done, total, mangaId, chapterUrl],
      );

  DownloadEntry? get(int mangaId, String chapterUrl) {
    final rs = db.db.select(
      'SELECT manga_id, chapter_url, state, total_pages, done_pages FROM download '
      'WHERE manga_id=? AND chapter_url=?',
      [mangaId, chapterUrl],
    );
    if (rs.isEmpty) return null;
    return DownloadEntry.fromRow(AppDatabase.rowToMap(rs[0]));
  }

  List<DownloadEntry> pending() => db.db
      .select('SELECT manga_id, chapter_url, state, total_pages, done_pages FROM download '
          'WHERE state IN (?, ?) ORDER BY manga_id, chapter_url',
          [DownloadState.queued.name, DownloadState.downloading.name])
      .map((r) => DownloadEntry.fromRow(AppDatabase.rowToMap(r)))
      .toList();

  List<DownloadEntry> forManga(int mangaId) => db.db
      .select(
        'SELECT manga_id, chapter_url, state, total_pages, done_pages FROM download '
        'WHERE manga_id=? ORDER BY chapter_url',
        [mangaId],
      )
      .map((r) => DownloadEntry.fromRow(AppDatabase.rowToMap(r)))
      .toList();

  void remove(int mangaId, String chapterUrl) =>
      db.db.execute('DELETE FROM download WHERE manga_id=? AND chapter_url=?', [mangaId, chapterUrl]);
}