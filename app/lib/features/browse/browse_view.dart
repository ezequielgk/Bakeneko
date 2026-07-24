import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/models.dart';
import '../../core/theme/icons.dart';
import '../../core/widgets/manga_cover.dart';
import '../shell/shell_view.dart';
import 'browse_controller.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _scrollCtrl = ScrollController();
  String _prevSource = '';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(browseProvider.notifier).loadFirst();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels > _scrollCtrl.position.maxScrollExtent - 400) {
      ref.read(browseProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(browseProvider);

    // Recarga si la fuente cambió.
    if (state.sourceId != _prevSource && _prevSource.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(browseProvider.notifier).loadFirst());
    }
    _prevSource = state.sourceId;

    return Scaffold(
      body: Column(
        children: [
          _Header(
            sourceId: state.sourceId,
            query: state.query,
            onSourceChanged: (s) => ref.read(browseProvider.notifier).setSource(s),
            onQueryChanged: (q) => ref.read(browseProvider.notifier).setQuery(q),
            onSearch: () => ref.read(browseProvider.notifier).loadFirst(),
          ),
          Expanded(child: _Body(state: state, scrollCtrl: _scrollCtrl)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.sourceId,
    required this.query,
    required this.onSourceChanged,
    required this.onQueryChanged,
    required this.onSearch,
  });
  final String sourceId;
  final String query;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSearch;

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
          Text('Explorar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),
          // Selector de fuente
          _SourceDropdown(sourceId: sourceId, onChanged: onSourceChanged),
          const SizedBox(width: 16),
          // Barra de búsqueda
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
          FilledButton(onPressed: onSearch, child: const Text('Buscar')),
        ],
      ),
    );
  }
}

class _SourceDropdown extends StatefulWidget {
  const _SourceDropdown({required this.sourceId, required this.onChanged});
  final String sourceId;
  final ValueChanged<String> onChanged;
  @override
  State<_SourceDropdown> createState() => _SourceDropdownState();
}

class _SourceDropdownState extends State<_SourceDropdown> {
  List<Source> _sources = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  void _loadSources() async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final daemon = container.read(daemonClientProvider);
      final list = await daemon.listSources();
      if (mounted) setState(() { _sources = list.map(Source.fromJson).toList(); _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    final current = _sources.where((s) => s.id == widget.sourceId).firstOrNull ?? _sources.firstOrNull;
    return PopupMenuButton<String>(
      initialValue: widget.sourceId,
      onSelected: widget.onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Row(children: [
          Text(current?.name ?? widget.sourceId, style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(I.chevronDown, size: 16),
        ]),
      ),
      itemBuilder: (_) => _sources.map((s) => PopupMenuItem(value: s.id, child: Text(s.name))).toList(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.scrollCtrl});
  final BrowseState state;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (state.error != null && state.mangas.isEmpty) {
      return _ErrorView(message: state.error!, onRetry: () => ProviderScope.containerOf(context, listen: false).read(browseProvider.notifier).loadFirst());
    }
    if (state.mangas.isEmpty) {
      return Center(child: Text('Sin resultados', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
    }

    return GridView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisExtent: 280,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: state.mangas.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= state.mangas.length) {
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))));
        }
        final manga = state.mangas[i];
        return MangaCover(manga: manga, onTap: () {
          final ref = ProviderScope.containerOf(context, listen: false);
          ref.read(navProvider.notifier).openManga(MangaRef(source: manga.source, url: manga.url, title: manga.title));
        });
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text('Error al cargar', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}