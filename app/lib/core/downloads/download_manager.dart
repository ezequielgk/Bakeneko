import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../daemon/daemon_client.dart';
import '../db/dao/download_dao.dart';
import '../db/dao/manga_dao.dart';
import '../models.dart';

/// Puerto minimalista sobre lo que [DownloadManager] necesita del daemon.
/// Lo extraemos como interfaz para poder testear con un stub sin red.
abstract class MangaSourceBackend {
  Future<List<Map<String, dynamic>>> chapterPages(String source, Map<String, dynamic> chapter);
  Future<String> pageUrl(String source, Map<String, dynamic> page);
  Future<Map<String, String>> sourceHeaders(String source);
}

/// Adaptador: [DaemonClient] satisface [MangaSourceBackend].
/// (No usamos `implements` en DaemonClient para no acoplarlo; este wrapper sí.)
class DaemonBackend implements MangaSourceBackend {
  DaemonBackend(this._daemon);
  final DaemonClient _daemon;
  @override
  Future<List<Map<String, dynamic>>> chapterPages(String source, Map<String, dynamic> chapter) =>
      _daemon.chapterPages(source, chapter);
  @override
  Future<String> pageUrl(String source, Map<String, dynamic> page) =>
      _daemon.pageUrl(source, page);
  @override
  Future<Map<String, String>> sourceHeaders(String source) =>
      _daemon.sourceHeaders(source);
}

/// Clave de una descarga (manga + chapterUrl) para indexar progreso.
typedef DownloadKey = ({int mangaId, String chapterUrl});

DownloadKey dlKey(int mangaId, String chapterUrl) => (mangaId: mangaId, chapterUrl: chapterUrl);

/// Cola de descargas persistida + worker pool de [concurrency] workers.
///
/// - Cada capítulo: pide páginas al backend, resuelve URLs, baja imágenes con
///   `dart:io HttpClient` (stdlib, sin deps), escribe `NNNN.jpg.part` y renombra
///   atómicamente al terminar la página.
/// - Layout: `<downloadsRoot>/<source>/<mangaHash>/<chapterHash>/0001.jpg`
///   donde `hash = url.hashCode.toRadixString(16)` (mismo formato que el original).
/// - Marca `completed.txt` al acabar todas las páginas → state=done.
/// - No re-descarga páginas ya presentes (idempotente ante reintentos).
class DownloadManager {
  DownloadManager({
    required MangaSourceBackend backend,
    required MangaDao mangaDao,
    required DownloadDao downloadDao,
    required Directory downloadsRoot,
    int concurrency = 3,
    HttpClient? httpClient,
  })  : _backend = backend,
        _mangaDao = mangaDao,
        _downloads = downloadDao,
        _root = downloadsRoot,
        _maxConcurrent = concurrency,
        _http = httpClient ?? HttpClient() {
    // Restaura descargas pendientes de la sesión anterior.
    final pending = _downloads.pending();
    for (final p in pending) {
      _queue.add(dlKey(p.mangaId, p.chapterUrl));
      if (p.state == DownloadState.downloading) {
        _downloads.setState(p.mangaId, p.chapterUrl, DownloadState.queued);
      }
    }
    if (_queue.isNotEmpty) {
      _pump();
    }
  }

  final MangaSourceBackend _backend;
  final MangaDao _mangaDao;
  final DownloadDao _downloads;
  final Directory _root;
  final int _maxConcurrent;
  final HttpClient _http;

  /// Cola en memoria de descargas pendientes (source of truth de estado: DB).
  final _queue = Queue<DownloadKey>();
  int _active = 0;
  bool _pumping = false;

