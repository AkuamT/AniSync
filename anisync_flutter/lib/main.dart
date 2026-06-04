import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/anime_provider.dart';
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
      ],
      child: MaterialApp(
        title: 'AniSync',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const HomePage(),
      ),
    );
  }

  ThemeData _buildTheme() {
    // Apple 风格设计令牌
    const accent = Color(0xFF0071E3);
    const danger = Color(0xFFFF3B30);
    const success = Color(0xFF34C759);
    const bg = Color(0xFFF5F5F7);
    const surface = Color(0xFFFFFFFF);
    const textPrimary = Color(0xFF1D1D1F);
    const textSecondary = Color(0xFF86868B);
    const border = Color(0xFFE5E5EA);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        secondary: success,
        surface: surface,
        error: danger,
        outline: border,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
