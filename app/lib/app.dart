import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/daemon/daemon_client.dart';
import 'core/db/database.dart';
import 'core/db/dao/category_dao.dart';
import 'core/db/dao/chapter_dao.dart';
import 'core/db/dao/download_dao.dart';
import 'core/db/dao/history_dao.dart';
import 'core/db/dao/manga_dao.dart';
import 'core/downloads/download_manager.dart';
import 'core/settings.dart';
import 'core/xdg.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/shell_view.dart';

/// Providers raíz de la app: daemon, base de datos, settings.
/// Singletons inyectados por Riverpod; testeables reemplazando el override.
final daemonClientProvider = Provider<DaemonClient>((ref) => DaemonClient());
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('override con AppDatabase.open/memory en ProviderScope');
});
final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  throw UnimplementedError('override en ProviderScope');
});
final daemonReadyProvider = FutureProvider<void>((ref) async {
  final c = ref.watch(daemonClientProvider);
  await c.start(jarPath: _resolveJarPathForBuild());
  ref.onDispose(c.stop);
});

// DAO providers: el main.dart los overridea con instancias reales.
final mangaDaoProvider = Provider<MangaDao>((ref) =>
    throw UnimplementedError());
final chapterDaoProvider = Provider<ChapterDao>((ref) =>
    throw UnimplementedError());
final downloadDaoProvider = Provider<DownloadDao>((ref) =>
    throw UnimplementedError());
final historyDaoProvider = Provider<HistoryDao>((ref) =>
    throw UnimplementedError());
final categoryDaoProvider = Provider<CategoryDao>((ref) =>
    throw UnimplementedError());

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final daemon = ref.watch(daemonClientProvider);
  final backend = DaemonBackend(daemon);
  final m = DownloadManager(
    backend: backend,
    mangaDao: ref.watch(mangaDaoProvider),
    downloadDao: ref.watch(downloadDaoProvider),
    downloadsRoot: Directory(Xdg.downloadsRoot.path),
  );
  ref.onDispose(m.dispose);
  return m;
});

/// Versión lógica de la biblioteca: bump tras mutar favoritos/categorías.
/// Los providers síncronos (Home/Library) lo [ref.watch]ean para refrescarse.
final libraryVersionProvider = StateProvider<int>((_) => 0);

String _resolveJarPathForBuild() {
  // En desarrollo: daemon/build/libs/bakeneko-daemon.jar relativo al SDK.
  // En release: junto al bundle. DaemonClient.defaultJarPath cubre ambos.
  return DaemonClient.defaultJarPath();
}

class SettingsNotifier extends StateNotifier<Settings> {
  SettingsNotifier(this._store, Settings initial) : super(initial);
  final SettingsStore _store;
  Future<void> update(Settings Function(Settings) fn) async {
    state = fn(state);
    await _store.save(state);
  }
}

class BakenekoApp extends ConsumerWidget {
  const BakenekoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ready = ref.watch(daemonReadyProvider);

    return MaterialApp(
      title: 'Bakeneko-Reader',
      debugShowCheckedModeBanner: false,
      theme: appTheme(AppThemeMode.light, settings.accent, Brightness.light, settings.cornerRadius),
      darkTheme: appTheme(AppThemeMode.dark, settings.accent, Brightness.dark, settings.cornerRadius),
      themeMode: _materialThemeMode(settings.themeMode),
      home: ready.when(
        data: (_) => const ShellView(),
        error: (e, _) => Scaffold(body: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error al iniciar: $e', textAlign: TextAlign.center),
          ]
        ))),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    );
  }

  ThemeMode _materialThemeMode(AppThemeMode m) =>
      m == AppThemeMode.dark ? ThemeMode.dark : (m == AppThemeMode.light ? ThemeMode.light : ThemeMode.system);
}