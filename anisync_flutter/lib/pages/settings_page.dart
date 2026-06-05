import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// 设置页面
///
/// - 外观模式选择（跟随系统 / 白天 ☀️ / 暗夜 🌙）
/// - 二次元主题色选择（初音绿 / 猛男粉 / 初号机 / 赛博黄）
/// - 保持全局毛玻璃质感与圆角设计
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preset = context.watch<ThemeProvider>().preset;

    return Stack(
      children: [
        // ── 全屏渐变背景 ──
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: _buildGradient(preset, isDark),
            ),
          ),
        ),
        // ── 遮罩 ──
        Positioned.fill(
          child: Container(
            color: isDark
                ? Colors.black.withOpacity(0.15)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        // ── 主内容 ──
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('设置'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(context, '外观模式'),
                const SizedBox(height: 12),
                const _ThemeModeSelector(),
                const SizedBox(height: 32),
                _buildSectionTitle(context, '主题色调'),
                const SizedBox(height: 12),
                const _ThemeColorSelector(),
                const SizedBox(height: 32),
                _buildSectionTitle(context, '关于'),
                const SizedBox(height: 12),
                _buildAboutCard(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  LinearGradient _buildGradient(ThemePreset preset, bool isDark) {
    if (isDark) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: preset.darkGradient,
        stops: preset.darkGradientStops,
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: preset.lightGradient,
      stops: preset.lightGradientStops,
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: scheme.primary,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.5),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    color: scheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AniSync',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '二次元追番管理工具',
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.outline.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 外观模式选择器
// ═══════════════════════════════════════════════════════════

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final modes = [
      _ModeData(ThemeMode.system, '跟随系统', Icons.brightness_auto_rounded),
      _ModeData(ThemeMode.light, '白天模式 ☀️', Icons.wb_sunny_rounded),
      _ModeData(ThemeMode.dark, '暗夜模式 🌙', Icons.nightlight_rounded),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.5),
              width: 0.5,
            ),
          ),
          child: Column(
            children: modes.map((mode) {
              final isSelected = themeProvider.themeMode == mode.mode;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => themeProvider.setMode(mode.mode),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(color: scheme.primary, width: 1.5)
                            : Border.all(color: Colors.transparent),
                        color: isSelected
                            ? scheme.primary.withOpacity(0.08)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            mode.icon,
                            size: 22,
                            color:
                                isSelected ? scheme.primary : scheme.outline,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              mode.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? scheme.primary
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                          AnimatedScale(
                            scale: isSelected ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: 22,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ModeData {
  final ThemeMode mode;
  final String label;
  final IconData icon;

  const _ModeData(this.mode, this.label, this.icon);
}

// ═══════════════════════════════════════════════════════════
// 主题色调选择器
// ═══════════════════════════════════════════════════════════

class _ThemeColorSelector extends StatelessWidget {
  const _ThemeColorSelector();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 140,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.5),
              width: 0.5,
            ),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: AppTheme.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final appTheme = AppTheme.values[index];
              final preset = themePresets[appTheme]!;
              final isSelected = themeProvider.themeColor == appTheme;

              return _ColorSwatch(
                preset: preset,
                isSelected: isSelected,
                onTap: () => themeProvider.setThemeColor(appTheme),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 单个二次元色块
///
/// - 选中时放大 + 外发光 + 白色粗边框 + 勾选角标
/// - 未选中时缩小 + 细白边
class _ColorSwatch extends StatelessWidget {
  final ThemePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: isSelected ? 100 : 84,
        height: isSelected ? 120 : 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [preset.primary, preset.secondary],
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: preset.primary.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
          ],
          border: isSelected
              ? Border.all(color: Colors.white, width: 3)
              : Border.all(
                  color: Colors.white.withOpacity(0.3), width: 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 名称
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  preset.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preset.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // 选中角标
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: preset.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
