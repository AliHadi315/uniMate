import 'package:flutter/material.dart';

/// Central design tokens so light and dark mode stay in step.
class AppTheme {
  const AppTheme._();

  static const seed = Color(0xFF2563EB);

  static const high = Color(0xFFDC2626);
  static const medium = Color(0xFFF59E0B);
  static const low = Color(0xFF16A34A);

  /// Palette used to colour-code courses.
  static const coursePalette = <Color>[
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF0891B2),
    Color(0xFF65A30D),
    Color(0xFF9333EA),
  ];

  /// Resolves a stored colour value, falling back to a stable palette entry.
  static Color courseColor(int colorValue, {int seedIndex = 0}) {
    if (colorValue != 0) return Color(colorValue);
    return coursePalette[seedIndex.abs() % coursePalette.length];
  }

  static Color priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return high;
      case 'Low':
        return low;
      default:
        return medium;
    }
  }

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final scaffold = isDark ? const Color(0xFF0F1115) : const Color(0xFFF3F4F6);
    final surface = isDark ? const Color(0xFF181B22) : Colors.white;
    final field = isDark ? const Color(0xFF21252E) : const Color(0xFFF3F4F6);
    final outline = isDark ? const Color(0xFF2C313B) : const Color(0xFFE5E7EB);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: outline, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 66,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppSurfaces(tile: field, outline: outline, card: surface),
      ],
    );
  }
}

/// Extra surface colours the screens use for the soft "tile" look.
@immutable
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  final Color tile;
  final Color outline;
  final Color card;

  const AppSurfaces({
    required this.tile,
    required this.outline,
    required this.card,
  });

  static AppSurfaces of(BuildContext context) =>
      Theme.of(context).extension<AppSurfaces>() ??
      const AppSurfaces(
        tile: Color(0xFFF3F4F6),
        outline: Color(0xFFE5E7EB),
        card: Colors.white,
      );

  @override
  AppSurfaces copyWith({Color? tile, Color? outline, Color? card}) =>
      AppSurfaces(
        tile: tile ?? this.tile,
        outline: outline ?? this.outline,
        card: card ?? this.card,
      );

  @override
  AppSurfaces lerp(ThemeExtension<AppSurfaces>? other, double t) {
    if (other is! AppSurfaces) return this;
    return AppSurfaces(
      tile: Color.lerp(tile, other.tile, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      card: Color.lerp(card, other.card, t)!,
    );
  }
}
