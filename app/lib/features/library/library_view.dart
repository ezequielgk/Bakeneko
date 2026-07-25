import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/icons.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/manga_cover.dart';
import '../shell/shell_view.dart';
import 'library_controller.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryProvider);
    final activeId = ref.watch(libraryActiveCategoryProvider);
    final active = state.categories.where((c) => c.id == activeId).firstOrNull;

    return Scaffold(
      endDrawer: _FilterDrawer(
        currentFilter: state.filter,
        onFilter: (f) => ref.read(libraryProvider.notifier).setFilter(f),
      ),
      body: Column(
        children: [
          _Header(
            title: active?.name ?? 'Biblioteca',
            hasActive: active != null,
            active: active,
            onRename: (name) => ref.read(libraryProvider.notifier).renameCategory(active!.id!, name),
            onDelete: () => ref.read(libraryProvider.notifier).deleteCategory(active!.id!),
            onToggleAuto: () => ref.read(libraryProvider.notifier).toggleAutoDownload(active!.id!),
          ),
          _CategoryTabs(
            categories: state.categories,
            activeId: activeId,
            onSelect: (id) => ref.read(libraryProvider.notifier).selectCategory(id),
            onCreate: (name, color) => ref.read(libraryProvider.notifier).createCategory(name, color),
          ),
          const Divider(height: 1, thickness: 0.5),
          Expanded(child: _Grid(mangas: state.mangas)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.hasActive,
    required this.active,
    required this.onRename,
    required this.onDelete,
    required this.onToggleAuto,
  });
  final String title;
  final bool hasActive;
  final Category? active;
  final ValueChanged<String> onRename;
  final VoidCallback onDelete;
  final VoidCallback onToggleAuto;

  @override
  Widget build(BuildContext context) {
    final cat = active;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: const Icon(I.filter, size: 20),
            tooltip: 'Filtros',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
          if (hasActive && cat != null) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(I.more, size: 20),
              tooltip: 'Opciones de categoría',
              onSelected: (v) {
                if (v == 'delete') {
                  onDelete();
                } else if (v == 'rename') {
                  _showRenameDialog(context, cat.name, onRename);
                } else if (v == 'auto') {
                  onToggleAuto();
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                const PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                PopupMenuItem(
                  value: 'auto',
                  child: Row(children: [
                    Icon(I.autoDl, size: 16, color: cat.autoDownload ? AppTokens.terracotta : null),
                    const SizedBox(width: 8),
                    Text(cat.autoDownload ? 'Auto-descarga: ON' : 'Auto-descarga: OFF'),
                  ]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete', child: Text('Borrar categoría')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

void _showRenameDialog(BuildContext context, String current, ValueChanged<String> onRename) {
  final ctrl = TextEditingController(text: current);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Renombrar categoría'),
      content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Nombre')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final n = ctrl.text.trim();
            if (n.isNotEmpty) onRename(n);
            Navigator.pop(ctx);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

/// Fila de tabs: "Todas" + categorías + botón de crear inline.
class _CategoryTabs extends ConsumerStatefulWidget {
  const _CategoryTabs({
    required this.categories,
    required this.activeId,
    required this.onSelect,
    required this.onCreate,
  });
  final List<Category> categories;
  final int? activeId;
  final ValueChanged<int?> onSelect;
  final void Function(String name, String color) onCreate;

  @override
  ConsumerState<_CategoryTabs> createState() => _CategoryTabsState();
}

class _CategoryTabsState extends ConsumerState<_CategoryTabs> {
  bool _creating = false;
  String _newName = '';
  String _newColor = AppTokens.categoryColors.first;

  void _commit() {
    final n = _newName.trim();
    if (n.isEmpty) return;
    widget.onCreate(n, _newColor);
    setState(() {
      _creating = false;
      _newName = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _pill(
            context: context,
            label: 'Todas',
            active: widget.activeId == null,
            color: null,
            onTap: () => widget.onSelect(null),
          ),
          const SizedBox(width: 8),
          for (final c in widget.categories) ...[
            _pill(
              context: context,
              label: c.name,
              active: c.id == widget.activeId,
              color: c.color,
              trailing: c.autoDownload ? Icon(I.autoDl, size: 12) : null,
              onTap: () => widget.onSelect(c.id),
            ),
            const SizedBox(width: 8),
          ],
          if (_creating)
            _CreateRow(
              color: _newColor,
              name: _newName,
              onName: (v) => setState(() => _newName = v),
              onColor: (v) => setState(() => _newColor = v),
              onCommit: _commit,
              onCancel: () => setState(() => _creating = false),
            )
          else
            _pill(
              context: context,
              label: 'Nueva',
              active: false,
              color: null,
              icon: I.plus,
              onTap: () => setState(() => _creating = true),
            ),
        ],
      ),
    );
  }

  Widget _pill({
    required BuildContext context,
    required String label,
    required bool active,
    required String? color,
    IconData? icon,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final accent = color != null ? _parseColor(color) : cs.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.15) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? accent : cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              Icon(icon, size: 14),
              const SizedBox(width: 4),
            ],
            Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? accent : cs.onSurface)),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing,
            ],
          ],
        ),
      ),
    );
  }
}