  /// Emite cada cambio de progreso/estado para que la UI se refresque.
  final _progress = StreamController<DownloadEntry>.broadcast();
  Stream<DownloadEntry> get progress => _progress.stream;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
    _pump();
  }

  // — API pública ———————————————————————————————————————————————

  /// Encola un capítulo para descarga. Idempotente: si ya está done o
  // downloading, no re-encola.
  Future<void> enqueue(Manga manga, Chapter chapter) async {
    final mangaId = _mangaDao.upsert(manga);
    final key = dlKey(mangaId, chapter.url);
    final existing = _downloads.get(mangaId, chapter.url);
    if (existing != null && (existing.state == DownloadState.done || existing.state == DownloadState.downloading)) {
      return; // ya hecho o en curso
    }
    _downloads.upsert(mangaId: mangaId, chapterUrl: chapter.url, state: DownloadState.queued);
    _queue.add(key);
    _emit(mangaId, chapter.url);
    _pump();
  }

  /// Páginas descargadas de un capítulo (vacío si no está completo).
  List<File> pagesFor(Manga manga, Chapter chapter) {
    if (!isComplete(manga, chapter)) return const [];
    return _chapterDir(manga.source, manga.url, chapter.url)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jpg'))
        .toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
  }

  bool isComplete(Manga manga, Chapter chapter) =>
      File(p.join(_chapterDir(manga.source, manga.url, chapter.url).path, _completedMark)).existsSync();

  static const _completedMark = 'completed.txt';

  /// Quita de la cola y borra archivos parciales (no los completados).
  Future<void> cancel(int mangaId, String chapterUrl) async {
    _queue.removeWhere((k) => k.mangaId == mangaId && k.chapterUrl == chapterUrl);
    final entry = _downloads.get(mangaId, chapterUrl);
    if (entry != null && entry.state != DownloadState.done) {
      _downloads.setState(mangaId, chapterUrl, DownloadState.idle);
      _emit(mangaId, chapterUrl);
    }
  }

  /// Borra un capítulo descargado del disco + la fila en DB.
  Future<void> delete(int mangaId, String chapterUrl) async {
    await cancel(mangaId, chapterUrl);
    final manga = _mangaDao.byId(mangaId);
    if (manga != null) {
      final dir = _chapterDir(manga.source, manga.url, chapterUrl);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
    _downloads.remove(mangaId, chapterUrl);
    _emit(mangaId, chapterUrl);
  }

  /// Snapshot actual del progreso de todas las descargas.
  List<DownloadEntry> snapshot() => _downloads.list();

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _progress.close();
    _http.close(force: true);
  }

  // — Internos: worker pool ——————————————————————————————————————

  void _pump() {
    if (_pumping || _isPaused) return;
    _pumping = true;
    scheduleMicrotask(_drainQueue);
  }

  Future<void> _drainQueue() async {
    _pumping = false;
    while (_queue.isNotEmpty && _active < _maxConcurrent) {
      final key = _queue.removeFirst();
      _active++;
      // Dispara sin await para que corran en paralelo hasta _maxConcurrent.
      _process(key).whenComplete(() {
        _active--;
        if (_queue.isNotEmpty) _pump();
      });
    }
  }

  Future<void> _process(DownloadKey key) async {
    final mangaId = key.mangaId;
    final chapterUrl = key.chapterUrl;
    final manga = _mangaDao.byId(mangaId);
    if (manga == null) {
      _downloads.setState(mangaId, chapterUrl, DownloadState.error);
      _emit(mangaId, chapterUrl);
      return;
    }
    // Reconstruye el blob del chapter desde el manga (el daemon lo pide).
    final chapter = manga.chapters.where((c) => c.url == chapterUrl).firstOrNull;
    if (chapter == null || chapter.blob == null) {
      _downloads.setState(mangaId, chapterUrl, DownloadState.error);
      _emit(mangaId, chapterUrl);
      return;
    }

    _downloads.setState(mangaId, chapterUrl, DownloadState.downloading);
    _emit(mangaId, chapterUrl);

    try {
      final dir = _chapterDir(manga.source, manga.url, chapterUrl);
      dir.createSync(recursive: true);

      final pages = await _backend.chapterPages(manga.source, chapter.blob!);
      _downloads.setProgress(mangaId, chapterUrl, 0, pages.length);

      final headers = await _backend.sourceHeaders(manga.source);

      var done = 0;
      for (var i = 0; i < pages.length; i++) {
        final name = _pageName(i + 1);
        final file = File(p.join(dir.path, name));
        if (!file.existsSync()) {
          // Resuelve la URL final y baja con .part + rename atómico.
          final url = await _backend.pageUrl(manga.source, pages[i]);
          await _downloadTo(url, file, headers);
        }
        done++;
        _downloads.setProgress(mangaId, chapterUrl, done, pages.length);
        _emit(mangaId, chapterUrl);
      }

      // Marca de capítulo completo.
      File(p.join(dir.path, _completedMark)).writeAsStringSync(DateTime.now().toIso8601String());
      _downloads.setState(mangaId, chapterUrl, DownloadState.done);
      _emit(mangaId, chapterUrl);
    } catch (e) {
      _downloads.setState(mangaId, chapterUrl, DownloadState.error);
      _emit(mangaId, chapterUrl);
    }
  }

  Future<void> _downloadTo(String url, File target, Map<String, String> headers) async {
    final part = File('${target.path}.part');
    final req = await _http.getUrl(Uri.parse(url));
    headers.forEach((k, v) => req.headers.set(k, v));
    final resp = await req.close();
    if (resp.statusCode != 200) {
      throw IOException('HTTP ${resp.statusCode} bajando $url');
    }
    final sink = part.openWrite();
    await sink.addStream(resp);
    await sink.flush();
    await sink.close();
    // Rename atómico (mismo filesystem).
    await part.rename(target.path);
  }

  Directory _chapterDir(String source, String mangaUrl, String chapterUrl) => Directory(p.join(
        _root.path,
        source,
        mangaUrl.hashCode.toRadixString(16),
        chapterUrl.hashCode.toRadixString(16),
      ));

  /// `0001.jpg`, `0002.jpg`, ... (4 dígitos, igual que el original).
  String _pageName(int n) => '${n.toString().padLeft(4, '0')}.jpg';

  void _emit(int mangaId, String chapterUrl) {
    final e = _downloads.get(mangaId, chapterUrl);
    if (e != null) _progress.add(e);
  }
}

/// Helper expuesto para rutas de descarga (tests / stats de almacenamiento).
Directory downloadedChapterDir(Directory root, String source, String mangaUrl, String chapterUrl) =>
    Directory(p.join(root.path, source, mangaUrl.hashCode.toRadixString(16), chapterUrl.hashCode.toRadixString(16)));

class IOException implements Exception {
  const IOException(this.message);
  final String message;
  @override
  String toString() => 'IOException: $message';
}
