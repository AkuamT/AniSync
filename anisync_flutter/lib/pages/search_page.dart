import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../models/search_result.dart';
import '../providers/anime_provider.dart';
import '../utils/debounce.dart';

/// 搜索并添加番剧页面（二次元风格）
///
/// 设计策略：
/// - 桌面端（宽屏 >700px）：居中对话框形式，最大宽度 600，圆角 24
/// - 移动端（窄屏 ≤700px）：全屏形式，占据整个屏幕
///
/// 交互：
/// - 输入框防抖 500ms 自动搜索
/// - 一键清除输入
/// - BUG 修复：根据 [defaultStatus] 参数动态传入添加状态，不再是硬编码 'plan'
/// - 添加成功后返回实际使用的 status 字符串，主页面据此跳转到对应 Tab
class SearchAnimePage extends StatefulWidget {
  /// 当前 Tab 对应的状态，用于添加番剧时动态指定 status
  final String defaultStatus;

  const SearchAnimePage({super.key, this.defaultStatus = 'plan'});

  @override
  State<SearchAnimePage> createState() => _SearchAnimePageState();
}

class _SearchAnimePageState extends State<SearchAnimePage> {
  final _searchController = TextEditingController();
  final _debounce = Debounce(delay: const Duration(milliseconds: 500));
  final _focusNode = FocusNode();

