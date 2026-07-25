import 'package:flutter/material.dart';

import '../settings.dart';

/// Paleta y tokens del mockup Figma. Una sola fuente de verdad para los
/// colores en claro y oscuro, con los dos acentos (terracotta / sage).
class AppTokens {
  // Núcleo "espresso" (sidebar, fondo oscuro).
  static const espresso = Color(0xFF1A120B);
  static const espressoDeep = Color(0xFF120D08);
  static const espressoBorder = Color(0xFF2E1E10);

  // Acentos.
  static const terracotta = Color(0xFFE29578);
  static const sage = Color(0xFFA3B19B);
  static const tan = Color(0xFFDDB892);
  static const cream = Color(0xFFEDE0D4);
  static const muted = Color(0xFF7A8C74);

  // Light theme.
  static const lightBackground = Color(0xFFEDE0D4);
  static const lightForeground = Color(0xFF1A120B);
  static const lightCard = Color(0xFFF5ECE2);
  static const lightSecondary = Color(0xFFE4D3BF);
  static const lightMutedFg = Color(0xFF7A8C74);
  static const lightBorder = Color(0xFFD4B896);

  // Dark theme (mismos acentos, fondo invertido).
  static const darkBackground = Color(0xFF1A120B);
  static const darkForeground = Color(0xFFEDE0D4);
  static const darkCard = Color(0xFF231810);
  static const darkSecondary = Color(0xFF2E2016);
  static const darkMutedFg = Color(0xFFA3B19B);
  static const darkBorder = Color(0xFF3A2A1E);

  // Sidebar (siempre espresso en ambos modos, como en el mockup).
  static const sidebarBg = espresso;
  static const sidebarFg = sage;
  static const sidebarFgActive = cream;
  static const sidebarBorder = Color(0xFF2E1E10); // Better contrast

  /// Paleta de colores para categorías (hex strings, como se guardan en DB).
  /// El usuario elige al crear una categoría.
  static const categoryColors = <String>[
    '#e29578', // terracotta
    '#a3b19b', // sage
    '#ddb892', // tan
    '#c08552', // ochre
    '#7a8c74', // muted sage
    '#b56576', // berry
    '#8a7090', // mauve
    '#5e8b7e', // teal sage
  ];
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

/// Construye el [ColorScheme] según modo de tema y acento elegido.
ColorScheme colorSchemeFor(AppThemeMode mode, Accent accent, Brightness brightness) {
  final isDark = mode == AppThemeMode.dark ||
      (mode == AppThemeMode.system && brightness == Brightness.dark);
  final primary = accent == Accent.sage ? AppTokens.sage : AppTokens.terracotta;
  if (isDark) {
    return ColorScheme.dark(
      primary: primary,
      onPrimary: AppTokens.espresso,
      secondary: AppTokens.tan,
      onSecondary: AppTokens.espresso,
      surface: AppTokens.darkCard,
      onSurface: AppTokens.darkForeground,
      surfaceContainerHighest: AppTokens.darkSecondary,
      onSurfaceVariant: AppTokens.darkMutedFg,
      error: const Color(0xFFCF6679),
      outline: AppTokens.darkBorder,
    );
  }
  return ColorScheme.light(
    primary: primary,
    onPrimary: AppTokens.espresso,
    secondary: AppTokens.tan,
    onSecondary: AppTokens.espresso,
    surface: AppTokens.lightCard,
    onSurface: AppTokens.lightForeground,
    surfaceContainerHighest: AppTokens.lightSecondary,
    onSurfaceVariant: AppTokens.lightMutedFg,
    error: const Color(0xFFB00020),
    outline: AppTokens.lightBorder,
  );
}

ThemeData appTheme(AppThemeMode mode, Accent accent, Brightness brightness, AppCornerRadius cornerRadius) {
  final cs = colorSchemeFor(mode, accent, brightness);
  
  double radiusValue;
  switch (cornerRadius) {
    case AppCornerRadius.sharp:
      radiusValue = 0.0;
      break;
    case AppCornerRadius.slight:
      radiusValue = 8.0;
      break;
    case AppCornerRadius.rounded:
      radiusValue = 16.0;
      break;
  }
  
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: mode == AppThemeMode.dark || (mode == AppThemeMode.system && brightness == Brightness.dark)
        ? AppTokens.darkBackground
        : AppTokens.lightBackground,
    fontFamily: 'Inter',
    cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusValue)))),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusValue))),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radiusValue))),
        foregroundColor: cs.primary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(radiusValue))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );
}