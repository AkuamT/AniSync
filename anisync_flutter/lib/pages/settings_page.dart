import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../providers/anime_provider.dart';
import '../providers/theme_provider.dart';

/// 设置页面
///
/// - 外观模式选择（跟随系统 / 白天 ☀️ / 暗夜 🌙）
/// - 二次元主题色选择（初音绿 / 猛男粉 / 初号机 / 赛博黄）
/// - 数据导出 / 导入（多端同步）
/// - 保持全局毛玻璃质感与圆角设计
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  Map<String, dynamic>? _importResult;

  // ============ 导出 ============

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      // 1. 从 API 获取所有数据（使用 AnimeProvider 已有的 list）
      final api = ApiClient();
      final exportData = await api.exportAnime();
      final animeList = exportData['anime_list'] as List;

      // 2. 序列化为 JSON 字符串
      const encoder = JsonEncoder.withIndent('  ');
      final jsonStr = encoder.convert(exportData);

      // 3. 选择保存路径（桌面端可用 saveFile，否则 fallback 到文档目录）
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:-]'), '')
          .split('.')
          .first;
      final fileName = 'anisync-backup-$timestamp.json';

      // 尝试使用 FilePicker 保存文件（桌面端支持）
      String? savedPath;
      try {
        savedPath = await FilePicker.platform.saveFile(
          dialogTitle: '保存备份文件',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: Uint8List.fromList(utf8.encode(jsonStr)),
        );
      } catch (_) {
        // FilePicker.saveFile 可能在某些平台不支持，fallback
      }

      if (savedPath != null) {
        // 使用 FilePicker 保存成功
        await File(savedPath).writeAsString(jsonStr);
      } else {
        // fallback：保存到文档目录
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(jsonStr);
        savedPath = file.path;
      }

      if (mounted) {
        Fluttertoast.showToast(
          msg: '导出成功！共 ${animeList.length} 部番剧\n$savedPath',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.green.shade700,
          textColor: Colors.white,
          fontSize: 14,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: '导出失败：${e.toString()}',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red.shade700,
          textColor: Colors.white,
          fontSize: 14,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ============ 导入 ============

  Future<void> _handleImport() async {
    // 选择文件
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: '选择备份文件',
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _isImporting = true;
      _importResult = null;
    });

    try {
      // 1. 读取文件内容
      final file = result.files.single;
      String jsonStr;
      if (file.bytes != null) {
        jsonStr = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonStr = await File(file.path!).readAsString();
      } else {
        throw Exception('无法读取文件内容');
      }

      // 2. 解析 JSON
      final dynamic parsed = jsonDecode(jsonStr);
      List<dynamic> animeList;

      if (parsed is Map<String, dynamic> && parsed.containsKey('anime_list')) {
        // 新版带 metadata 的格式
        animeList = parsed['anime_list'] as List<dynamic>;
      } else if (parsed is List) {
        // 旧版纯数组格式
        animeList = parsed;
      } else {
        throw Exception('文件格式错误：未找到番剧数据');
      }

      if (animeList.isEmpty) {
        throw Exception('备份文件中没有番剧数据');
      }

      // 3. 发送到后端导入
      final api = ApiClient();
      final importResult = await api.importAnime(
        animeList.cast<Map<String, dynamic>>(),
      );

      if (mounted) {
        setState(() => _importResult = importResult);
        final imported = importResult['imported'] ?? 0;
        final updated = importResult['updated'] ?? 0;
        final errors = importResult['errors'] as List? ?? [];
        Fluttertoast.showToast(
          msg: errors.isNotEmpty
              ? '导入完成：新增 $imported，更新 $updated，跳过 ${errors.length}'
              : '导入成功：新增 $imported 部，更新 $updated 部',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.green.shade700,
          textColor: Colors.white,
          fontSize: 14,
        );
        // 刷新列表
        if (context.mounted) {
          context.read<AnimeProvider>().loadList();
        }
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: '导入失败：${e.toString()}',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red.shade700,
          textColor: Colors.white,
          fontSize: 14,
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

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
                _buildSectionTitle(context, '数据同步'),
                const SizedBox(height: 12),
                _buildSyncSection(context),
                const SizedBox(height: 32),
                _buildSectionTitle(context, '关于'),
                const SizedBox(height: 12),
                _buildAboutCard(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 数据同步
  // ═══════════════════════════════════════════════════════════

  Widget _buildSyncSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
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
            children: [
              // ── 导出 ──
              _SyncActionCard(
                icon: Icons.file_upload_outlined,
                iconColor: scheme.primary,
                iconBgColor: scheme.primary.withOpacity(0.15),
                title: '导出数据',
                subtitle: '将全部追番记录导出为 JSON 备份文件',
                buttonText: _isExporting ? '导出中...' : '导出',
                isLoading: _isExporting,
                onTap: _isExporting ? null : _handleExport,
              ),
              const SizedBox(height: 12),
              // ── 导入 ──
              _SyncActionCard(
                icon: Icons.file_download_outlined,
                iconColor: Colors.green.shade400,
                iconBgColor: Colors.green.withOpacity(0.15),
                title: '导入数据',
                subtitle: '从 JSON 备份文件恢复追番记录',
                buttonText: _isImporting ? '导入中...' : '导入',
                isLoading: _isImporting,
                onTap: _isImporting ? null : _handleImport,
              ),
              // ── 导入结果 ──
              if (_importResult != null) ...[
                const SizedBox(height: 12),
                _buildImportResult(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportResult(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imported = _importResult!['imported'] as int? ?? 0;
    final updated = _importResult!['updated'] as int? ?? 0;
    final errors = _importResult!['errors'] as List? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          const Text(
            '导入结果',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatColumn('新增', imported.toString(), Colors.green),
              const SizedBox(width: 32),
              _buildStatColumn('更新', updated.toString(), scheme.primary),
              if (errors.isNotEmpty) ...[
                const SizedBox(width: 32),
                _buildStatColumn('错误', errors.length.toString(), Colors.red),
              ],
            ],
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...errors.take(3).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    e.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _importResult = null),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════

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
// 同步操作卡片
// ═══════════════════════════════════════════════════════════

class _SyncActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String buttonText;
  final bool isLoading;
  final VoidCallback? onTap;

  const _SyncActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.15)
            : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // 图标
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          // 文字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 按钮
          if (isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          else
            Material(
              color: scheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: scheme.primary.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
