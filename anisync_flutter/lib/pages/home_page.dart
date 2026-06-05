import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/anime.dart';
import '../providers/anime_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/anime_card.dart';
import 'search_page.dart';
import 'settings_page.dart';

// ═══════════════════════════════════════════════════════════════════
//  数据定义
// ═══════════════════════════════════════════════════════════════════

class _TabData {
  final String label;
  final String status;

  const _TabData({required this.label, required this.status});
}

// ═══════════════════════════════════════════════════════════════════
//  主页面 — 二次元沉浸风格重构版
// ═══════════════════════════════════════════════════════════════════

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PageController _pageController;
  int _currentIndex = 0;
  int _animationTrigger = 0;

  static const _tabs = [
    _TabData(label: '在看', status: 'watching'),
    _TabData(label: '想看', status: 'plan'),
    _TabData(label: '已看完', status: 'completed'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnimeProvider>().loadList();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
    setState(() => _currentIndex = index);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _animationTrigger++;
    });
  }

  Future<void> _openSearch(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SearchAnimePage(),
    );
    if (result == 'plan' && mounted) {
      _onTabTap(1);
    }
  }

  LinearGradient _buildGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preset = context.read<ThemeProvider>().preset;

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
          body: SafeArea(
            child: Column(
              children: [
                // 顶部栏：标题 + 胶囊 Tab
                _TopBar(
                  currentIndex: _currentIndex,
                  tabs: _tabs,
                  onTabTap: _onTabTap,
                ),
                // 页面内容
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _tabs.length,
                    itemBuilder: (context, index) => _AnimeListPage(
                      status: _tabs[index].status,
                      showHero: index == 0,
                      animationTrigger: _animationTrigger,
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: _GlowingFAB(
            onPressed: () => _openSearch(context),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  顶部栏
// ═══════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  final int currentIndex;
  final List<_TabData> tabs;
  final ValueChanged<int> onTabTap;

  const _TopBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTabTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          // 标题行
          Row(
            children: [
              Text(
                'AniSync',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
              const Spacer(),
              const _SettingsButton(),
            ],
          ),
          const SizedBox(height: 12),
          // 胶囊 Tab 栏
          _CapsuleTabBar(
            selectedIndex: currentIndex,
            tabs: tabs,
            onTap: onTabTap,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  悬浮胶囊 Tab 栏 — 带动画指示器与计数徽章
// ═══════════════════════════════════════════════════════════════════

class _CapsuleTabBar extends StatelessWidget {
  final int selectedIndex;
  final List<_TabData> tabs;
  final ValueChanged<int> onTap;

  const _CapsuleTabBar({
    required this.selectedIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.5),
              width: 0.5,
            ),
          ),
          child: Consumer<AnimeProvider>(
            builder: (context, provider, child) {
              final counts = provider.tabCounts;
              return Row(
                children: tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tab = entry.value;
                  final isSelected = index == selectedIndex;
                  final count = counts[tab.status] ?? 0;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scheme.primary.withOpacity(0.9)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tab.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? scheme.onPrimary
                                      : scheme.onSurface.withOpacity(0.7),
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? scheme.onPrimary.withOpacity(0.2)
                                        : scheme.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      color: isSelected
                                          ? scheme.onPrimary
                                          : scheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  设置按钮
// ═══════════════════════════════════════════════════════════════════

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '设置',
      icon: const Icon(Icons.settings_rounded, size: 22),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  番剧列表页面 — CustomScrollView + 错层布局 + 交错动画
// ═══════════════════════════════════════════════════════════════════

class _AnimeListPage extends StatefulWidget {
  final String status;
  final bool showHero;
  final int animationTrigger;

  const _AnimeListPage({
    required this.status,
    this.showHero = false,
    this.animationTrigger = 0,
  });

  @override
  State<_AnimeListPage> createState() => _AnimeListPageState();
}

class _AnimeListPageState extends State<_AnimeListPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Anime? _getHeroAnime(List<Anime> list) {
    if (list.isEmpty) return null;
    return list.reduce((a, b) {
      final aProgress =
          a.totalEpisodes > 0 ? a.currentEpisode / a.totalEpisodes : 0.0;
      final bProgress =
          b.totalEpisodes > 0 ? b.currentEpisode / b.totalEpisodes : 0.0;
      return aProgress > bProgress ? a : b;
    });
  }

  int _itemsPerRow(double width) {
    if (width <= 500) return 2;
    if (width <= 900) return 3;
    return 4;
  }

  Offset _staggerOffset(int itemsPerRow, int columnIndex, bool isNarrow) {
    final offset = isNarrow ? 16.0 : 20.0;
    if (itemsPerRow == 2) {
      return columnIndex == 1 ? Offset(0, offset) : Offset.zero;
    }
    if (itemsPerRow == 3) {
      return columnIndex == 1 ? Offset(0, -offset * 0.6) : Offset.zero;
    }
    return columnIndex % 2 == 1 ? Offset(0, offset) : Offset.zero;
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
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: scheme.surface.withOpacity(0.95),
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
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<AnimeProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.animeList.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = provider.filteredByStatus(widget.status);

        if (list.isEmpty) {
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
                        : _EmptyState(status: widget.status),
                  ),
                ),
              ),
            ),
          );
        }

        final heroAnime = widget.showHero ? _getHeroAnime(list) : null;
        final gridList = heroAnime != null
            ? list.where((a) => a.id != heroAnime.id).toList()
            : list;

        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final isNarrow = w <= 500;
            final padding = isNarrow ? 12.0 : 16.0;
            final spacing = isNarrow ? 10.0 : 14.0;
            final itemsPerRow = _itemsPerRow(w);

            return RefreshIndicator(
              onRefresh: provider.loadList,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Hero Section ──
                  if (heroAnime != null) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            EdgeInsets.fromLTRB(padding, 4, padding, spacing),
                        child: _HeroSection(
                          anime: heroAnime,
                          onAddProgress: () => _handleAddProgress(
                              context, provider, heroAnime),
                        ),
                      ),
                    ),
                  ],
                  // ── 错层瀑布流列表 ──
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, rowIndex) {
                          final startIndex = rowIndex * itemsPerRow;
                          final endIndex =
                              (startIndex + itemsPerRow).clamp(0, gridList.length);
                          final rowItems =
                              gridList.sublist(startIndex, endIndex);

                          return Padding(
                            padding: EdgeInsets.only(bottom: spacing),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int i = 0; i < rowItems.length; i++) ...[
                                  if (i > 0) SizedBox(width: spacing),
                                  Expanded(
                                    child: _StaggeredItem(
                                      index: startIndex + i,
                                      trigger: widget.animationTrigger,
                                      child: Transform.translate(
                                        offset: _staggerOffset(
                                            itemsPerRow, i, isNarrow),
                                        child: AspectRatio(
                                          aspectRatio: isNarrow ? 0.58 : 0.62,
                                          child: AnimeCard(
                                            anime: rowItems[i],
                                            compact: isNarrow,
                                            onAddProgress: () =>
                                                _handleAddProgress(context,
                                                    provider, rowItems[i]),
                                            onDelete: () =>
                                                _showDeleteConfirm(context,
                                                    provider, rowItems[i]),
                                            onCardTap: () {
                                              debugPrint(
                                                  '[AnimeCard] Tapped: ${rowItems[i].title}');
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                for (int i = rowItems.length;
                                    i < itemsPerRow;
                                    i++) ...[
                                  if (i > 0) SizedBox(width: spacing),
                                  const Expanded(child: SizedBox.shrink()),
                                ],
                              ],
                            ),
                          );
                        },
                        childCount:
                            (gridList.length + itemsPerRow - 1) ~/ itemsPerRow,
                      ),
                    ),
                  ),
                  // ── 底部留白（避免 FAB 遮挡）──
                  SliverToBoxAdapter(
                    child: SizedBox(height: isNarrow ? 80 : 100),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  交错动画 Item — 滑入 + 渐显
// ═══════════════════════════════════════════════════════════════════

class _StaggeredItem extends StatefulWidget {
  final int index;
  final int trigger;
  final Widget child;

  const _StaggeredItem({
    required this.index,
    required this.trigger,
    required this.child,
  });

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  void _initAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    Future.delayed(Duration(milliseconds: widget.index * 45), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(_StaggeredItem old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) {
      _controller.dispose();
      _initAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Hero Section — 大画幅焦点卡片
// ═══════════════════════════════════════════════════════════════════

class _HeroSection extends StatelessWidget {
  final Anime anime;
  final VoidCallback? onAddProgress;

  const _HeroSection({
    required this.anime,
    this.onAddProgress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFullyWatched = anime.totalEpisodes > 0 &&
        anime.currentEpisode >= anime.totalEpisodes;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 封面背景
            Image.network(
              anime.coverUrl ?? '',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade900,
              ),
            ),
            // 渐变遮罩
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // 内容
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 标签
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '正在追',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 标题
                  Text(
                    anime.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 进度行
                  Row(
                    children: [
                      Text(
                        '${anime.currentEpisode} / ${anime.totalEpisodes > 0 ? anime.totalEpisodes : '?'} 集',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: anime.totalEpisodes > 0
                                ? (anime.currentEpisode / anime.totalEpisodes)
                                    .clamp(0.0, 1.0)
                                : 0,
                            backgroundColor: Colors.white.withOpacity(0.15),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(scheme.primary),
                            minHeight: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // +1 按钮
                      _HeroAddButton(
                        isFullyWatched: isFullyWatched,
                        onTap: onAddProgress,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Hero +1 按钮 — 圆形带按压回弹
// ═══════════════════════════════════════════════════════════════════

class _HeroAddButton extends StatefulWidget {
  final bool isFullyWatched;
  final VoidCallback? onTap;
  final Color color;

  const _HeroAddButton({
    required this.isFullyWatched,
    this.onTap,
    required this.color,
  });

  @override
  State<_HeroAddButton> createState() => _HeroAddButtonState();
}

class _HeroAddButtonState extends State<_HeroAddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 - (_ctrl.value * 0.15),
            child: child,
          );
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isFullyWatched
                ? Colors.greenAccent.withOpacity(0.9)
                : widget.color,
            boxShadow: [
              BoxShadow(
                color: (widget.isFullyWatched
                        ? Colors.greenAccent
                        : widget.color)
                    .withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Icon(
            widget.isFullyWatched ? Icons.check_rounded : Icons.add_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  发光 FAB（二次元风格）
// ═══════════════════════════════════════════════════════════════════

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
        foregroundColor: scheme.onPrimary,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  颜文字空状态与错误状态
// ═══════════════════════════════════════════════════════════════════

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
                color: scheme.primary.withOpacity(0.75),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _title,
              style: textTheme.titleMedium?.copyWith(
                color: scheme.onSurface.withOpacity(0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.primary.withOpacity(0.55),
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
                color: scheme.error.withOpacity(0.7),
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
                color: scheme.primary.withOpacity(0.5),
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
