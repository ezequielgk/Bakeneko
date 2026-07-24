import 'package:sqlite3/sqlite3.dart';

import 'schema.dart';

/// Envoltorio delgado sobre la conexión sqlite3 nativa.
/// Una sola responsabilidad: abrir, migrar (PRAGMA user_version) y exponer
/// la conexión a los DAOs. Los DAOs hacen todo el SQL.
class AppDatabase {
  AppDatabase._(this.db, {required this.inMemory});
  final Database db;
  final bool inMemory;

  static const int _schemaVersion = 1;

  /// Abre (o crea) la base de datos en [path]. Ejecuta el esquema inicial
  /// si la base está vacía; en el futuro las migraciones viven aquí.
  factory AppDatabase.open(String path) {
    final db = sqlite3.open(path);
    db.execute('PRAGMA foreign_keys = ON;');
    _migrate(db, fileBacked: true);
    db.execute('PRAGMA foreign_keys = ON;');
    return AppDatabase._(db, inMemory: false);
  }

  /// DB en memoria (útil para tests).
  factory AppDatabase.memory() {
    final db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON;');
    _migrate(db, fileBacked: false);
    return AppDatabase._(db, inMemory: true);
  }

  static void _migrate(Database db, {required bool fileBacked}) {
    final version = db.select('PRAGMA user_version').first.values.first as int;
    if (version >= _schemaVersion) return;
    // v0 -> v1: esquema inicial. Quitamos comentarios de línea y dividimos
    // en statements por ';'. (No hay strings con ';' en el esquema.)
    final cleaned = schemaSql
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('--'))
        .join('\n');
    for (final stmt in cleaned.split(';')) {
      final s = stmt.trim();
      if (s.isEmpty) continue;
      db.execute(s);
    }
    db.execute('PRAGMA user_version = $_schemaVersion;');
  }

  void close() => db.dispose();

  /// Convierte un [Row] en un mapa nombre-columna -> valor, para los DAOs.
  static Map<String, dynamic> rowToMap(Row r) => {
        for (final k in r.keys) k: r[k],
      };
}