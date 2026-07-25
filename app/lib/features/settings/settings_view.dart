import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/settings.dart';
import 'appearance_preview.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedIndex = 0;
  
  final List<String> _categories = [
    'Apariencia',
    'Lector',
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: Row(
        children: [
          SizedBox(
            width: 250,
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                return ListTile(
                  title: Text(_categories[i]),
                  selected: _selectedIndex == i,
                  onTap: () => setState(() => _selectedIndex = i),
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _AppearanceSettings(settings: settings, ref: ref),
                _ReaderSettings(settings: settings, ref: ref),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSettings extends StatelessWidget {
  const _AppearanceSettings({required this.settings, required this.ref});
  final Settings settings;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AppearancePreview(
          themeMode: settings.themeMode,
          accent: settings.accent,
          gridDensity: settings.gridDensity,
        ),
        const SizedBox(height: 32),
        Text('Tema', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<AppThemeMode>(
          initialValue: settings.themeMode,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: AppThemeMode.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
          onChanged: (val) {
            if (val != null) ref.read(settingsProvider.notifier).update((s) => s.copyWith(themeMode: val));
          },
        ),
        const SizedBox(height: 16),
        Text('Color de Acento', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<Accent>(
          initialValue: settings.accent,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: Accent.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
          onChanged: (val) {
            if (val != null) ref.read(settingsProvider.notifier).update((s) => s.copyWith(accent: val));
          },
        ),
        const SizedBox(height: 16),
        Text('Densidad de Portadas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<GridDensity>(
          initialValue: settings.gridDensity,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: GridDensity.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
          onChanged: (val) {
            if (val != null) ref.read(settingsProvider.notifier).update((s) => s.copyWith(gridDensity: val));
          },
        ),
        const SizedBox(height: 16),
        Text('Radio de bordes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<AppCornerRadius>(
          initialValue: settings.cornerRadius,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: AppCornerRadius.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
          onChanged: (val) {
            if (val != null) ref.read(settingsProvider.notifier).update((s) => s.copyWith(cornerRadius: val));
          },
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Mostrar contenido NSFW', style: Theme.of(context).textTheme.titleMedium),
          subtitle: const Text('Permite buscar y ver extensiones y mangas NSFW en toda la app'),
          value: settings.showNsfwContent,
          onChanged: (val) {
            ref.read(settingsProvider.notifier).update((s) => s.copyWith(showNsfwContent: val));
          },
        ),
      ],
    );
  }
}

class _ReaderSettings extends StatelessWidget {
  const _ReaderSettings({required this.settings, required this.ref});
  final Settings settings;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Modo de lectura por defecto', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<ReadMode>(
          initialValue: settings.defaultReadMode,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: ReadMode.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
          onChanged: (val) {
            if (val != null) ref.read(settingsProvider.notifier).update((s) => s.copyWith(defaultReadMode: val));
          },
        ),
        const SizedBox(height: 16),
        Text('Filtro de color', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<ColorFilterPreset>(
          initialValue: settings.readerColorFilter,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: ColorFilterPreset.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
          onChanged: (val) {
            if (val != null) ref.read(settingsProvider.notifier).update((s) => s.copyWith(readerColorFilter: val));
          },
        ),
      ],
    );
  }
}