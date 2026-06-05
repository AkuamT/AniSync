import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/anime_provider.dart';
import 'providers/theme_provider.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const AniSyncApp());
}

class AniSyncApp extends StatelessWidget {
  const AniSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AnimeProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, child) {
          final preset = theme.preset;
          return MaterialApp(
            title: 'AniSync',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(preset),
            darkTheme: _buildDarkTheme(preset),
            themeMode: theme.themeMode,
            home: const HomePage(),
          );
        },
      ),
    );
  }

  // ── 中性色板（不随主题色变化）──
  static const Color _darkBg = Color(0xFF0A0A14);
  static const Color _darkSurface = Color(0xFF12121F);
  static const Color _darkTextPrimary = Color(0xFFF0F0F5);
  static const Color _darkTextSecondary = Color(0xFF9CA3AF);
  static const Color _darkBorder = Color(0xFF2A2A3E);

  static const Color _lightBg = Color(0xFFF5F0FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightTextPrimary = Color(0xFF1A1A2E);
  static const Color _lightTextSecondary = Color(0xFF6B7280);
  static const Color _lightBorder = Color(0xFFE5E0EB);

  // ── 暗黑主题 ──
  ThemeData _buildDarkTheme(ThemePreset preset) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _darkBg,
      colorScheme: ColorScheme.dark(
        primary: preset.primary,
        onPrimary: preset.onPrimary,
        secondary: preset.secondary,
        surface: _darkSurface,
        error: preset.danger,
        outline: _darkBorder,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: _darkTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
        titleMedium: TextStyle(
          color: _darkTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(color: _darkTextPrimary, fontSize: 14),
        bodySmall: TextStyle(color: _darkTextSecondary, fontSize: 12),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: _darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: _darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: _darkSurface.withOpacity(0.6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _darkBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: preset.primary,
          foregroundColor: preset.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(preset.primary.withOpacity(0.2)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: preset.primary, width: 2),
        ),
        filled: true,
        fillColor: _darkSurface.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _darkTextPrimary,
        unselectedLabelColor: _darkTextSecondary,
        indicatorColor: preset.primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: preset.primary,
        foregroundColor: preset.onPrimary,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 1,
      ),
    );
  }

  // ── 亮色主题 ──
  ThemeData _buildTheme(ThemePreset preset) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _lightBg,
      colorScheme: ColorScheme.light(
        primary: preset.primary,
        onPrimary: preset.onPrimary,
        secondary: preset.secondary,
        surface: _lightSurface,
        error: preset.danger,
        outline: _lightBorder,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: _lightTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
        titleMedium: TextStyle(
          color: _lightTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(color: _lightTextPrimary, fontSize: 14),
        bodySmall: TextStyle(color: _lightTextSecondary, fontSize: 12),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: _lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: _lightTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: _lightSurface.withOpacity(0.85),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _lightBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: preset.primary,
          foregroundColor: preset.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(preset.primary.withOpacity(0.2)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: preset.primary, width: 2),
        ),
        filled: true,
        fillColor: _lightSurface.withOpacity(0.8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _lightTextPrimary,
        unselectedLabelColor: _lightTextSecondary,
        indicatorColor: preset.primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: preset.primary,
        foregroundColor: preset.onPrimary,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: _lightBorder,
        thickness: 1,
      ),
    );
  }
}
