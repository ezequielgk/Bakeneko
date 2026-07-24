import 'dart:io';

import 'package:path/path.dart' as p;

/// Rutas según la especificación XDG Base Directory.
/// Una sola función por path, cacheadas perezosamente para no releer env.
class Xdg {
  const Xdg._();

  /// $XDG_DATA_HOME o ~/.local/share
  static Directory get dataHome {
    final env = Platform.environment['XDG_DATA_HOME'];
    final dir = env != null && env.isNotEmpty
        ? env
        : p.join(home, '.local', 'share');
    return Directory(dir);
  }

  /// $XDG_CONFIG_HOME o ~/.config
  static Directory get configHome {
    final env = Platform.environment['XDG_CONFIG_HOME'];
    final dir = env != null && env.isNotEmpty ? env : p.join(home, '.config');
    return Directory(dir);
  }

  /// $XDG_CACHE_HOME o ~/.cache
  static Directory get cacheHome {
    final env = Platform.environment['XDG_CACHE_HOME'];
    final dir = env != null && env.isNotEmpty ? env : p.join(home, '.cache');
    return Directory(dir);
  }

  /// $XDG_RUNTIME_DIR o /tmp/bakeneko-$uid (debe existir y ser 0700, pero
  /// no lo garantizamos aquí; el daemon lo crea igual).
  static Directory get runtimeDir {
    final env = Platform.environment['XDG_RUNTIME_DIR'];
    final dir = env != null && env.isNotEmpty ? env : '/tmp/bakeneko-$uid';
    return Directory(dir);
  }

  /// Directorio raíz de la app bajo datos: catálogo local + descargas.
  static Directory get dataRoot => Directory(p.join(dataHome.path, 'bakeneko'));

  /// Configuración: settings.json.
  static Directory get configRoot => Directory(p.join(configHome.path, 'bakeneko'));

  /// Caché de imágenes (covers/páginas).
  static Directory get cacheRoot => Directory(p.join(cacheHome.path, 'bakeneko'));

  /// Socket del daemon en runtime.
  static File get daemonSocket => File(p.join(runtimeDir.path, 'bakeneko', 'daemon.sock'));

  /// Descargas de capítulos: `dataRoot/downloads/<fuente>/<mangaHash>/<capHash>`
  static Directory get downloadsRoot => Directory(p.join(dataRoot.path, 'downloads'));

  static String get home => Platform.environment['HOME'] ?? '/tmp';

  static int get uid => _uid ??= _readUid() ?? 1000;
  static int? _uid;

  static int? _readUid() {
    // En Linux, /proc/self/status es la forma portable de leer el uid.
    try {
      final f = File('/proc/self/status');
      if (!f.existsSync()) return null;
      for (final line in f.readAsLinesSync()) {
        if (line.startsWith('Uid:')) {
          return int.tryParse(line.split(RegExp(r'\s+'))[1]);
        }
      }
    } catch (_) {
      // ignoramos: hay fallbacks
    }
    return null;
  }

  /// Asegura que todos los directorios base existen (idempotente).
  static void ensureDirs() {
    for (final d in [dataRoot, configRoot, cacheRoot, downloadsRoot]) {
      if (!d.existsSync()) d.createSync(recursive: true);
    }
    // El dir del socket lo crea el daemon; aquí sólo lo creamos por si acaso.
    final sockDir = Directory(p.join(runtimeDir.path, 'bakeneko'));
    if (!sockDir.existsSync()) sockDir.createSync(recursive: true);
    try {
      sockDir.statSync(); // aseguramos
    } catch (_) {}
  }
}