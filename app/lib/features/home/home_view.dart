import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme/icons.dart';
import '../../core/widgets/manga_cover.dart';
import '../shell/shell_view.dart';
import 'home_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);
    return Scaffold(
      body: Column(
        children: [
          _TopBar(),
          const Divider(height: 1, thickness: 0.5),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _Section(
                  label: 'Continuar leyendo',
                  emptyText: 'No hay lectura reciente',
                  emptyIcon: I.play,
                  child: state.continueReading.isEmpty
                      ? null
                      : SizedBox(
                          height: 250,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: state.continueReading.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 16),
                            itemBuilder: (context, i) {
                              final h = state.continueReading[i];
                              return MangaCover(
                                manga: h.manga,
                                width: 130,
                                subtitle: 'Cap. ${h.chapterIndex + 1}',
                                onTap: () => _open(context, h.manga),
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 32),
                _Section(
                  label: 'Añadidos recientemente',
                  emptyText: 'Tu biblioteca está vacía',
                  emptyIcon: I.library,
                  child: state.recentlyAdded.isEmpty
                      ? null
                      : Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            for (final m in state.recentlyAdded.take(10))
                              SizedBox(
                                height: 250,
                                child: MangaCover(
                                  manga: m,
                                  width: 150,
                                  onTap: () => _open(context, m),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Manga m) =>
      ProviderScope.containerOf(context, listen: false)
          .read(navProvider.notifier)
          .openManga(MangaRef(source: m.source, url: m.url, title: m.title));
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline, width: 0.5)),
      ),
      alignment: Alignment.centerLeft,
      child: Text('Inicio', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

/// Sección con título + separador; si [child] es null muestra estado vacío.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.emptyText, required this.emptyIcon, required this.child});
  final String label;
  final String emptyText;
  final IconData emptyIcon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7A8C74))),
            const SizedBox(width: 16),
            const Expanded(child: Divider(height: 1, thickness: 0.5)),
          ],
        ),
        const SizedBox(height: 16),
        if (child != null)
          child!
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(emptyIcon, size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text(emptyText, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
