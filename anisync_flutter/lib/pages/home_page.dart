import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/anime.dart';
import '../providers/anime_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/anime_card.dart';
import 'search_page.dart';

/// 主页面 - 追番列表（二次元沉浸风格）
///
/// 架构说明：
/// - 全局渐变背景 + 暗色遮罩 + 毛玻璃卡片
/// - 颜文字空状态与错误兜底
/// - TabBar 使用 BackdropFilter 毛玻璃效果
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    Tab(text: '在看'),
    Tab(text: '想看'),
    Tab(text: '已看完'),
  ];

  static const _statuses = ['watching', 'plan', 'completed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnimeProvider>().loadList();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openSearch(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SearchAnimePage(),
    );
    if (result == 'plan' && mounted) {
      _tabController.animateTo(1);
    }
  }

  /// 二次元风格背景渐变
  LinearGradient _buildGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1A0A2E), // 深紫
          Color(0xFF0A0A14), // 近黑
          Color(0xFF0F1A2E), // 深蓝
          Color(0xFF1A0A2E), // 深紫
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF5E6FA), // 淡紫
        Color(0xFFE6F0FA), // 淡蓝
        Color(0xFFFAE6F0), // 淡粉
        Color(0xFFF5E6FA), // 淡紫
      ],
      stops: [0.0, 0.35, 0.7, 1.0],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // ── 全屏渐变背景 ──
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(gradient: _buildGradient(context)),
          ),
        ),
        // ── 暗色遮罩（保证文字可读性）──
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
            title: const Text('AniSync'),
            actions: const [
              _ThemeToggleButton(),
              SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.white.withOpacity(0.5),
                          width: 0.5,
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        tabs: _tabs,
                        labelStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        indicatorSize: TabBarIndicatorSize.label,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: _statuses
                .map((status) => _AnimeGridPage(status: status))
                .toList(),
          ),
          floatingActionButton: _GlowingFAB(
            onPressed: () => _openSearch(context),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 发光 FAB（二次元风格）
// ═══════════════════════════════════════════════════════════

class _GlowingFAB extends StatelessWidget {
  final VoidCallback onPressed;

  const _GlowingFAB({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.35),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: scheme.primary.withOpacity(0.15),
            blurRadius: 32,
            spreadRadius: 6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加番剧'),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 主题切换按钮（带动画）
// ═══════════════════════════════════════════════════════════

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        final isDark = theme.isDark;
        final icon = isDark ? Icons.wb_sunny_rounded : Icons.nightlight_rounded;
        final tooltip = isDark ? '切换至浅色模式' : '切换至深色模式';

        return GestureDetector(
          onLongPress: () => _showThemeMenu(context, theme),
          child: IconButton(
            tooltip: tooltip,
            onPressed: theme.toggle,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: Tween<double>(begin: 0.75, end: 1.0).animate(animation),
                  child: ScaleTransition(
                    scale: animation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  ),
                );
              },
              child: Icon(
                icon,
                key: ValueKey<bool>(isDark),
                size: 22,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showThemeMenu(BuildContext context, ThemeProvider theme) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final overlay = Navigator.of(context).overlay?.context.findRenderObject()
        as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlay),
        renderBox.localToGlobal(
          renderBox.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<ThemeMode>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        _themeMenuItem(context, theme, ThemeMode.system, '跟随系统',
            Icons.brightness_auto_rounded),
        _themeMenuItem(context, theme, ThemeMode.light, '浅色模式',
            Icons.wb_sunny_rounded),
        _themeMenuItem(context, theme, ThemeMode.dark, '深色模式',
            Icons.nightlight_rounded),
      ],
    );
  }

  PopupMenuItem<ThemeMode> _themeMenuItem(
    BuildContext context,
    ThemeProvider theme,
    ThemeMode mode,
    String label,
    IconData icon,
  ) {
    final isSelected = theme.themeMode == mode;
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuItem<ThemeMode>(
      value: mode,
      onTap: () => theme.setMode(mode),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? scheme.primary : scheme.onSurface,
            ),
          ),
          const Spacer(),
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: 18,
              color: scheme.primary,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 内部页面组件
// ═══════════════════════════════════════════════════════════

class _AnimeGridPage extends StatelessWidget {
  final String status;

  const _AnimeGridPage({required this.status});

  @override
  Widget build(BuildContext context) {
    return Consumer<AnimeProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.animeList.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = provider.filteredByStatus(status);

        if (list.isNotEmpty) {
          return RefreshIndicator(
            onRefresh: provider.loadList,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final isNarrow = w <= 500;
                final padding = isNarrow ? 10.0 : 16.0;
                final spacing = isNarrow ? 10.0 : 16.0;

                return GridView.builder(
                  padding: EdgeInsets.all(padding),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: _gridCellWidth(w),
                    childAspectRatio: isNarrow ? 0.56 : 0.55,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final anime = list[index];
                    return AnimeCard(
                      anime: anime,
                      compact: isNarrow,
                      onAddProgress: () =>
                          _handleAddProgress(context, provider, anime),
                      onDelete: () =>
                          _showDeleteConfirm(context, provider, anime),
                      onCardTap: () {
                        debugPrint('[AnimeCard] Tapped: ${anime.title}');
                      },
                    );
                  },
                );
              },
            ),
          );
        }

        final bool isError =
            provider.error != null && provider.animeList.isEmpty;
        return RefreshIndicator(
          onRefresh: provider.loadList,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: isError
                      ? _ErrorState(
                          message: provider.error!,
                          onRetry: provider.loadList,
                        )
                      : _EmptyState(status: status),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _gridCellWidth(double screenWidth) {
    if (screenWidth <= 500) return screenWidth / 2 - 8;
    if (screenWidth <= 700) return screenWidth / 3 - 12;
    if (screenWidth <= 1100) return screenWidth / 4 - 14;
    return screenWidth / 5 - 16;
  }

  Future<void> _handleAddProgress(
    BuildContext context,
    AnimeProvider provider,
    Anime anime,
  ) async {
    final success = await provider.plusOne(anime);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败: ${provider.error}')),
      );
    }
  }

  void _showDeleteConfirm(
    BuildContext context,
    AnimeProvider provider,
    Anime anime,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: isDark
            ? const Color(0xFF12121F).withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        title: const Text('确认删除'),
        content: Text('确定要删除「${anime.title}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await provider.deleteAnime(anime.id);
              if (context.mounted && !success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('删除失败: ${provider.error}')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 颜文字空状态与错误状态
// ═══════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final String status;

  const _EmptyState({required this.status});

  String get _kaomoji {
    switch (status) {
      case 'watching':
        return 'ヾ(≧▽≦*)o';
      case 'completed':
        return '(｡♥‿♥｡)';
      case 'plan':
      default:
        return '(ﾉ>ω<)ﾉ';
    }
  }

  String get _title {
    switch (status) {
      case 'watching':
        return '没有正在追的番';
      case 'completed':
        return '还没有看完的番';
      case 'plan':
      default:
        return '列表空空如也';
    }
  }

  String get _subtitle {
    switch (status) {
      case 'watching':
        return '快去添加一部新番开始追吧！';
      case 'completed':
        return '看完的番剧会出现在这里，加油追番吧！';
      case 'plan':
      default:
        return '快去捕捉新番吧！';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _kaomoji,
              style: TextStyle(
                fontSize: 48,
                color: scheme.primary.withOpacity(0.6),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _title,
              style: textTheme.titleMedium?.copyWith(
                color: scheme.onSurface.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.outline.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '(っ °Д °;)っ',
              style: TextStyle(
                fontSize: 48,
                color: scheme.error.withOpacity(0.6),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '呀！后端君失联了',
              style: textTheme.titleMedium?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '快去检查 Python 服务！\n$message',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.outline.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }
}
