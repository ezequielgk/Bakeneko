import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bakeneko/core/db/dao/download_dao.dart';
import 'package:bakeneko/core/db/dao/manga_dao.dart';
import 'package:bakeneko/core/db/database.dart';
import 'package:bakeneko/core/downloads/download_manager.dart';
import 'package:bakeneko/core/models.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';

/// Backend falso: simula el daemon. Sirve 3 páginas PNG de 1x1 por capítulo.
class _FakeBackend implements MangaSourceBackend {
  int pages = 3;
  final pageCalls = <String>[];
  final _img = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  );

  @override
  Future<List<Map<String, dynamic>>> chapterPages(String source, Map<String, dynamic> chapter) async {
    return List.generate(pages, (i) => {'source': source, 'url': 'page-$i'});
  }

  @override
  Future<String> pageUrl(String source, Map<String, dynamic> page) async {
    pageCalls.add(page['url'] as String);
    // No podemos servir una URL real en tests; el HttpClientMock intercepta.
    return 'http://bakeneko.test/${page['url']}';
  }

  @override
  Future<Map<String, String>> sourceHeaders(String source) async => {'Referer': 'http://bakeneko.test'};
}

/// HttpClient que no abre sockets: sirve un body fijo para cualquier URL.
class _StubHttpClient implements HttpClient {
  final List<int> bytes;
  _StubHttpClient(this.bytes);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _StubRequest(bytes);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation inv) => super.noSuchMethod(inv);
}

class _StubRequest implements HttpClientRequest {
  final List<int> bytes;
  _StubRequest(this.bytes);
  @override
  HttpHeaders headers = _StubHeaders();
  @override
  Future<HttpClientResponse> close() async => _StubResponse(bytes);
  @override
  dynamic noSuchMethod(Invocation inv) => super.noSuchMethod(inv);
}

class _StubHeaders implements HttpHeaders {
  final Map<String, String> _m = {};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) => _m[name] = value.toString();
  @override
  dynamic noSuchMethod(Invocation inv) => super.noSuchMethod(inv);
}

class _StubResponse extends Stream<List<int>> implements HttpClientResponse {
  final List<int> bytes;
  _StubResponse(this.bytes);

  @override
  int statusCode = 200;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.fromIterable([bytes])
        .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation inv) => super.noSuchMethod(inv);
}

Manga _manga(String url) => Manga(
      source: 'MANGADEX',
      url: url,
      title: 'T',
      coverUrl: 'c',
      chapters: [
        Chapter(
          source: 'MANGADEX',
          url: '/ch1',
          title: 'Cap 1',
          number: 1,
          blob: {'source': 'MANGADEX', 'url': '/ch1', 'title': 'Cap 1', 'number': 1},
        ),
      ],
      blob: {
        'source': 'MANGADEX',
        'url': url,
        'title': 'T',
        'coverUrl': 'c',
        'chapters': [
          {'source': 'MANGADEX', 'url': '/ch1', 'title': 'Cap 1', 'number': 1}
        ],
      },
    );

