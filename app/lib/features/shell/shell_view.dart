import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/icons.dart';
import '../browse/browse_view.dart';
import '../details/details_view.dart';
import '../downloads/downloads_view.dart';
import '../extensions/extensions_view.dart';
import '../home/home_view.dart';
import '../library/library_view.dart';
import '../settings/settings_view.dart';

/// Secciones del sidebar (mismas que el mockup Figma + 'Explorar' acordada).
enum NavSection { home, library, browse, downloads, extensions, settings }

/// Estado global de navegación: la sección activa y la pila de Detalles.
/// Lleva un único `_notifier` (sin go_router) como se decidió en el diseño.
final navProvider = StateNotifierProvider<NavigationController, NavState>((ref) {
  ref.watch(detailsStackProvider);
  return NavigationController();
});

class NavState {
  const NavState({this.section = NavSection.library, this.details = const []});
  final NavSection section;
  final List<MangaRef> details; // pila de mangas abiertos (push/pop)
  bool get onDetails => details.isNotEmpty;
  NavState copyWith({NavSection? section, List<MangaRef>? details}) =>
      NavState(section: section ?? this.section, details: details ?? this.details);
}

final detailsStackProvider = StateProvider<List<MangaRef>>((_) => const []);

class NavigationController extends StateNotifier<NavState> {
  NavigationController() : super(const NavState());
  void go(NavSection s) => state = state.copyWith(section: s, details: const []);
  void openManga(MangaRef m) => state = state.copyWith(details: [...state.details, m]);
  void closeManga() => state = state.copyWith(details: state.details.isEmpty ? const [] : state.details.sublist(0, state.details.length - 1));
}

class ShellView extends ConsumerWidget {
  const ShellView({super.key});

  static const _items = <(NavSection, IconData, String)>[
    (NavSection.home, I.home, 'Home'),
    (NavSection.library, I.library, 'Biblioteca'),
    (NavSection.browse, I.explore, 'Explorar'),
    (NavSection.downloads, I.downloads, 'Descargas'),
    (NavSection.extensions, I.extensions, 'Extensiones'),
    (NavSection.settings, I.settings, 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(navProvider);
    final current = nav.details.isNotEmpty ? nav.details.last : null;
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(active: nav.section, onGo: (s) => ref.read(navProvider.notifier).go(s)),
          const VerticalDivider(width: 1, color: AppTokens.sidebarBorder),
          Expanded(
            child: current == null
                ? IndexedStack(index: nav.section.index, children: const [
                    HomeScreen(),
                    LibraryScreen(),
                    BrowseScreen(),
                    DownloadsScreen(),
                    ExtensionsScreen(),
                    SettingsScreen(),
                  ])
                : _DetailWithBack(mangaRef: current),
          ),
        ],
      ),
    );
  }
}

class _DetailWithBack extends ConsumerWidget {
  const _DetailWithBack({required this.mangaRef});
  final MangaRef mangaRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline, width: 0.5)),
          ),
          child: Row(children: [
            TextButton.icon(
              onPressed: () => ref.read(navProvider.notifier).closeManga(),
              icon: const Icon(I.chevronLeft, size: 18),
              label: const Text('Atrás'),
            ),
          ]),
        ),
        Expanded(child: DetailsView(ref: mangaRef)),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.active, required this.onGo});
  final NavSection active;
  final ValueChanged<NavSection> onGo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 196,
      color: AppTokens.sidebarBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'BAKENEKO',
                  style: TextStyle(
                    color: AppTokens.terracotta,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ...ShellView._items.map((it) {
                final (section, icon, label) = it;
                final isActive = section == active;
                return _NavItem(
                  icon: icon,
                  label: label,
                  active: isActive,
                  onTap: () => onGo(section),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppTokens.sidebarFgActive : AppTokens.sidebarFg;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(width: 3, color: active ? AppTokens.terracotta : Colors.transparent)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: fg, fontSize: 14, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}