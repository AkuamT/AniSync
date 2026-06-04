import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/anime.dart';

/// 番剧卡片 - 纯 UI 展示组件（二次元毛玻璃风格）
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

  /// 紧凑模式：窄屏 2 列布局下缩小间距和字号
  final bool compact;

  const AnimeCard({
    super.key,
    required this.anime,
    this.onAddProgress,
    this.onDelete,
    this.onCardTap,
    this.compact = false,
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

    return _GlassCard(
      onTap: onCardTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 封面图（Expanded 自适应剩余高度）──
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                width: double.infinity,
                child: _CoverImage(coverUrl: anime.coverUrl),
              ),
            ),
          ),

          // ── 内容区（固定结构，不会溢出）──
          Padding(
            padding: compact
                ? const EdgeInsets.fromLTRB(10, 8, 10, 10)
                : const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Text(
                  anime.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: compact
                      ? textTheme.titleSmall
                      : textTheme.titleMedium,
                ),
                SizedBox(height: compact ? 4 : 6),

                // 状态标签 + 进度文字
                Row(
                  children: [
                    _StatusBadge(
                      label: anime.statusLabel,
                      color: statusColor,
                      compact: compact,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${anime.currentEpisode}/${anime.totalEpisodes > 0 ? anime.totalEpisodes : '?'}',
                      style: compact
                          ? textTheme.bodySmall?.copyWith(fontSize: 11)
                          : textTheme.bodySmall,
                    ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // 进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: anime.totalEpisodes > 0
                        ? (anime.currentEpisode / anime.totalEpisodes)
                            .clamp(0.0, 1.0)
                        : 0,
                    backgroundColor: scheme.outline.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: compact ? 3 : 4,
                  ),
                ),
                SizedBox(height: compact ? 8 : 10),

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
                                  scheme.secondary.withOpacity(0.15),
                              foregroundColor: scheme.secondary,
                              compact: compact,
                            )
                          : _ActionButton(
                              icon: Icons.add_rounded,
                              label: '+1',
                              onTap: onAddProgress,
                              backgroundColor: scheme.primary,
                              foregroundColor: Colors.white,
                              compact: compact,
                            ),
                    ),
                    const SizedBox(width: 8),
                    // 删除按钮
                    _ActionButton(
                      icon: Icons.delete_outline_rounded,
                      onTap: onDelete,
                      backgroundColor: scheme.error.withOpacity(0.15),
                      foregroundColor: scheme.error,
                      compact: compact,
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

/// 二次元毛玻璃卡片包装器
///
/// 使用 BackdropFilter + ImageFilter.blur 实现毛玻璃效果，
/// 配合半透明底色和极细白边营造精致感。
class _GlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _GlassCard({required this.child, this.onTap});

  @override
  State<_GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<_GlassCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    // 毛玻璃底色：暗色下偏黑半透明，亮色下偏白半透明
    final glassColor = isDark
        ? Colors.black.withOpacity(0.35)
        : Colors.white.withOpacity(0.55);
    // 边框色：暗色下微白，亮色下更白
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.6);
    final hoverBorderColor = isDark
        ? scheme.primary.withOpacity(0.5)
        : scheme.primary.withOpacity(0.4);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _hovered ? hoverBorderColor : borderColor,
                  width: _hovered ? 1.5 : 1,
                ),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: scheme.primary.withOpacity(isDark ? 0.25 : 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(20),
                hoverColor: scheme.primary.withOpacity(0.06),
                splashColor: scheme.primary.withOpacity(0.1),
                child: widget.child,
              ),
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

/// 状态标签（二次元风格小药丸）
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _StatusBadge({required this.label, required this.color, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}

/// 操作按钮（圆角更大，更活泼）
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool compact;

  const _ActionButton({
    required this.icon,
    this.label,
    this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(compact ? 8 : 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: onTap != null
            ? foregroundColor.withOpacity(0.12)
            : Colors.transparent,
        child: Container(
          height: compact ? 32 : 36,
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: compact ? 14 : 16, color: foregroundColor),
              if (label != null) ...[
                SizedBox(width: compact ? 3 : 4),
                Text(
                  label!,
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 12 : 13,
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
