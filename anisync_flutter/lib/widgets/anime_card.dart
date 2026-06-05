import 'package:flutter/material.dart';
import '../models/anime.dart';

/// 番剧卡片 — 纯 UI 展示组件（杂志风无界设计）
///
/// 布局结构（Column 约束模型，杜绝溢出）：
/// ```
/// ClipRRect
///   └─ Column
///        ├─ Expanded ─ Stack（封面图 + 水印 + 删除按钮 + 底部渐变融合）
///        └─ Container ─ 底部信息区（标题、状态、进度条、+1 按钮）
/// ```
///
/// 约束来源：ReorderableGridView.count(childAspectRatio: 0.62)
/// → 单元格高度 = 单元格宽度 / 0.62
/// → Expanded 自动吐纳剩余空间，信息区根据内容自然撑开
/// → 绝无 BOTTOM OVERFLOWED
class AnimeCard extends StatefulWidget {
  final Anime anime;
  final VoidCallback? onAddProgress;
  final VoidCallback? onDelete;
  final VoidCallback? onCardTap;
  final bool compact;

  const AnimeCard({
    super.key,
    required this.anime,
    this.onAddProgress,
    this.onDelete,
    this.onCardTap,
    this.compact = false,
  });

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springController;
  late final Animation<double> _springAnimation;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _springAnimation = CurvedAnimation(
      parent: _springController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    _springController.animateTo(0.94, curve: Curves.easeOutQuart);
  }

  void _onTapUp(_) {
    _springController.animateTo(0, curve: Curves.easeOut);
  }

  void _onTapCancel() {
    _springController.animateTo(0, curve: Curves.easeOut);
  }

  Color _statusColor(ColorScheme scheme) {
    switch (widget.anime.status) {
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
    final scheme = theme.colorScheme;
    final statusColor = _statusColor(scheme);

    final bool isFullyWatched = widget.anime.totalEpisodes > 0 &&
        widget.anime.currentEpisode >= widget.anime.totalEpisodes;

    final double cardRadius = widget.compact ? 16 : 20;
    final double fontSize = widget.compact ? 14 : 16;
    final double smallFont = widget.compact ? 11 : 12;
    final double barHeight = widget.compact ? 2.5 : 3.0;
    final EdgeInsets infoPadding = widget.compact
        ? const EdgeInsets.all(10)
        : const EdgeInsets.all(14);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onCardTap,
      child: AnimatedBuilder(
        animation: _springAnimation,
        builder: (context, child) {
          final scale = 0.94 + (_springAnimation.value * 0.06);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 封面图区域（Expanded 自动吞吐剩余高度）──
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 封面图 — fit: BoxFit.cover 确保填满且不溢出
                    _CoverImage(coverUrl: widget.anime.coverUrl),

                    // ── 删除按钮（右上角悬浮）──
                    if (widget.onDelete != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _DeleteButton(onTap: widget.onDelete!),
                      ),

                    // ── 装饰水印 — 角落大字号半透明 ──
                    Positioned(
                      top: widget.compact ? -8 : -12,
                      right: widget.compact ? -6 : -8,
                      child: Opacity(
                        opacity: 0.04,
                        child: Text(
                          widget.anime.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: widget.compact ? 42 : 56,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),

                    // ── 图片底部渐变（与下方实色自然融合）──
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 底部信息栏 — 独立容器，高度由内容决定，绝不溢出 ──
              Container(
                color: const Color(0xFF121212),
                padding: infoPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── 标题 ──
                    Text(
                      widget.anime.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: widget.compact ? 6 : 8),

                    // ── 进度行 ──
                    Row(
                      children: [
                        _StatusBadge(
                          label: widget.anime.statusLabel,
                          color: statusColor,
                          compact: widget.compact,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.anime.currentEpisode}/${widget.anime.totalEpisodes > 0 ? widget.anime.totalEpisodes : '?'}',
                          style: TextStyle(
                            fontSize: smallFont,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                        const Spacer(),
                        _FloatingAction(
                          icon: isFullyWatched
                              ? Icons.check_rounded
                              : Icons.add_rounded,
                          onTap: isFullyWatched ? null : widget.onAddProgress,
                          color: isFullyWatched
                              ? Colors.greenAccent
                              : statusColor,
                          compact: widget.compact,
                        ),
                      ],
                    ),
                    SizedBox(height: widget.compact ? 6 : 8),

                    // ── 进度条 ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: widget.anime.totalEpisodes > 0
                            ? (widget.anime.currentEpisode /
                                    widget.anime.totalEpisodes)
                                .clamp(0.0, 1.0)
                            : 0,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          statusColor.withOpacity(0.9),
                        ),
                        minHeight: barHeight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  子组件
// ═══════════════════════════════════════════════════════════════

class _CoverImage extends StatelessWidget {
  final String? coverUrl;

  const _CoverImage({this.coverUrl});

  @override
  Widget build(BuildContext context) {
    if (coverUrl == null || coverUrl!.isEmpty) {
      return Container(
        color: Colors.grey.shade900,
        child: const Center(
          child: Icon(Icons.movie_outlined, size: 48, color: Colors.white24),
        ),
      );
    }
    return Image.network(
      coverUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey.shade900,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade900,
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 40,
            color: Colors.white24,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _StatusBadge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w800,
          height: 1.2,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FloatingAction extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final bool compact;

  const _FloatingAction({
    required this.icon,
    this.onTap,
    required this.color,
    this.compact = false,
  });

  @override
  State<_FloatingAction> createState() => _FloatingActionState();
}

class _FloatingActionState extends State<_FloatingAction>
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
    final size = widget.compact ? 28.0 : 32.0;

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
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.9),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: widget.compact ? 14 : 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 卡片删除按钮 — 右上角悬浮圆形图标，轻触弹出确认对话框
class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.45),
        ),
        child: const Icon(
          Icons.close_rounded,
          size: 14,
          color: Colors.white70,
        ),
      ),
    );
  }
}
