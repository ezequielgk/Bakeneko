import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/models.dart';
import '../../core/settings.dart';
import 'reader_controller.dart';
import 'reader_state.dart';

class ReaderView extends ConsumerWidget {
  const ReaderView({super.key, required this.manga, required this.chapterIndex});
  final Manga manga;
  final int chapterIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final arg = ReaderArg(manga: manga, chapterIndex: chapterIndex, settings: settings);
    final state = ref.watch(readerProvider(arg));

    if (state.error != null && state.pageUrls.isEmpty) {
      return _ReaderError(message: state.error!, onRetry: () => ref.read(readerProvider(arg).notifier).retry(arg));
    }
    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.chapters.isEmpty) {
      return const Scaffold(body: Center(child: Text('No hay capítulos.')));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          state.readMode == ReadMode.webtoon
              ? _WebtoonPages(state: state)
              : _PagedPages(state: state),
          _BottomBar(
            state: state,
            onPrev: () => ref.read(readerProvider(arg).notifier).prevChapter(arg),
            onNext: () => ref.read(readerProvider(arg).notifier).nextChapter(arg),
            onToggleMode: () => ref.read(readerProvider(arg).notifier).setReadMode(
                state.readMode == ReadMode.webtoon ? ReadMode.paginated : ReadMode.webtoon),
            onColorFilter: () => _showFilterMenu(context, ref, arg, state.colorFilter),
          ),
        ],
      ),
    );
  }

  void _showFilterMenu(BuildContext context, WidgetRef ref, ReaderArg arg, ColorFilterPreset current) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('Filtros de color', style: TextStyle(fontWeight: FontWeight.bold))),
            for (final f in ColorFilterPreset.values)
              RadioListTile<ColorFilterPreset>(
                value: f,
                groupValue: current,
                title: Text(_filterLabel(f)),
                onChanged: (v) {
                  if (v != null) ref.read(readerProvider(arg).notifier).setColorFilter(v);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _filterLabel(ColorFilterPreset f) => switch (f) {
        ColorFilterPreset.none => 'Ninguno',
        ColorFilterPreset.grayscale => 'Blanco y negro',
        ColorFilterPreset.sepia => 'Sepia',
        ColorFilterPreset.bluelight => 'Luz azul (night shift)',
      };
}

class _WebtoonPages extends StatelessWidget {
  const _WebtoonPages({required this.state});
  final ReaderState state;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: state.pageUrls.length + 1,
      itemBuilder: (context, i) {
        if (i == state.pageUrls.length) return const SizedBox(height: 80);
        return _Page(url: state.pageUrls[i], filter: state.colorFilter, fit: BoxFit.fitWidth);
      },
    );
  }
}

class _PagedPages extends StatefulWidget {
  const _PagedPages({required this.state});
  final ReaderState state;

  @override
  State<_PagedPages> createState() => _PagedPagesState();
}

class _PagedPagesState extends State<_PagedPages> {
  late PageController _ctrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() => _ctrl.dispose();

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _ctrl,
      itemCount: widget.state.pageUrls.length,
      onPageChanged: (p) => setState(() => _page = p),
      itemBuilder: (context, i) => _Page(
        url: widget.state.pageUrls[i],
        filter: widget.state.colorFilter,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.url, required this.filter, required this.fit});
  final String url;
  final ColorFilterPreset filter;
  final BoxFit fit;

  ColorFilter? get _colorFilter => switch (filter) {
        ColorFilterPreset.none => null,
        ColorFilterPreset.grayscale => const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
        ColorFilterPreset.sepia => const ColorFilter.matrix(<double>[
            0.393, 0.769, 0.189, 0, 0,
            0.349, 0.686, 0.168, 0, 0,
            0.272, 0.534, 0.131, 0, 0,
            0, 0, 0, 1, 0,
          ]),
        ColorFilterPreset.bluelight => const ColorFilter.matrix(<double>[
            1, 0, 0, 0, 0,
            0, 1, 0, 0, 0,
            0, 0, 0.6, 0, 0,
            0, 0, 0, 1, 0,
          ]),
      };

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (url.startsWith('file://')) {
      final path = url.replaceFirst('file://', '');
      img = Image.file(
        File(path),
        fit: fit,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 40),
      );
    } else {
      img = CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white54)),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 40),
      );
    }
    final cf = _colorFilter;
    return cf == null ? img : ColorFiltered(colorFilter: cf, child: img);
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.onPrev,
    required this.onNext,
    required this.onToggleMode,
    required this.onColorFilter,
  });
  final ReaderState state;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToggleMode;
  final VoidCallback onColorFilter;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: state.currentChapter > 0 ? onPrev : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Capítulo anterior',
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.chapters[state.currentChapter].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(onPressed: onToggleMode, child: Text(state.readMode == ReadMode.webtoon ? 'Webtoon' : 'Paginado')),
                      TextButton(onPressed: onColorFilter, child: const Text('Filtros')),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: state.currentChapter < state.chapters.length - 1 ? onNext : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Capítulo siguiente',
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.white54),
            const SizedBox(height: 12),
            Text('Error al cargar páginas', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 4),
            Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}