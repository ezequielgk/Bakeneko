import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/settings.dart';
import '../../core/widgets/manga_cover.dart';

class AppearancePreview extends StatelessWidget {
  const AppearancePreview({
    super.key,
    required this.themeMode,
    required this.accent,
    required this.gridDensity,
  });

  final AppThemeMode themeMode;
  final Accent accent;
  final GridDensity gridDensity;

  @override
  Widget build(BuildContext context) {
    final double maxExtent = switch (gridDensity) {
      GridDensity.compact => 120.0,
      GridDensity.comfortable => 160.0,
      GridDensity.large => 220.0,
    };

    final dummyManga = Manga(
      source: 'MANGADEX',
      url: '/manga/preview',
      title: 'Manga de Prueba',
      coverUrl: null,
      authors: ['Autor Desconocido'],
      chapters: [],
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Previsualización', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Icon(Icons.brush, size: 16, color: Theme.of(context).colorScheme.primary),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: maxExtent,
                childAspectRatio: 0.62,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: 4,
              itemBuilder: (context, i) => MangaCover(
                manga: dummyManga,
                width: maxExtent - 10,
                onTap: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
