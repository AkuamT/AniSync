import 'package:flutter/material.dart';
import '../models/anime.dart';

/// 番剧卡片 - 纯 UI 展示组件
///
/// 架构约束：
/// - 纯 StatelessWidget，不持有任何业务状态
/// - 不直接调用 API，不操作全局 Provider
/// - 所有交互通过构造函数注入的回调函数向外传递
class AnimeCard extends StatelessWidget {
  final Anime anime;
  final VoidCallback? onAddProgress;
  final VoidCallback? onDelete;
  final VoidCallback? onCardTap;

  const AnimeCard({
    super.key,
    required this.anime,
    this.onAddProgress,
    this.onDelete,
    this.onCardTap,
  });

  /// 根据状态返回主题色
  Color _statusColor(ColorScheme scheme) {
    switch (anime.status) {
      case 'watching':
        return scheme.primary;
      case 'completed':
        return scheme.secondary;
      case 'plan':
      default:
        return scheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final statusColor = _statusColor(scheme);

    final bool isFullyWatched =
        anime.totalEpisodes > 0 && anime.currentEpisode >= anime.totalEpisodes;

    return _HoverableCard(
      onTap: onCardTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 封面图（Expanded 自适应剩余高度）──
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                width: double.infinity,
                child: _CoverImage(coverUrl: anime.coverUrl),
              ),
            ),
          ),

          // ── 内容区（固定结构，不会溢出）──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Text(
                  anime.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 6),

                // 状态标签 + 进度文字
                Row(
                  children: [
                    _StatusBadge(
                      label: anime.statusLabel,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${anime.currentEpisode}/${anime.totalEpisodes > 0 ? anime.totalEpisodes : '?'}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // 进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: anime.totalEpisodes > 0
                        ? (anime.currentEpisode / anime.totalEpisodes)
                            .clamp(0.0, 1.0)
                        : 0,
                    backgroundColor: scheme.outline.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 10),

                // 操作按钮区
                Row(
                  children: [
                    // +1 / 已看完 按钮
                    Expanded(
                      child: isFullyWatched
                          ? _ActionButton(
                              icon: Icons.check_rounded,
                              label: '已看完',
                              onTap: null,
                              backgroundColor:
                                  scheme.secondary.withOpacity(0.1),
                              foregroundColor: scheme.secondary,
                            )
                          : _ActionButton(
                              icon: Icons.add_rounded,
                              label: '+1',
                              onTap: onAddProgress,
                              backgroundColor: scheme.primary,
                              foregroundColor: Colors.white,
                            ),
                    ),
                    const SizedBox(width: 8),
                    // 删除按钮
                    _ActionButton(
                      icon: Icons.delete_outline_rounded,
                      onTap: onDelete,
                      backgroundColor: scheme.error.withOpacity(0.1),
                      foregroundColor: scheme.error,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 内部辅助组件
// ═══════════════════════════════════════════════════════════

/// 带悬停动效的卡片包装器
///
/// 桌面端：鼠标悬停时阴影加深 + 轻微放大
class _HoverableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HoverableCard({required this.child, this.onTap});

  @override
  State<_HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<_HoverableCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _hovered
                    ? scheme.primary.withOpacity(0.3)
                    : scheme.outline.withOpacity(0.5),
                width: _hovered ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              hoverColor: scheme.primary.withOpacity(0.04),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 封面图 - 处理加载中、失败、空 URL 三种状态
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
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: scheme.outline.withOpacity(0.15),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _Placeholder(scheme: scheme),
    );
  }
}

/// 封面占位图
class _Placeholder extends StatelessWidget {
  final ColorScheme scheme;

  const _Placeholder({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.outline.withOpacity(0.15),
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          size: 40,
          color: scheme.outline,
        ),
      ),
    );
  }
}

/// 状态标签
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;

  const _ActionButton({
    required this.icon,
    this.label,
    this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: onTap != null
            ? foregroundColor.withOpacity(0.1)
            : Colors.transparent,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foregroundColor),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label!,
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