void main() {
  late AppDatabase db;
  late MangaDao mangaDao;
  late DownloadDao downloadDao;
  late Directory tmpRoot;
  late _FakeBackend backend;
  late _StubHttpClient http;
  late DownloadManager mgr;

  setUp(() async {
    db = AppDatabase.memory();
    mangaDao = MangaDao(db);
    downloadDao = DownloadDao(db);
    tmpRoot = await Directory.systemTemp.createTemp('bakeneko_dl_');
    final img = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    );
    backend = _FakeBackend();
    http = _StubHttpClient(img);
    mgr = DownloadManager(
      backend: backend,
      mangaDao: mangaDao,
      downloadDao: downloadDao,
      downloadsRoot: tmpRoot,
      httpClient: http,
    );
  });
  tearDown(() async {
    mgr.dispose();
    db.close();
    if (tmpRoot.existsSync()) await tmpRoot.delete(recursive: true);
  });

  /// Espera a que la descarga de un chapter llegue a un estado terminal.
  Future<void> waitUntilDone(String mangaUrl, [String chapterUrl = '/ch1']) async {
    final manga = _manga(mangaUrl);
    final mangaId = mangaDao.upsert(manga);
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final e = downloadDao.get(mangaId, chapterUrl);
      if (e != null && (e.state == DownloadState.done || e.state == DownloadState.error)) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('enqueue descarga todas las páginas y marca completed.txt', () async {
    final manga = _manga('/a');
    await mgr.enqueue(manga, manga.chapters.first);
    await waitUntilDone('/a');

    final mangaId = mangaDao.upsert(manga);
    expect(downloadDao.get(mangaId, '/ch1')!.state, DownloadState.done);

    final dir = downloadedChapterDir(tmpRoot, 'MANGADEX', '/a', '/ch1');
    final jpgs = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jpg')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(jpgs.length, 3);
    expect(jpgs.map((f) => p.basename(f.path)).toList(), ['0001.jpg', '0002.jpg', '0003.jpg']);
    expect(File(p.join(dir.path, 'completed.txt')).existsSync(), isTrue);
  });

  test('no deja archivos .part al terminar (rename atómico)', () async {
    final manga = _manga('/b');
    await mgr.enqueue(manga, manga.chapters.first);
    await waitUntilDone('/b');

    final dir = downloadedChapterDir(tmpRoot, 'MANGADEX', '/b', '/ch1');
    final parts = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.part')).toList();
    expect(parts, isEmpty);
  });

  test('no re-descarga páginas existentes (idempotente)', () async {
    final manga = _manga('/c');
    await mgr.enqueue(manga, manga.chapters.first);
    await waitUntilDone('/c');

    final callsAfterFirst = backend.pageCalls.length;

    // Re-encolar: debería estar done y no re-procesar.
    await mgr.enqueue(manga, manga.chapters.first);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(backend.pageCalls.length, callsAfterFirst); // sin nuevas llamadas
  });

  test('pagesFor devuelve las páginas si está completo, vacío si no', () async {
    final manga = _manga('/d');
    expect(mgr.pagesFor(manga, manga.chapters.first), isEmpty); // no descargado

    await mgr.enqueue(manga, manga.chapters.first);
    await waitUntilDone('/d');

    final pages = mgr.pagesFor(manga, manga.chapters.first);
    expect(pages.length, 3);
    expect(mgr.isComplete(manga, manga.chapters.first), isTrue);
  });

  test('cancel elimina de la cola y deja estado idle', () async {
    final manga = _manga('/e');
    final mangaId = mangaDao.upsert(manga);
    await mgr.enqueue(manga, manga.chapters.first);
    await mgr.cancel(mangaId, '/ch1');
    // Dar tiempo a que el worker (si arrancó) no recoloque.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(downloadDao.get(mangaId, '/ch1')!.state, isNot(DownloadState.queued));
  });

  test('delete borra archivos y la fila en DB', () async {
    final manga = _manga('/f');
    final mangaId = mangaDao.upsert(manga);
    await mgr.enqueue(manga, manga.chapters.first);
    await waitUntilDone('/f');

    final dir = downloadedChapterDir(tmpRoot, 'MANGADEX', '/f', '/ch1');
    expect(dir.existsSync(), isTrue);

    await mgr.delete(mangaId, '/ch1');
    expect(dir.existsSync(), isFalse);
    expect(downloadDao.get(mangaId, '/ch1'), isNull);
  });

  test('3 descargas paralelas: no más de 3 en downloading simultáneo', () async {
    // 6 mangas distintos → 6 chapters. Concurrency=3.
    backend.pages = 20; // muchas páginas para alargar y poder observar concurrencia
    final mangas = List.generate(6, (i) => _manga('/p$i'));
    for (final m in mangas) {
      await mgr.enqueue(m, m.chapters.first);
    }

    // Observar la concurrencia máxima en algún punto del tiempo.
    var maxConcurrent = 0;
    for (var i = 0; i < 30; i++) {
      final downloading = downloadDao.list().where((e) => e.state == DownloadState.downloading).length;
      if (downloading > maxConcurrent) maxConcurrent = downloading;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(maxConcurrent, lessThanOrEqualTo(3));
  });
}
