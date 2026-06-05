import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════
// 二次元主题配色预设
// ═══════════════════════════════════════════════════════════

/// 可选主题色枚举
enum AppTheme {
  miku, // 初音绿
  sakura, // 猛男粉
  eva, // 初号机紫
  cyberpunk, // 赛博黄
  uzumaki, // 元气橙
}

/// 主题配色数据包
///
/// 每套配色包含主色、副色、渐变等完整视觉参数，
/// 确保「毛玻璃」效果在任何主题下都优雅。
class ThemePreset {
  final String name;
  final String description;

  /// 主色（按钮、指示器、高亮）
  final Color primary;

  /// 主色上的文字/图标颜色（自动适配对比度）
  final Color onPrimary;

  /// 副色（点缀、成功状态）
  final Color secondary;

  /// 危险/错误色
  final Color danger;

  // ── 深色模式渐变 ──
  final List<Color> darkGradient;
  final List<double> darkGradientStops;

  // ── 浅色模式渐变 ──
  final List<Color> lightGradient;
  final List<double> lightGradientStops;

  const ThemePreset({
    required this.name,
    required this.description,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    this.danger = const Color(0xFFFF3B30),
    required this.darkGradient,
    this.darkGradientStops = const [0.0, 0.35, 0.7, 1.0],
    required this.lightGradient,
    this.lightGradientStops = const [0.0, 0.35, 0.7, 1.0],
  });
}

/// 预设配色表
///
/// 初音绿 / 猛男粉 / 初号机 / 赛博黄
final Map<AppTheme, ThemePreset> themePresets = {
  AppTheme.miku: const ThemePreset(
    name: '初音绿',
    description: 'Miku Teal',
    primary: Color(0xFF39C5BB),
    onPrimary: Colors.white,
    secondary: Color(0xFF86CECB),
    darkGradient: [
      Color(0xFF0A1A1A),
      Color(0xFF0A0A14),
      Color(0xFF0F1E1E),
      Color(0xFF0A1A1A),
    ],
    lightGradient: [
      Color(0xFFE6FAF5),
      Color(0xFFE6F0FA),
      Color(0xFFF5FAE6),
      Color(0xFFE6FAF5),
    ],
  ),
  AppTheme.sakura: const ThemePreset(
    name: '猛男粉',
    description: 'Sakura Pink',
    primary: Color(0xFFFFB6C1),
    onPrimary: Color(0xFF4A1A2E),
    secondary: Color(0xFFFF69B4),
    darkGradient: [
      Color(0xFF1A0A0F),
      Color(0xFF140A0A),
      Color(0xFF1A0F14),
      Color(0xFF1A0A0F),
    ],
    lightGradient: [
      Color(0xFFFAE6F0),
      Color(0xFFFAE6E6),
      Color(0xFFF5E6FA),
      Color(0xFFFAE6F0),
    ],
  ),
  AppTheme.eva: const ThemePreset(
    name: '初号机',
    description: 'EVA Purple',
    primary: Color(0xFF7A5DC7),
    onPrimary: Colors.white,
    secondary: Color(0xFF39FF14),
    darkGradient: [
      Color(0xFF1A0A2E),
      Color(0xFF0A0A14),
      Color(0xFF140A1A),
      Color(0xFF1A0A2E),
    ],
    lightGradient: [
      Color(0xFFF0E6FA),
      Color(0xFFE6E6FA),
      Color(0xFFFAE6F0),
      Color(0xFFF0E6FA),
    ],
  ),
  AppTheme.cyberpunk: const ThemePreset(
    name: '赛博黄',
    description: 'Cyberpunk',
    primary: Color(0xFFFCEE0A),
    onPrimary: Color(0xFF141400),
    secondary: Color(0xFFFF00FF),
    darkGradient: [
      Color(0xFF0A0A0A),
      Color(0xFF14120A),
      Color(0xFF0A0A12),
      Color(0xFF0A0A0A),
    ],
    lightGradient: [
      Color(0xFFFAFAE6),
      Color(0xFFF0F0E6),
      Color(0xFFFAF5E6),
      Color(0xFFFAFAE6),
    ],
  ),
  AppTheme.uzumaki: const ThemePreset(
    name: '元气橙',
    description: 'Uzumaki Orange',
    primary: Color(0xFFFF8C00),
    onPrimary: Color(0xFF2A1000),
    secondary: Color(0xFFFF6B35),
    darkGradient: [
      Color(0xFF1A0A00),
      Color(0xFF0F0A05),
      Color(0xFF1A1200),
      Color(0xFF1A0A00),
    ],
    lightGradient: [
      Color(0xFFFAF0E6),
      Color(0xFFFAE6D5),
      Color(0xFFFAF0D5),
      Color(0xFFFAF0E6),
    ],
  ),
};

// ═══════════════════════════════════════════════════════════
// 主题状态管理
// ═══════════════════════════════════════════════════════════

/// 全局主题控制器
///
/// 管理两项持久化状态：
/// 1. [themeMode] — system / light / dark
/// 2. [themeColor] — miku / sakura / eva / cyberpunk
///
/// 使用 SharedPreferences 保存，应用重启后自动恢复。
class ThemeProvider extends ChangeNotifier {
  static const _themeModeKey = 'app_theme_mode';
  static const _themeColorKey = 'app_theme_color';

  ThemeMode _themeMode = ThemeMode.system;
  AppTheme _themeColor = AppTheme.miku;

  ThemeMode get themeMode => _themeMode;
  AppTheme get themeColor => _themeColor;

  /// 当前选中的配色预设
  ThemePreset get preset => themePresets[_themeColor]!;

  bool get isSystem => _themeMode == ThemeMode.system;
  bool get isLight => _themeMode == ThemeMode.light;
  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadFromPrefs();
  }

  /// 从本地存储读取主题偏好
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final savedMode = prefs.getString(_themeModeKey);
    if (savedMode != null) {
      try {
        _themeMode = ThemeMode.values.byName(savedMode);
      } catch (_) {
        _themeMode = ThemeMode.system;
      }
    }

    final savedColor = prefs.getString(_themeColorKey);
    if (savedColor != null) {
      try {
        _themeColor = AppTheme.values.byName(savedColor);
      } catch (_) {
        _themeColor = AppTheme.miku;
      }
    }

    notifyListeners();
  }

  /// 切换外观模式（system / light / dark）
  Future<void> setMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  /// 切换主题配色（miku / sakura / eva / cyberpunk）
  Future<void> setThemeColor(AppTheme theme) async {
    if (_themeColor == theme) return;
    _themeColor = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeColorKey, theme.name);
  }

  /// 快捷切换：light ↔ dark（跳过 system）
  Future<void> toggle() async {
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }
}
