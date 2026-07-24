import 'package:bakeneko/core/db/database.dart';
import 'package:bakeneko/core/models.dart';

class CategoryDao {
  CategoryDao(this.db);
  final AppDatabase db;

  int create(String name, String color, {bool autoDownload = false, int now = 0}) {
    final at = now == 0 ? DateTime.now().millisecondsSinceEpoch : now;
    db.db.execute(
      'INSERT INTO category(name, color, auto_download, created_at) VALUES (?, ?, ?, ?)',
      [name, color, autoDownload ? 1 : 0, at],
    );
    final id = db.db
        .select('SELECT id FROM category WHERE name=? ORDER BY id DESC LIMIT 1', [name])
        .first
        .columnAt(0) as int;
    return id;
  }

  List<Category> list() => db.db
      .select('SELECT id, name, color, auto_download, created_at FROM category '
          'ORDER BY created_at ASC')
      .map((r) => Category.fromRow(AppDatabase.rowToMap(r)))
      .toList();

  void rename(int id, String name) =>
      db.db.execute('UPDATE category SET name=? WHERE id=?', [name, id]);

  void delete(int id) => db.db.execute('DELETE FROM category WHERE id=?', [id]);

  void setAutoDownload(int id, bool auto) =>
      db.db.execute('UPDATE category SET auto_download=? WHERE id=?', [auto ? 1 : 0, id]);

  void assign(int mangaId, int categoryId) => db.db.execute(
        'INSERT OR IGNORE INTO manga_category(manga_id, category_id) VALUES (?, ?)',
        [mangaId, categoryId],
      );

  void unassign(int mangaId, int categoryId) => db.db.execute(
        'DELETE FROM manga_category WHERE manga_id=? AND category_id=?',
        [mangaId, categoryId],
      );

  /// Ids de categoría de un manga.
  List<int> forManga(int mangaId) {
    final rs = db.db
        .select('SELECT category_id FROM manga_category WHERE manga_id=?', [mangaId]);
    return rs.map((r) => r.columnAt(0) as int).toList();
  }

  /// Mangas de una categoría (o de toda la biblioteca si categoryId=null).
  List<int> mangasIn({int? categoryId}) {
    final rs = categoryId == null
        ? db.db.select('SELECT id FROM manga WHERE library=1 ORDER BY added_at DESC')
        : db.db.select(
            'SELECT manga_id FROM manga_category WHERE category_id=? '
            'ORDER BY (SELECT added_at FROM manga WHERE id=manga_id) DESC',
            [categoryId],
          );
    return rs.map((r) => r.columnAt(0) as int).toList();
  }
}