class _CreateRow extends StatelessWidget {
  const _CreateRow({
    required this.color,
    required this.name,
    required this.onName,
    required this.onColor,
    required this.onCommit,
    required this.onCancel,
  });
  final String color;
  final String name;
  final ValueChanged<String> onName;
  final ValueChanged<String> onColor;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in AppTokens.categoryColors)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () => onColor(c),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _parseColor(c),
                  shape: BoxShape.circle,
                  border: c == color ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2) : null,
                ),
              ),
            ),
          ),
        const SizedBox(width: 6),
        SizedBox(
          width: 120,
          child: TextField(
            autofocus: true,
            onChanged: onName,
            onSubmitted: (_) => onCommit(),
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(hintText: 'Nombre…', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
          ),
        ),
        IconButton(icon: const Icon(I.check, size: 16), onPressed: onCommit, visualDensity: VisualDensity.compact),
        IconButton(icon: const Icon(Icons.close, size: 16), onPressed: onCancel, visualDensity: VisualDensity.compact),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.mangas});
  final List<Manga> mangas;

  @override
  Widget build(BuildContext context) {
    if (mangas.isEmpty) {
      return EmptyStateAction(
        icon: I.library,
        message: 'Tu biblioteca está vacía\nExplora mangas y márcalos como favorito',
        buttonText: 'Explorar',
        onPressed: () {
          ProviderScope.containerOf(context, listen: false)
              .read(navProvider.notifier)
              .go(NavSection.browse);
        },
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisExtent: 280,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: mangas.length,
      itemBuilder: (context, i) {
        final m = mangas[i];
        return MangaCover(
          manga: m,
          width: 150,
          onTap: () => ProviderScope.containerOf(context, listen: false)
              .read(navProvider.notifier)
              .openManga(MangaRef(source: m.source, url: m.url, title: m.title)),
          onLongPress: () => _showCategoryPopover(context, m),
        );
      },
    );
  }
}

void _showCategoryPopover(BuildContext context, Manga manga) {
  final ref = ProviderScope.containerOf(context, listen: false);
  final categories = ref.read(libraryProvider).categories;
  final assigned = ref.read(libraryProvider.notifier).getCategoriesForManga(manga).toSet();

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(manga.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Añadir a categoría:', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  if (categories.isEmpty)
                    Text('No hay categorías creadas.', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  for (final c in categories)
                    CheckboxListTile(
                      title: Text(c.name, style: const TextStyle(fontSize: 14)),
                      value: assigned.contains(c.id),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          if (v) {
                            assigned.add(c.id!);
                          } else {
                            assigned.remove(c.id!);
                          }
                        });
                        ref.read(libraryProvider.notifier).toggleCategoryForManga(manga, c.id!, v);
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
            ],
          );
        },
      );
    },
  );
}

class _FilterDrawer extends StatelessWidget {
  const _FilterDrawer({required this.currentFilter, required this.onFilter});
  final LibraryFilter currentFilter;
  final ValueChanged<LibraryFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
            ),
            const Divider(height: 1),
            _FilterItem(label: 'Todos', value: LibraryFilter.all, groupValue: currentFilter, onChanged: onFilter),
            _FilterItem(label: 'No leídos', value: LibraryFilter.unread, groupValue: currentFilter, onChanged: onFilter),
            _FilterItem(label: 'Leídos', value: LibraryFilter.read, groupValue: currentFilter, onChanged: onFilter),
            _FilterItem(label: 'Descargados', value: LibraryFilter.downloaded, groupValue: currentFilter, onChanged: onFilter),
            _FilterItem(label: 'No descargados', value: LibraryFilter.notDownloaded, groupValue: currentFilter, onChanged: onFilter),
          ],
        ),
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  const _FilterItem({required this.label, required this.value, required this.groupValue, required this.onChanged});
  final String label;
  final LibraryFilter value;
  final LibraryFilter groupValue;
  final ValueChanged<LibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<LibraryFilter>(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      groupValue: groupValue,
      onChanged: (v) {
        if (v != null) {
          onChanged(v);
          Navigator.pop(context); // Close drawer
        }
      },
    );
  }
}

Color _parseColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}
