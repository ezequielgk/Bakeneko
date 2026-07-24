import 'dart:convert';

import 'package:bakeneko/core/db/dao/chapter_dao.dart';
import 'package:bakeneko/core/db/dao/download_dao.dart';
import 'package:bakeneko/core/db/dao/manga_dao.dart';
import 'package:bakeneko/core/db/dao/history_dao.dart';
import 'package:bakeneko/core/db/database.dart';
import 'package:bakeneko/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

Manga _m(String url, {String title = 'T', String source = 'MANGADEX'}) =>
    Manga(source: source, url: url, title: title, coverUrl: 'c', blob: {
      'source': source,
      'url': url,
      'title': title,
      'coverUrl': 'c',
    });

void main() {
  late AppDatabase db;
  late MangaDao manga;
  late ChapterDao chapters;
  late HistoryDao history;
  late DownloadDao downloads;

  setUp(() {
    db = AppDatabase.memory();
    manga = MangaDao(db);
    chapters = ChapterDao(db);
    history = HistoryDao(db, manga);
    downloads = DownloadDao(db);
  });
  tearDown(() => db.close());

  test('MangaDao upsert es idempotente y devuelve id estable', () {
    final id1 = manga.upsert(_m('/title/a'));
    final id2 = manga.upsert(_m('/title/a', title: 'T2'));
    expect(id1, id2);
    final m = manga.byId(id1)!;
    expect(m.title, 'T2');
  });

  test('MangaDao favoritos persisten y se listan', () {
    final id = manga.upsert(_m('/x'));
    expect(manga.isFavorite(id), isFalse);
    manga.setFavorite(id, true);
    expect(manga.isFavorite(id), isTrue);
    expect(manga.favorites().length, 1);
    manga.setFavorite(id, false);
    expect(manga.favorites(), isEmpty);
  });

  test('ChapterDao replaceChapters reemplaza y ordena desc', () {
    final id = manga.upsert(_m('/x'));
    chapters.replaceChapters(id, [
      Chapter(source: 'MANGADEX', url: '/c1', title: 'c1', number: 1, blob: {'source': 'MANGADEX', 'url': '/c1', 'title': 'c1', 'number': 1}),
      Chapter(source: 'MANGADEX', url: '/c2', title: 'c2', number: 2, blob: {'source': 'MANGADEX', 'url': '/c2', 'title': 'c2', 'number': 2}),
    ]);
    final list = chapters.forManga(id);
    expect(list.length, 2);
    expect(list.first.number, 2); // DESC
    chapters.setRead(id, '/c1', true);
    expect(chapters.unreadCount(id, '/c1'), 0);
  });

  test('HistoryDao upsert reemplaza y list ordena DESC', () {
    final id1 = manga.upsert(_m('/a', title: 'A'));
    final id2 = manga.upsert(_m('/b', title: 'B'));
    history.upsert(id1, chapterIndex: 3, now: 1000);
    history.upsert(id2, chapterIndex: 1, now: 2000);
    final list = history.list();
    expect(list.first.manga.title, 'B');
    expect(history.forManga(id1)!.chapterIndex, 3);
    history.upsert(id1, chapterIndex: 9, now: 3000);
    expect(history.forManga(id1)!.chapterIndex, 9);
    expect(history.list().first.manga.title, 'A');
  });

  test('DownloadDao upsert y pending filtra estados', () {
    final id = manga.upsert(_m('/a'));
    downloads.upsert(mangaId: id, chapterUrl: '/c1', state: DownloadState.queued);
    downloads.upsert(mangaId: id, chapterUrl: '/c2', state: DownloadState.done);
    expect(downloads.pending().length, 1);
    expect(downloads.pending().first.chapterUrl, '/c1');
    downloads.setProgress(id, '/c1', 5, 10);
    expect(downloads.get(id, '/c1')!.donePages, 5);
    downloads.setState(id, '/c1', DownloadState.downloading);
    expect(downloads.get(id, '/c1')!.state, DownloadState.downloading);
  });

  test('DownloadDao list ordena (no-done primero) y done filtra completados', () {
    final id = manga.upsert(_m('/a'));
    downloads.upsert(mangaId: id, chapterUrl: '/c1', state: DownloadState.queued);
    downloads.upsert(mangaId: id, chapterUrl: '/c2', state: DownloadState.done);
    downloads.upsert(mangaId: id, chapterUrl: '/c3', state: DownloadState.done);

    // list: pendientes antes que done
    final all = downloads.list();
    expect(all.length, 3);
    expect(all.first.chapterUrl, '/c1');

    // done: solo completados
    final done = downloads.done();
    expect(done.length, 2);
    expect(done.every((d) => d.state == DownloadState.done), isTrue);
  });

  test('DownloadDao contadores de storage', () {
    final id1 = manga.upsert(_m('/a', title: 'A'));
    final id2 = manga.upsert(_m('/b', title: 'B'));
    downloads.upsert(mangaId: id1, chapterUrl: '/c1', state: DownloadState.done);
    downloads.upsert(mangaId: id1, chapterUrl: '/c2', state: DownloadState.done);
    downloads.upsert(mangaId: id2, chapterUrl: '/c1', state: DownloadState.done);
    downloads.upsert(mangaId: id2, chapterUrl: '/c3', state: DownloadState.queued); // no cuenta

    expect(downloads.countDoneChapters(), 3);
    expect(downloads.countDoneManga(), 2);
  });

  test('blob persistido es JSON válido y reconstruye Manga', () {
    final id = manga.upsert(_m('/z', title: 'Zman'));
    final m = manga.byId(id)!;
    expect(m.title, 'Zman');
    // El blob reconstruido es un Map válido (lo serializamos a JSON y back).
    expect(() => jsonEncode(m.blob), returnsNormally);
    final round = Manga.fromJson(m.blob!);
    expect(round.title, 'Zman');
  });
}