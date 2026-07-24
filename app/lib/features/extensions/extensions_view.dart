import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';

final sourcesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final daemon = ref.watch(daemonClientProvider);
  return daemon.listSources();
});

class ExtensionsScreen extends ConsumerStatefulWidget {
  const ExtensionsScreen({super.key});

  @override
  ConsumerState<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends ConsumerState<ExtensionsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncSources = ref.watch(sourcesProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extensiones'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar extensiones...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => setState(() => _query = val.toLowerCase()),
            ),
          ),
        ),
      ),
      body: asyncSources.when(
        data: (sources) {
          final filtered = sources.where((s) {
            final name = (s['name'] as String?)?.toLowerCase() ?? '';
            return name.contains(_query);
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                'No se encontraron extensiones',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            );
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final source = filtered[i];
              final name = source['name'] as String? ?? 'Desconocida';
              final lang = source['lang'] as String? ?? 'N/A';
              
              final isEnabled = settings.enabledSources
                  .map((e) => e.toUpperCase())
                  .contains(name.toUpperCase());

              return SwitchListTile(
                title: Text(name),
                subtitle: Text('Idioma: $lang'),
                value: isEnabled,
                onChanged: (val) {
                  ref.read(settingsProvider.notifier).update((s) {
                    final current = List<String>.from(s.enabledSources);
                    final key = name.toUpperCase();
                    if (val) {
                      if (!current.contains(key)) current.add(key);
                    } else {
                      current.remove(key);
                    }
                    return s.copyWith(enabledSources: current);
                  });
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}