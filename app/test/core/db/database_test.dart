import 'package:bakeneko/core/db/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppDatabase.memory crea el esquema con user_version=1', () {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final v = db.db.select('PRAGMA user_version').first.columnAt(0) as int;
    expect(v, 1);

    // Tablas presentes
    final tables = db.db
        .select("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        .map((r) => r.columnAt(0) as String)
        .toList();
    expect(tables, containsAll(['manga', 'chapter', 'category', 'manga_category', 'history', 'download']));
  });
}