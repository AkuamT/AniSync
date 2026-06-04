/// 番剧数据模型，与后端 AnimeResponse 完全对齐
class Anime {
  final int id;
  final String title;
  final String? coverUrl;
  final String? description;
  final int totalEpisodes;
  final int currentEpisode;
  final String status; // plan | watching | completed
  final int? score;
  final String? airDate;
  final int? bangumiId;
  final String? createdAt;
  final String? updatedAt;

  Anime({
    required this.id,
    required this.title,
    this.coverUrl,
    this.description,
    this.totalEpisodes = 0,
    this.currentEpisode = 0,
    this.status = 'plan',
    this.score,
    this.airDate,
    this.bangumiId,
    this.createdAt,
    this.updatedAt,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      id: json['id'] as int,
      title: json['title'] as String,
      coverUrl: json['cover_url'] as String?,
      description: json['description'] as String?,
      totalEpisodes: json['total_episodes'] as int? ?? 0,
      currentEpisode: json['current_episode'] as int? ?? 0,
      status: json['status'] as String? ?? 'plan',
      score: json['score'] as int?,
      airDate: json['air_date'] as String?,
      bangumiId: json['bangumi_id'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'cover_url': coverUrl,
      'description': description,
      'total_episodes': totalEpisodes,
      'current_episode': currentEpisode,
      'status': status,
      'score': score,
      'air_date': airDate,
      'bangumi_id': bangumiId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// 用于导出全量数据
  Map<String, dynamic> toExportJson() {
    return {
      'title': title,
      'cover_url': coverUrl,
      'description': description,
      'total_episodes': totalEpisodes,
      'current_episode': currentEpisode,
      'status': status,
      'score': score,
      'air_date': airDate,
      'bangumi_id': bangumiId,
    };
  }

  /// 是否已看完
  bool get isCompleted => totalEpisodes > 0 && currentEpisode >= totalEpisodes;

  /// 进度百分比 0~100
  double get progressPercent {
    if (totalEpisodes <= 0) return 0;
    return (currentEpisode / totalEpisodes * 100).clamp(0, 100);
  }

  /// 状态中文标签
  String get statusLabel {
    switch (status) {
      case 'watching':
        return '在看';
      case 'completed':
        return '已看完';
      case 'plan':
      default:
        return '想看';
    }
  }

  Anime copyWith({
    int? id,
    String? title,
    String? coverUrl,
    String? description,
    int? totalEpisodes,
    int? currentEpisode,
    String? status,
    int? score,
    String? airDate,
    int? bangumiId,
    String? createdAt,
    String? updatedAt,
  }) {
    return Anime(
      id: id ?? this.id,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      status: status ?? this.status,
      score: score ?? this.score,
      airDate: airDate ?? this.airDate,
      bangumiId: bangumiId ?? this.bangumiId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
