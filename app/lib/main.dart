import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/daemon/daemon_client.dart';
import 'core/db/database.dart';
import 'core/db/dao/category_dao.dart';
import 'core/db/dao/chapter_dao.dart';
import 'core/db/dao/download_dao.dart';
import 'core/db/dao/history_dao.dart';
import 'core/db/dao/manga_dao.dart';
import 'core/settings.dart';
import 'core/xdg.dart';

import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  Xdg.ensureDirs();

  final db = AppDatabase.open('${Xdg.dataRoot.path}/bakeneko.db');
  final settingsStore = SettingsStore();
  final mangaDao = MangaDao(db);
  final chapterDao = ChapterDao(db);
  final downloadDao = DownloadDao(db);
  final historyDao = HistoryDao(db, mangaDao);
  final categoryDao = CategoryDao(db);

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      settingsProvider.overrideWith((ref) => SettingsNotifier(settingsStore, settingsStore.load())),
      daemonClientProvider.overrideWithValue(DaemonClient()),
      mangaDaoProvider.overrideWithValue(mangaDao),
      chapterDaoProvider.overrideWithValue(chapterDao),
      downloadDaoProvider.overrideWithValue(downloadDao),
      historyDaoProvider.overrideWithValue(historyDao),
      categoryDaoProvider.overrideWithValue(categoryDao),
    ],
    child: const BakenekoApp(),
  ));
}