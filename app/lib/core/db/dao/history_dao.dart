import 'package:bakeneko/core/db/dao/manga_dao.dart';
import 'package:bakeneko/core/db/database.dart';
import 'package:bakeneko/core/models.dart';

class HistoryDao {
  HistoryDao(this.db, this.mangaDao);
  final AppDatabase db;
  final MangaDao mangaDao;

  void upsert(int mangaId, {required int chapterIndex, int pageIndex = 0, int now = 0}) {
    final at = now == 0 ? DateTime.now().millisecondsSinceEpoch : now;
    db.db.execute(
      'INSERT INTO history(manga_id, chapter_index, page_index, updated_at) '
      'VALUES (?, ?, ?, ?) '
      'ON CONFLICT(manga_id) DO UPDATE SET '
      'chapter_index=excluded.chapter_index, page_index=excluded.page_index, '
      'updated_at=excluded.updated_at',
      [mangaId, chapterIndex, pageIndex, at],
    );
  }

  HistoryEntry? forManga(int mangaId) {
    final rs = db.db.select(
      'SELECT chapter_index, page_index, updated_at FROM history WHERE manga_id=?',
      [mangaId],
    );
    if (rs.isEmpty) return null;
    final manga = mangaDao.byId(mangaId);
    if (manga == null) return null;
    final r = rs.first;
    return HistoryEntry(
      manga: manga,
      chapterIndex: r.columnAt(0) as int,
      pageIndex: r.columnAt(1) as int,
      updatedAt: r.columnAt(2) as int,
    );
  }

  List<HistoryEntry> list({int limit = 50}) {
    final rs = db.db.select(
      'SELECT manga_id, chapter_index, page_index, updated_at FROM history '
      'ORDER BY updated_at DESC LIMIT ?',
      [limit],
    );
    final entries = <HistoryEntry>[];
    for (final r in rs) {
      final manga = mangaDao.byId(r.columnAt(0) as int);
      if (manga == null) continue;
      entries.add(HistoryEntry(
        manga: manga,
        chapterIndex: r.columnAt(1) as int,
        pageIndex: r.columnAt(2) as int,
        updatedAt: r.columnAt(3) as int,
      ));
    }
    return entries;
  }
}