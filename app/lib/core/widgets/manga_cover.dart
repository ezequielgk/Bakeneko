import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/icons.dart';

/// Portada de manga reutilizable (Explorar, Home, Biblioteca).
///
/// Tamaños: [width] controla el ancho del card (por defecto 150, ~md).
/// [subtitle] muestra texto bajo el título (ej. "Cap. 12" en historial,
/// autor en catálogo). Si es null, se muestra el autor si existe.
class MangaCover extends StatelessWidget {
  const MangaCover({
    super.key,
    required this.manga,
    required this.onTap,
    this.onLongPress,
    this.width = 150,
    this.subtitle,
  });

  final Manga manga;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double width;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapUp: onLongPress != null ? (_) => onLongPress!() : null, // Para PC
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: manga.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: manga.coverUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (_, __, ___) =>
                              Icon(I.star, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        )
                      : const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              manga.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle ?? (manga.authors.isNotEmpty ? manga.authors.join(', ') : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
