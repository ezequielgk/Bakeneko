import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/models.dart';
import '../../core/theme/icons.dart';
import 'downloads_provider.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadsProvider);
    final isPaused = state.isPaused;

    // Solo mostramos queued, downloading, o error.
    final list = state.entries.where((e) => e.state != DownloadState.done).toList();

    return Scaffold(
      body: Column(
        children: [
          _TopBar(
            isPaused: isPaused,
            onTogglePause: () => ref.read(downloadsProvider.notifier).togglePause(),
          ),
          const Divider(height: 1, thickness: 0.5),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(I.downloads, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text('No hay descargas activas', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final e = list[i];
                      return _DownloadTile(entry: e);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isPaused, required this.onTogglePause});
  final bool isPaused;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline, width: 0.5)),
      ),
      child: Row(
        children: [
          Text('Descargas', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            onPressed: onTogglePause,
            icon: Icon(isPaused ? I.play : I.pause),
            tooltip: isPaused ? 'Reanudar descargas' : 'Pausar descargas',
          ),
        ],
      ),
    );
  }
}

class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.entry});
  final DownloadEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mangaDao = ref.watch(mangaDaoProvider);
    final manga = mangaDao.byId(entry.mangaId);

    // Intentar buscar el capítulo original para mostrar el título, 
    // pero si no está disponible, mostrar la url.
    final chTitle = manga?.chapters.where((c) => c.url == entry.chapterUrl).firstOrNull?.title ?? entry.chapterUrl;

    Widget leading;
    if (entry.state == DownloadState.downloading) {
      final progress = entry.totalPages > 0 ? entry.donePages / entry.totalPages : null;
      leading = Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(value: progress),
          if (progress != null)
            Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 10)),
        ],
      );
    } else if (entry.state == DownloadState.queued) {
      leading = const Icon(Icons.access_time);
    } else {
      leading = const Icon(Icons.error, color: Colors.red);
    }

    return ListTile(
      leading: SizedBox(width: 48, height: 48, child: leading),
      title: Text(manga?.title ?? 'Manga desconocido', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(chTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          ref.read(downloadsProvider.notifier).cancel(entry.mangaId, entry.chapterUrl);
        },
      ),
    );
  }
}