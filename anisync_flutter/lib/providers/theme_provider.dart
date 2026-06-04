import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式状态管理
///
/// 支持三种模式：system / light / dark
/// 使用 SharedPreferences 持久化用户选择
class ThemeProvider extends ChangeNotifier {
  static const _key = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isSystem => _themeMode == ThemeMode.system;
  bool get isLight => _themeMode == ThemeMode.light;
  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadFromPrefs();
  }

  /// 从本地存储读取主题偏好
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      _themeMode = ThemeMode.values.byName(saved);
      notifyListeners();
    }
  }

  /// 切换至指定模式
  Future<void> setMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// 快捷切换：light ↔ dark（跳过 system）
  Future<void> toggle() async {
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }
}
