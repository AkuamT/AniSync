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

  /// ═══════════════════════════════════════════════════════════
  /// 二次元 (ACG) 主题色板 —— 亮紫 × 初音绿
  /// ═══════════════════════════════════════════════════════════
  static const Color _primary = Color(0xFFE040FB);      // 亮紫（主色）
  static const Color _secondary = Color(0xFF39C5BB);    // 初音绿
  static const Color _danger = Color(0xFFFF3B30);
  static const Color _success = Color(0xFF39C5BB);

  static const Color _darkBg = Color(0xFF0A0A14);       // 深蓝黑背景
  static const Color _darkSurface = Color(0xFF12121F);  // 卡片底色（毛玻璃下可见）
  static const Color _darkTextPrimary = Color(0xFFF0F0F5);
  static const Color _darkTextSecondary = Color(0xFF9CA3AF);
  static const Color _darkBorder = Color(0xFF2A2A3E);

  static const Color _lightBg = Color(0xFFF5F0FA);      // 淡紫灰背景
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightTextPrimary = Color(0xFF1A1A2E);
  static const Color _lightTextSecondary = Color(0xFF6B7280);
  static const Color _lightBorder = Color(0xFFE5E0EB);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AnimeProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, child) {
          return MaterialApp(
            title: 'AniSync',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: theme.themeMode,
            home: const HomePage(),
          );
        },
      ),
    );
  }

  // ── 暗黑主题 ──
  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _darkBg,
      colorScheme: const ColorScheme.dark(
        primary: _primary,
        onPrimary: Colors.white,
        secondary: _secondary,
        surface: _darkSurface,
        error: _danger,
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
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(_primary.withOpacity(0.2)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        filled: true,
        fillColor: _darkSurface.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: _darkTextPrimary,
        unselectedLabelColor: _darkTextSecondary,
        indicatorColor: _primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        extendedPadding: EdgeInsets.symmetric(horizontal: 20),
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 1,
      ),
    );
  }

  // ── 亮色主题 ──
  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _lightBg,
      colorScheme: const ColorScheme.light(
        primary: _primary,
        onPrimary: Colors.white,
        secondary: _secondary,
        surface: _lightSurface,
        error: _danger,
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
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(_primary.withOpacity(0.2)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        filled: true,
        fillColor: _lightSurface.withOpacity(0.8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: _lightTextPrimary,
        unselectedLabelColor: _lightTextSecondary,
        indicatorColor: _primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        extendedPadding: EdgeInsets.symmetric(horizontal: 20),
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: _lightBorder,
        thickness: 1,
      ),
    );
  }
}
