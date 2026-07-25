import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/models.dart';
import '../../core/settings.dart';
import '../../core/theme/icons.dart';
import '../../core/widgets/manga_cover.dart';
import '../shell/shell_view.dart';
import 'browse_controller.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key, this.lockedSourceId});
  final String? lockedSourceId;

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locked = widget.lockedSourceId ?? '';
      ref.read(browseProvider(locked).notifier).loadFirst();
    });
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _FiltersBottomSheet(lockedSourceId: widget.lockedSourceId),
    ).then((_) {
      // Reload on close in case filters changed
      final locked = widget.lockedSourceId ?? '';
      ref.read(browseProvider(locked).notifier).loadFirst();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.lockedSourceId ?? '';
    final state = ref.watch(browseProvider(locked));
    final controller = ref.read(browseProvider(locked).notifier);

    return Scaffold(
      body: Column(
        children: [
          _Header(
            query: state.query,
            locked: widget.lockedSourceId != null,
            onQueryChanged: controller.setQuery,
            onSearch: controller.loadFirst,
            onFilter: _showFilters,
          ),
          Expanded(child: _Body(state: state, lockedSourceId: widget.lockedSourceId)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.query,
    required this.locked,
    required this.onQueryChanged,
    required this.onSearch,
    required this.onFilter,
  });
  final String query;
  final bool locked;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSearch;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(I.explore, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(locked ? 'Extensión' : 'Explorar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: query)..selection = TextSelection.fromPosition(TextPosition(offset: query.length)),
              onChanged: onQueryChanged,
              onSubmitted: (_) => onSearch(),
              decoration: InputDecoration(
                hintText: 'Buscar manga...',
                prefixIcon: const Icon(I.search, size: 18),
                isDense: true,
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onFilter,
            icon: const Icon(Icons.filter_list, size: 18),
            label: const Text('Filtros'),
          ),
          const SizedBox(width: 12),
          FilledButton(onPressed: onSearch, child: const Text('Buscar')),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.lockedSourceId});
  final BrowseState state;
  final String? lockedSourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (state.error != null && state.mangasBySource.isEmpty) {
      return Center(child: Text('Error: ${state.error}', style: TextStyle(color: Theme.of(context).colorScheme.error)));
    }
    if (state.mangasBySource.isEmpty) {
      return Center(child: Text('Sin resultados', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: state.mangasBySource.length,
      itemBuilder: (context, i) {
        final sourceName = state.mangasBySource.keys.elementAt(i);
        final mangas = state.mangasBySource[sourceName]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(sourceName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisExtent: 280,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: mangas.length,
              itemBuilder: (context, j) {
                final manga = mangas[j];
                return MangaCover(
                  manga: manga,
                  width: 150,
                  onTap: () {
                    ref.read(navProvider.notifier).openManga(MangaRef(source: manga.source, url: manga.url, title: manga.title));
                  },
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

class _FiltersBottomSheet extends ConsumerStatefulWidget {
  const _FiltersBottomSheet({this.lockedSourceId});
  final String? lockedSourceId;

  @override
  ConsumerState<_FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends ConsumerState<_FiltersBottomSheet> {
  List<Source> _allSources = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  void _loadSources() async {
    final daemon = ref.read(daemonClientProvider);
    try {
      final list = await daemon.listSources();
      if (mounted) {
        setState(() {
          _allSources = list.map(Source.fromJson).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isLocked = widget.lockedSourceId != null;

    if (_loading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }

    final enabledSources = _allSources.where((s) => settings.enabledSources.contains(s.id));
    final langs = enabledSources.map((s) => s.lang).toSet().toList()..sort();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filtros', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 24),
          
          SwitchListTile(
            title: const Text('Mostrar contenido NSFW'),
            subtitle: const Text('Sobreescribe el ajuste global para esta búsqueda'),
            value: settings.browseNsfwOverride ?? settings.showNsfwContent,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(browseNsfwOverride: val));
            },
          ),
          const Divider(),
          
          const Text('Idiomas', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: langs.map((l) {
              final selected = settings.browseSelectedLangs.contains(l);
              return FilterChip(
                label: Text(l),
                selected: selected,
                onSelected: (val) {
                  final list = List<String>.from(settings.browseSelectedLangs);
                  val ? list.add(l) : list.remove(l);
                  ref.read(settingsProvider.notifier).update((s) => s.copyWith(browseSelectedLangs: list));
                },
              );
            }).toList(),
          ),
          
          if (!isLocked) ...[
            const SizedBox(height: 16),
            const Divider(),
            const Text('Fuentes', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: settings.enabledSources.map((srcId) {
                final source = _allSources.where((s) => s.id == srcId).firstOrNull;
                final name = source?.name ?? srcId;
                final selected = settings.browseSelectedSources.isEmpty || settings.browseSelectedSources.contains(srcId);
                
                return FilterChip(
                  label: Text(name),
                  selected: selected,
                  onSelected: (val) {
                    List<String> list = List<String>.from(settings.browseSelectedSources);
                    // If empty, it means all were selected. So we need to explicitly populate the list with all others first, then remove.
                    if (list.isEmpty) {
                      list = List<String>.from(settings.enabledSources);
                    }
                    val ? list.add(srcId) : list.remove(srcId);
                    if (list.length == settings.enabledSources.length) list.clear(); // Reset to empty if all selected
                    ref.read(settingsProvider.notifier).update((s) => s.copyWith(browseSelectedSources: list));
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}