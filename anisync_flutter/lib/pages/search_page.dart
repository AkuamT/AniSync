import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../models/search_result.dart';
import '../providers/anime_provider.dart';
import '../utils/debounce.dart';

/// 搜索并添加番剧页面
///
/// 设计策略：
/// - 桌面端（宽屏 >700px）：居中对话框形式，最大宽度 600，圆角 16
/// - 移动端（窄屏 ≤700px）：全屏形式，占据整个屏幕
///
/// 交互：
/// - 输入框防抖 500ms 自动搜索
/// - 一键清除输入
/// - 点击「添加」后调用 POST /api/anime，成功后返回 'plan' 信号
class SearchAnimePage extends StatefulWidget {
  const SearchAnimePage({super.key});

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
    // 监听输入变化以控制清除按钮显示
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    // 清空上次搜索结果
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

  /// 输入变化回调 —— 防抖搜索
  void _onSearchChanged(String value) {
    _debounce.run(() {
      if (mounted) {
        context.read<AnimeProvider>().searchBangumi(value);
      }
    });
  }

  /// 一键清除搜索
  void _clearSearch() {
    _searchController.clear();
    _debounce.cancel();
    context.read<AnimeProvider>().clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isDesktop
          ? const EdgeInsets.symmetric(horizontal: 80, vertical: 48)
          : EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 0),
        child: Container(
          width: isDesktop ? 600 : double.infinity,
          constraints: isDesktop
              ? const BoxConstraints(maxHeight: 700)
              : const BoxConstraints.expand(),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('搜索番剧'),
              leading: IconButton(
                icon: Icon(
                  isDesktop ? Icons.close_rounded : Icons.arrow_back_rounded,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              elevation: 0,
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
                      hintText: '输入番剧名称，如「进击的巨人」...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: _clearSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
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
    );
  }

  /// 构建搜索结果区域
  Widget _buildResultArea() {
    return Consumer<AnimeProvider>(
      builder: (context, provider, child) {
        // 初始空状态
        if (_searchController.text.trim().isEmpty) {
          return const _CenterMessage(
            icon: Icons.search_rounded,
            message: '输入关键词开始搜索',
          );
        }

        // 搜索中
        if (provider.isSearching) {
          return const Center(child: CircularProgressIndicator());
        }

        // 搜索出错
        if (provider.searchError != null) {
          return _CenterMessage(
            icon: Icons.error_outline_rounded,
            message: provider.searchError!,
            isError: true,
          );
        }

        // 无结果
        if (provider.searchResults.isEmpty) {
          return const _CenterMessage(
            icon: Icons.sentiment_dissatisfied_rounded,
            message: '未找到相关番剧',
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
  Future<void> _handleAdd(
    AnimeProvider provider,
    SearchResult result,
  ) async {
    if (_addingIds.contains(result.bangumiId)) return;

    setState(() => _addingIds.add(result.bangumiId));

    final success = await provider.addAnimeFromSearch(result);

    if (mounted) {
      setState(() => _addingIds.remove(result.bangumiId));
    }

    if (!mounted) return;

    if (success) {
      Fluttertoast.showToast(
        msg: '「${result.title}」已添加到想看',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: const Color(0xFF34C759),
        textColor: Colors.white,
        fontSize: 14,
      );
      // 返回 'plan' 信号，让主页切换到「想看」Tab
      Navigator.pop(context, 'plan');
    } else {
      Fluttertoast.showToast(
        msg: '添加失败: ${provider.error}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: const Color(0xFFFF3B30),
        textColor: Colors.white,
        fontSize: 14,
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 内部辅助组件
// ═══════════════════════════════════════════════════════════

/// 居中的消息提示（空状态 / 错误状态）
class _CenterMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isError;

  const _CenterMessage({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isError ? scheme.error : scheme.outline;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color.withOpacity(0.5)),
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
            borderRadius: BorderRadius.circular(6),
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
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.movie_outlined,
        size: 20,
        color: scheme.outline.withOpacity(0.4),
      ),
    );
  }
}
