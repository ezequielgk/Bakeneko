import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme/icons.dart';
import 'details_controller.dart';

class DetailsView extends ConsumerWidget {
  const DetailsView({super.key, required this.ref});
  final MangaRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final state = widgetRef.watch(detailsProvider(ref));
    return Scaffold(
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _ErrorView(message: state.error!, onRetry: () => widgetRef.read(detailsProvider(ref).notifier).retry(ref))
              : _Content(manga: state.manga!, isFavorite: state.isFavorite, ref: ref),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.manga, required this.isFavorite, required this.ref});
  final Manga manga;
  final bool isFavorite;
  final MangaRef ref;

  @override
  Widget build(BuildContext context, WidgetRef w) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna izquierda: portada + acciones.
        SizedBox(
          width: 240,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  child: AspectRatio(
                    aspectRatio: 0.7,
                    child: Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: manga.coverUrl != null
                          ? CachedNetworkImage(imageUrl: manga.coverUrl!, fit: BoxFit.cover)
                          : const Icon(Icons.image_not_supported_outlined, size: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(I.play, size: 18),
                  label: const Text('Leer Ahora'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => w.read(detailsProvider(ref).notifier).toggleFavorite(),
                  icon: Icon(isFavorite ? I.bookmarkFilled : I.bookmark, size: 18, color: isFavorite ? Colors.red : null),
                  label: Text(isFavorite ? 'En Biblioteca' : 'Añadir a Biblioteca'),
                ),
              ],
            ),
          ),
        ),
        // Columna derecha: info + capítulos.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(manga.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                if (manga.authors.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(manga.authors.join(', '), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14)),
                ],
                const SizedBox(height: 16),
                Text('Sinopsis', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Text(manga.description ?? 'Sin descripción disponible.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Capítulos (${manga.chapters.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (manga.chapters.isNotEmpty)
                      TextButton.icon(onPressed: () {}, icon: const Icon(I.download, size: 16), label: const Text('Descargar Todo')),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  flex: 2,
                  child: manga.chapters.isEmpty
                      ? Center(child: Text('No hay capítulos disponibles', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
                      : ListView.builder(
                          itemCount: manga.chapters.length,
                          itemBuilder: (_, i) {
                            final ch = manga.chapters[i];
                            return ListTile(
                              dense: true,
                              title: Text(ch.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(onPressed: () {}, icon: const Icon(I.download, size: 18)),
                                  TextButton(onPressed: () {}, child: const Text('Ver')),
                                ],
                              ),
                              onTap: () {},
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
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
          Text('Error al cargar detalles', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}