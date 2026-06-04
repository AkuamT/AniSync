/// API 端点常量，避免魔法字符串
class ApiEndpoints {
  // 番剧管理
  static const String anime = '/api/anime';
  static String animeById(int id) => '/api/anime/$id';

  // 番剧搜索（外部数据源）
  static const String bangumiSearch = '/api/bangumi/search';

  // 健康检查
  static const String health = '/api/health';
}
