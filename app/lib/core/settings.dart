import 'dart:convert';
import 'dart:io';

import 'package:bakeneko/core/xdg.dart';
import 'package:path/path.dart' as p;

/// Preferencias de usuario, persistidas en un único settings.json legible.
/// Inmutable: copiar con [copyWith] y guardar con [SettingsStore.save].
class Settings {
  const Settings({
    this.themeMode = AppThemeMode.system,
    this.accent = Accent.terracotta,
    this.gridDensity = GridDensity.comfortable,
    this.defaultReadMode = ReadMode.webtoon,
    this.readerColorFilter = ColorFilterPreset.none,
    this.enabledSources = const ['MANGADEX'],
  });

  final AppThemeMode themeMode;
  final Accent accent;
  final GridDensity gridDensity;
  final ReadMode defaultReadMode;
  final ColorFilterPreset readerColorFilter;
  final List<String> enabledSources;

  Settings copyWith({
    AppThemeMode? themeMode,
    Accent? accent,
    GridDensity? gridDensity,
    ReadMode? defaultReadMode,
    ColorFilterPreset? readerColorFilter,
    List<String>? enabledSources,
  }) => Settings(
    themeMode: themeMode ?? this.themeMode,
    accent: accent ?? this.accent,
    gridDensity: gridDensity ?? this.gridDensity,
    defaultReadMode: defaultReadMode ?? this.defaultReadMode,
    readerColorFilter: readerColorFilter ?? this.readerColorFilter,
    enabledSources: enabledSources ?? this.enabledSources,
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'accent': accent.name,
    'gridDensity': gridDensity.name,
    'defaultReadMode': defaultReadMode.name,
    'readerColorFilter': readerColorFilter.name,
    'enabledSources': enabledSources,
  };

  factory Settings.fromJson(Map<String, dynamic> json) {
    T byName<T>(List<T> values, String? raw, T def) =>
        values.firstWhere((v) => v.toString().split('.').last == raw, orElse: () => def);
    return Settings(
      themeMode: byName(AppThemeMode.values, json["themeMode"] as String?, AppThemeMode.system),
      accent: byName(Accent.values, json['accent'] as String?, Accent.terracotta),
      gridDensity: byName(GridDensity.values, json['gridDensity'] as String?, GridDensity.comfortable),
      defaultReadMode: byName(ReadMode.values, json['defaultReadMode'] as String?, ReadMode.webtoon),
      readerColorFilter: byName(
        ColorFilterPreset.values,
        json['readerColorFilter'] as String?,
        ColorFilterPreset.none,
      ),
      enabledSources: (json['enabledSources'] as List?)?.cast<String>() ?? const ['MANGADEX'],
    );
  }

  static const Settings defaults = Settings();
}

enum AppThemeMode { light, dark, system }
enum Accent { terracotta, sage }
enum GridDensity { compact, comfortable, large }
enum ReadMode { webtoon, paginated }
enum ColorFilterPreset { none, grayscale, sepia, bluelight }

/// Lee/escribe settings.json bajo $XDG_CONFIG_HOME/bakeneko/.
class SettingsStore {
  SettingsStore({File? file}) : _file = file ?? File(p.join(Xdg.configRoot.path, 'settings.json'));

  final File _file;

  Settings load() {
    if (!_file.existsSync()) return Settings.defaults;
    try {
      final raw = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      return Settings.fromJson(raw);
    } catch (_) {
      return Settings.defaults;
    }
  }

  Future<void> save(Settings s) async {
    if (!_file.existsSync()) {
      _file.parent.createSync(recursive: true);
    }
    await _file.writeAsString(jsonEncode(s.toJson()));
  }
}