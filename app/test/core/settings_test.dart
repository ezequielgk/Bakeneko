import 'dart:io';

import 'package:bakeneko/core/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late File settingsFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bakeneko-settings-');
    settingsFile = File('${tmp.path}/settings.json');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('load devuelve defaults si no hay archivo', () {
    final store = SettingsStore(file: settingsFile);
    expect(store.load(), Settings.defaults);
  });

  test('round-trip serializa y restaura todos los campos', () async {
    final store = SettingsStore(file: settingsFile);
    final s = Settings.defaults.copyWith(
      themeMode: AppThemeMode.dark,
      accent: Accent.sage,
      gridDensity: GridDensity.large,
      defaultReadMode: ReadMode.paginated,
      readerColorFilter: ColorFilterPreset.sepia,
      enabledSources: ['MANGADEX', 'MANGA_PLUS'],
    );
    await store.save(s);

    final loaded = store.load();
    expect(loaded.themeMode, AppThemeMode.dark);
    expect(loaded.accent, Accent.sage);
    expect(loaded.gridDensity, GridDensity.large);
    expect(loaded.defaultReadMode, ReadMode.paginated);
    expect(loaded.readerColorFilter, ColorFilterPreset.sepia);
    expect(loaded.enabledSources, ['MANGADEX', 'MANGA_PLUS']);
  });

  test('load ignora JSON corrupto y devuelve defaults', () {
    settingsFile.writeAsStringSync('{ no es json');
    final store = SettingsStore(file: settingsFile);
    expect(store.load(), Settings.defaults);
  });

  test('toJson produce nombres de enum legibles', () {
    final json = Settings.defaults.toJson();
    expect(json['themeMode'], 'system');
    expect(json['accent'], 'terracotta');
    expect(json['readerColorFilter'], 'none');
  });

  test('fromJson tolera campos desconocidos', () {
    final s = Settings.fromJson({'themeMode': 'dark', 'algoDesconocido': 42} as Map<String, dynamic>);
    expect(s.themeMode, AppThemeMode.dark);
  });
}