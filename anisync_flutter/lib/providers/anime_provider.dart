import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/anime.dart';
import '../models/search_result.dart';

/// 追番列表状态管理
/// 单向数据流：UI → Provider → API → Provider → UI
class AnimeProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<Anime> _animeList = [];
  bool _isLoading = false;
  String? _error;

  // ===== 搜索相关状态 =====
  List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  // BUG-9 修复：请求序列号，用于丢弃过期响应
  int _searchSeq = 0;

  List<Anime> get animeList => _animeList;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<SearchResult> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;

  /// 按状态筛选
  List<Anime> filteredByStatus(String status) {
    return _animeList.where((a) => a.status == status).toList();
  }

  /// 各状态计数
  Map<String, int> get tabCounts => {
        'watching': _animeList.where((a) => a.status == 'watching').length,
        'plan': _animeList.where((a) => a.status == 'plan').length,
        'completed': _animeList.where((a) => a.status == 'completed').length,
      };

  /// 加载列表
  Future<void> loadList() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _animeList = await _api.fetchAnimeList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 添加番剧（从搜索结果加入）
  Future<bool> addAnime(Map<String, dynamic> payload) async {
    try {
      await _api.createAnime(payload);
      await loadList();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// +1 集
  Future<bool> plusOne(Anime anime) async {
    final newEpisode = anime.currentEpisode + 1;
    final newStatus =
        (anime.totalEpisodes > 0 && newEpisode >= anime.totalEpisodes)
            ? 'completed'
            : anime.status;

    try {
      await _api.updateAnime(anime.id, {
        'current_episode': newEpisode,
        'status': newStatus,
      });
      await loadList();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 切换状态
  Future<bool> changeStatus(Anime anime, String newStatus) async {
    try {
      await _api.updateAnime(anime.id, {'status': newStatus});
      await loadList();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 删除番剧
  Future<bool> deleteAnime(int id) async {
    try {
      await _api.deleteAnime(id);
      await loadList();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 搜索外部番剧（结果存储在 Provider 状态中）
  /// BUG-9 修复：使用请求序列号丢弃过期响应，防止竞态条件
  Future<void> searchBangumi(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      _searchResults = [];
      _searchError = null;
      notifyListeners();
      return;
    }

    final seq = ++_searchSeq;
    _isSearching = true;
    _searchError = null;
    notifyListeners();

    try {
      final results = await _api.searchBangumi(trimmed);
      // 如果已发出更新的请求，丢弃本次结果
      if (seq != _searchSeq) return;
      _searchResults = results;
    } catch (e) {
      if (seq != _searchSeq) return;
      _searchError = e.toString();
      _searchResults = [];
    } finally {
      if (seq == _searchSeq) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  /// 清空搜索结果
  /// BUG-10 修复：补充 notifyListeners() 调用
  void clearSearch() {
    _searchResults = [];
    _searchError = null;
    _searchSeq++; // 取消正在进行的搜索请求
    notifyListeners();
  }

  /// 从搜索结果添加番剧（默认 status = plan）
  Future<bool> addAnimeFromSearch(SearchResult result) async {
    try {
      await _api.createAnime(result.toCreatePayload());
      await loadList();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
