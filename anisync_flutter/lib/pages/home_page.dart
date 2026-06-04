import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/anime.dart';
import '../providers/anime_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/anime_card.dart';
import 'search_page.dart';

/// 主页面 - 追番列表
///
/// 架构说明：
/// - 顶层容器负责 Tab 切换、响应式布局、空状态处理
/// - 底层 AnimeCard 纯展示，所有业务操作通过 Provider 回调完成
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
    // 首次加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnimeProvider>().loadList();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 打开搜索页面，接收返回的状态信号以自动切换 Tab
  Future<void> _openSearch(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SearchAnimePage(),
    );

    // 添加成功返回 'plan'，自动切换到「想看」Tab
    if (result == 'plan' && mounted) {
      _tabController.animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AniSync'),
        actions: const [
          _ThemeToggleButton(),
          SizedBox(width: 4),
        ],
        bottom: TabBar(
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
          labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statuses
            .map((status) => _AnimeGridPage(status: status))
            .toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSearch(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加番剧'),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 主题切换按钮（带动画）
// ═══════════════════════════════════════════════════════════

/// 主题切换按钮
///
/// - 短按：light ↔ dark 快捷切换
/// - 长按：弹出菜单，可选择 system / light / dark
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        _themeMenuItem(context, theme, ThemeMode.system, '跟随系统', Icons.brightness_auto_rounded),
        _themeMenuItem(context, theme, ThemeMode.light, '浅色模式', Icons.wb_sunny_rounded),
        _themeMenuItem(context, theme, ThemeMode.dark, '深色模式', Icons.nightlight_rounded),
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

/// 某一状态分类下的番剧网格页
class _AnimeGridPage extends StatelessWidget {
  final String status;

  const _AnimeGridPage({required this.status});

  @override
  Widget build(BuildContext context) {
    return Consumer<AnimeProvider>(
      builder: (context, provider, child) {
        // 首次加载中（无数据时不支持下拉刷新，避免重复加载指示器）
        if (provider.isLoading && provider.animeList.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = provider.filteredByStatus(status);

        // 有列表数据：GridView + 下拉刷新
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
                      onAddProgress: () => _handleAddProgress(context, provider, anime),
                      onDelete: () => _showDeleteConfirm(context, provider, anime),
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

        // 空状态 / 错误状态：使用可滚动容器，支持下拉刷新
        final bool isError = provider.error != null && provider.animeList.isEmpty;
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

  /// 根据屏幕宽度计算网格单元最大宽度，实现响应式列数
  double _gridCellWidth(double screenWidth) {
    // 手机竖屏 (≤500): 2列
    if (screenWidth <= 500) return screenWidth / 2 - 8;
    // 小平板/手机横屏 (≤700): 3列
    if (screenWidth <= 700) return screenWidth / 3 - 12;
    // 平板/桌面小窗口 (≤1100): 4列
    if (screenWidth <= 1100) return screenWidth / 4 - 14;
    // 桌面宽屏: 5列
    return screenWidth / 5 - 16;
  }

  /// +1 进度处理
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

  /// 删除确认对话框
  void _showDeleteConfirm(
    BuildContext context,
    AnimeProvider provider,
    Anime anime,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
// 空状态与错误状态
// ═══════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final String status;

  const _EmptyState({required this.status});

  String get _title {
    switch (status) {
      case 'watching':
        return '暂无在看的番剧';
      case 'completed':
        return '暂无已看完的番剧';
      case 'plan':
      default:
        return '暂无想看的番剧';
    }
  }

  String get _subtitle {
    switch (status) {
      case 'watching':
        return '开始追一部新番吧！点击右下角按钮添加。';
      case 'completed':
        return '看完的番剧会出现在这里。';
      case 'plan':
      default:
        return '把想看的番剧加入清单，不再错过佳作。';
    }
  }

  IconData get _icon {
    switch (status) {
      case 'watching':
        return Icons.play_circle_outline_rounded;
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'plan':
      default:
        return Icons.bookmark_border_rounded;
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
            Icon(
              _icon,
              size: 64,
              color: scheme.outline.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _title,
              style: textTheme.titleMedium?.copyWith(
                color: scheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.outline.withOpacity(0.7),
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
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: scheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: textTheme.titleMedium?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
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