  /// 防止重复点击：记录正在添加中的 bangumiId
  final Set<int> _addingIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnimeProvider>().clearSearch();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce.run(() {
      if (mounted) {
        context.read<AnimeProvider>().searchBangumi(value);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce.cancel();
    context.read<AnimeProvider>().clearSearch();
  }

  /// 当前状态的 UI 标签
  String get _statusLabel {
    switch (widget.defaultStatus) {
      case 'watching':
        return '在看';
      case 'completed':
        return '已看完';
      case 'plan':
      default:
        return '想看';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isDesktop
          ? const EdgeInsets.symmetric(horizontal: 80, vertical: 48)
          : EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 0),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: isDesktop ? 16 : 0, sigmaY: isDesktop ? 16 : 0),
          child: Container(
            width: isDesktop ? 600 : double.infinity,
            constraints: isDesktop
                ? const BoxConstraints(maxHeight: 700)
                : const BoxConstraints.expand(),
            decoration: isDesktop
                ? BoxDecoration(
                    color: isDark
                        ? Theme.of(context)
                            .colorScheme
                            .surface
                            .withOpacity(0.92)
                        : Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.white.withOpacity(0.6),
                      width: 0.5,
                    ),
                  )
                : null,
            child: Scaffold(
              backgroundColor: isDesktop ? Colors.transparent : null,
              appBar: AppBar(
                title: const Text('搜索番剧'),
                leading: IconButton(
                  icon: Icon(
                    isDesktop ? Icons.close_rounded : Icons.arrow_back_rounded,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
              ),
              body: Column(
                children: [
                  // ── 搜索输入框 ──
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '输入番剧名，如「进击的巨人」... o(*≧▽≦)ツ',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: _clearSearch,
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),

                  // ── 分割线 ──
                  const Divider(height: 1),

                  // ── 结果列表 ──
                  Expanded(
                    child: _buildResultArea(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建搜索结果区域
  Widget _buildResultArea() {
    return Consumer<AnimeProvider>(
      builder: (context, provider, child) {
        // 初始空状态
        if (_searchController.text.trim().isEmpty) {
          return const _CenterMessage(
            kaomoji: '(｡･ω･｡)ﾉ',
            message: '输入关键词开始搜索吧~',
          );
        }

        // 搜索中
        if (provider.isSearching) {
          return const Center(child: CircularProgressIndicator());
        }

        // 搜索出错
        if (provider.searchError != null) {
          return _CenterMessage(
            kaomoji: '(；´Д｀)',
            message: provider.searchError!,
            isError: true,
          );
        }

        // 无结果
        if (provider.searchResults.isEmpty) {
          return const _CenterMessage(
            kaomoji: '( ´･ω･`)',
            message: '未找到相关番剧，换个关键词试试？',
          );
        }

        // 结果列表
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: provider.searchResults.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
          itemBuilder: (context, index) {
            final result = provider.searchResults[index];
            final isAdding = _addingIds.contains(result.bangumiId);
            return _SearchResultTile(
              result: result,
              isAdding: isAdding,
              onAdd: isAdding
                  ? null
                  : () => _handleAdd(provider, result),
            );
          },
        );
      },
    );
  }

  /// 处理添加操作：防重 + Loading + Toast + 返回信号
  /// BUG 修复：使用 [widget.defaultStatus] 动态传入状态
  Future<void> _handleAdd(
    AnimeProvider provider,
    SearchResult result,
  ) async {
    if (_addingIds.contains(result.bangumiId)) return;

    setState(() => _addingIds.add(result.bangumiId));

    final success = await provider.addAnimeFromSearch(
      result,
      status: widget.defaultStatus,
    );

    if (mounted) {
      setState(() => _addingIds.remove(result.bangumiId));
    }

    if (!mounted) return;

    final scheme = Theme.of(context).colorScheme;

    if (success) {
      Fluttertoast.showToast(
        msg: '「${result.title}」已添加到$_statusLabel',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: scheme.secondary,
        textColor: scheme.onPrimary,
        fontSize: 14,
      );
      // BUG 修复：返回实际使用的 status，主页面据此处理后续逻辑
      Navigator.pop(context, widget.defaultStatus);
    } else {
      Fluttertoast.showToast(
        msg: '添加失败: ${provider.error}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: scheme.error,
        textColor: Colors.white,
        fontSize: 14,
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 内部辅助组件
// ═══════════════════════════════════════════════════════════

/// 居中的消息提示（颜文字版）
class _CenterMessage extends StatelessWidget {
  final IconData? icon;
  final String? kaomoji;
  final String message;
  final bool isError;

  const _CenterMessage({
    this.icon,
    this.kaomoji,
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isError ? scheme.error : scheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (kaomoji != null)
              Text(
                kaomoji!,
                style: TextStyle(
                  fontSize: 40,
                  color: color.withOpacity(0.5),
                  height: 1.2,
                ),
              )
            else if (icon != null)
              Icon(icon!, size: 48, color: color.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 搜索结果列表项
class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback? onAdd;
  final bool isAdding;

  const _SearchResultTile({
    required this.result,
    this.onAdd,
    this.isAdding = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // ── 封面图 ──
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _CoverImage(coverUrl: result.coverUrl),
          ),
          const SizedBox(width: 12),

          // ── 信息区 ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _buildSubtitle(),
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.outline.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── 添加按钮 / Loading ──
          if (isAdding)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('添加'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                textStyle: const TextStyle(fontSize: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (result.airYear.isNotEmpty) {
      parts.add('${result.airYear}年');
    }
    if (result.totalEpisodes > 0) {
      parts.add('${result.totalEpisodes}集');
    }
    return parts.isEmpty ? '信息待补充' : parts.join(' · ');
  }
}

/// 搜索结果封面图（小尺寸 48×64）
class _CoverImage extends StatelessWidget {
  final String? coverUrl;

  const _CoverImage({this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (coverUrl == null || coverUrl!.isEmpty) {
      return _Placeholder(scheme: scheme);
    }

    return Image.network(
      coverUrl!,
      width: 48,
      height: 64,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 48,
          height: 64,
          color: scheme.outline.withOpacity(0.1),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _Placeholder(scheme: scheme),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final ColorScheme scheme;

  const _Placeholder({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        color: scheme.outline.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.movie_outlined,
        size: 20,
        color: scheme.outline.withOpacity(0.4),
      ),
    );
  }
}
