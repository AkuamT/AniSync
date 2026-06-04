import 'package:dio/dio.dart';
import '../app_config.dart';
import 'api_endpoints.dart';
import '../models/anime.dart';
import '../models/search_result.dart';

/// 网络请求单例
/// 统一管理 Dio 实例、拦截器、错误处理
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    // 请求拦截器：日志
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('[API] ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        print('[API] ${response.statusCode} ${response.requestOptions.path}');
        handler.next(response);
      },
      onError: (error, handler) {
        print('[API ERROR] ${error.message}');
        handler.next(error);
      },
    ));
  }

  /// 统一错误处理包装
  Future<Response<T>> _request<T>(Future<Response<T>> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  String _parseError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.sendTimeout:
        return '发送超时，请检查网络';
      case DioExceptionType.receiveTimeout:
        return '请求超时，服务器响应过慢';
      case DioExceptionType.connectionError:
        return '无法连接服务器，请确认后端已启动';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final detail = e.response?.data?['detail'];
        // 优先展示后端返回的 detail（如 Bangumi 超时、频率限制等）
        if (detail != null) return detail.toString();
        if (statusCode == 404) return '资源不存在';
        if (statusCode == 500) return '服务器内部错误';
        if (statusCode == 502) return '上游服务不可用';
        if (statusCode == 503) return '服务暂时不可用，请稍后重试';
        if (statusCode == 504) return '上游服务超时，请稍后重试';
        return '请求失败 ($statusCode)';
      default:
        return '网络错误: ${e.message}';
    }
  }

  // ============ 番剧管理 API ============

  /// 获取番剧列表
  Future<List<Anime>> fetchAnimeList({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 100,
  }) async {
    final response = await _request(() => _dio.get(
      ApiEndpoints.anime,
      queryParameters: {
        if (status != null) 'status': status,
        if (search != null) 'search': search,
        'page': page,
        'page_size': pageSize,
      },
    ));
    return (response.data as List).map((e) => Anime.fromJson(e)).toList();
  }

  /// 添加番剧
  Future<Anime> createAnime(Map<String, dynamic> payload) async {
    final response = await _request(
      () => _dio.post(ApiEndpoints.anime, data: payload),
    );
    return Anime.fromJson(response.data);
  }

  /// 更新番剧（部分更新）
  Future<Anime> updateAnime(int id, Map<String, dynamic> payload) async {
    final response = await _request(
      () => _dio.put(ApiEndpoints.animeById(id), data: payload),
    );
    return Anime.fromJson(response.data);
  }

  /// 删除番剧
  Future<void> deleteAnime(int id) async {
    await _request(() => _dio.delete(ApiEndpoints.animeById(id)));
  }

  // ============ 搜索 API ============

  /// 搜索外部番剧数据库
  Future<List<SearchResult>> searchBangumi(String keyword, {int limit = 10}) async {
    final response = await _request(() => _dio.get(
      ApiEndpoints.bangumiSearch,
      queryParameters: {'keyword': keyword, 'limit': limit},
    ));
    final results = response.data['results'] as List;
    return results
        .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
