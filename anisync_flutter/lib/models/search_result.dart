/// Bangumi 搜索结果模型
/// 对应后端 `/api/bangumi/search` 返回的 results 数组项
class SearchResult {
  final int bangumiId;
  final String title;
  final String? coverUrl;
  final String? description;
  final int totalEpisodes;
  final String? airDate;

  SearchResult({
    required this.bangumiId,
    required this.title,
    this.coverUrl,
    this.description,
    this.totalEpisodes = 0,
    this.airDate,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      bangumiId: json['bangumi_id'] as int,
      title: json['title'] as String,
      coverUrl: json['cover_url'] as String?,
      description: json['description'] as String?,
      totalEpisodes: json['total_episodes'] as int? ?? 0,
      airDate: json['air_date'] as String?,
    );
  }

  /// 转换为 AnimeCreate payload
  /// [status] 由调用方根据当前 Tab 动态传入，默认为 'plan'（想看）
  /// BUG-12 修复：省略 score 字段而非显式传 null
  Map<String, dynamic> toCreatePayload({String status = 'plan'}) {
    return {
      'title': title,
      'cover_url': coverUrl,
      'description': description,
      'total_episodes': totalEpisodes,
      'current_episode': 0,
      'status': status,
      'air_date': airDate,
      'bangumi_id': bangumiId,
    };
  }

  /// 安全的开播年份提取
  String get airYear {
    if (airDate == null || airDate!.isEmpty) return '';
    if (airDate!.length >= 4) return airDate!.substring(0, 4);
    return '';
  }
}
