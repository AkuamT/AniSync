import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models/anime.dart';
import '../models/search_result.dart';

/// 追番列表状态管理
/// 单向数据流：UI → Provider → API → Provider → UI
///
/// 自定义排序机制：
/// - 每个 status 维护一个 ID 序列，通过 shared_preferences 持久化
/// - 从后端拉取数据后，根据本地 ID 序列重排
/// - 新番剧（本地无记录）默认插入列表最前面
/// - 拖拽排序后立即保存新的 ID 序列
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

  // ===== 自定义排序 =====
  // status → 有序 ID 列表（例如 'watching' → [5, 2, 8, 1]）
  final Map<String, List<int>> _customOrders = {};
  bool _ordersLoaded = false;

  // ===== Getters =====

  List<Anime> get animeList => _animeList;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<SearchResult> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;

  /// 按自定义顺序返回指定状态的番剧列表
  List<Anime> orderedByStatus(String status) {
    final filtered = _animeList.where((a) => a.status == status).toList();
    final order = _customOrders[status];
    if (order == null || order.isEmpty) return filtered;

    // 按本地 ID 序列排序
    final animeMap = {for (final a in filtered) a.id: a};
    final result = <Anime>[];
    for (final id in order) {
      if (animeMap.containsKey(id)) {
        result.add(animeMap[id]!);
      }
    }
    // 兜底：新加入但 order 尚未更新的 ID
    for (final a in filtered) {
      if (!order.contains(a.id)) {
        result.insert(0, a);
      }
    }
    return result;
  }

  /// 各状态计数
  Map<String, int> get tabCounts => {
        'watching': _animeList.where((a) => a.status == 'watching').length,
        'plan': _animeList.where((a) => a.status == 'plan').length,
        'completed': _animeList.where((a) => a.status == 'completed').length,
      };

  // ===== 自定义排序持久化 =====

  String _orderKey(String status) => 'custom_order_$status';

  /// 从 shared_preferences 加载所有排序数据（仅首次调用时读取磁盘）
  Future<void> _loadAllOrders() async {
    if (_ordersLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    for (final status in ['watching', 'plan', 'completed']) {
      final raw = prefs.getString(_orderKey(status));
      if (raw != null && raw.isNotEmpty) {
        try {
          _customOrders[status] = (json.decode(raw) as List).cast<int>();
        } catch (_) {
          _customOrders[status] = [];
        }
      } else {
        _customOrders[status] = [];
      }
    }
    _ordersLoaded = true;
  }

  /// 保存某个 status 的排序到磁盘
  Future<void> _saveOrder(String status) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _customOrders[status] ?? [];
    await prefs.setString(_orderKey(status), json.encode(ids));
  }

  /// 将后端返回的数据与本地排序合并，返回更新后的 ID 序列
  ///
  /// 合并规则：
  /// 1. 保留本地排序中仍存在于后端数据中的 ID（按本地顺序）
  /// 2. 移除已不在后端数据中的 ID（已被删除或变更状态）
  /// 3. 新 ID（后端有但本地无）插入最前面
  /// 4. 写回 shared_preferences
  List<int> _mergeOrder(String status, List<Anime> filtered) {
    final order = List<int>.from(_customOrders[status] ?? []);
    final fetchedIds = filtered.map((a) => a.id).toSet();

    // 剔除本地有但后端已不存在的 ID
    order.removeWhere((id) => !fetchedIds.contains(id));

    // 将新 ID 插入最前面
    for (final id in fetchedIds) {
      if (!order.contains(id)) {
        order.insert(0, id);
      }
    }

    _customOrders[status] = order;
    _saveOrder(status);
    return order;
  }

  // ===== 数据加载 =====

  /// 加载列表（首次加载或刷新时调用）
  Future<void> loadList() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadAllOrders();
      _animeList = await _api.fetchAnimeList();

      // 对每个状态应用本地排序
      for (final status in ['watching', 'plan', 'completed']) {
        final filtered = _animeList.where((a) => a.status == status).toList();
        _mergeOrder(status, filtered);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== 番剧操作（均在本地原地更新，不再全量 reload） =====

  /// 添加番剧 — 动态 status，本地 prepend 而非 reload
  Future<bool> addAnime(Map<String, dynamic> payload,
      {String status = 'plan'}) async {
    try {
      // 确保 payload 中的 status 与传入的 status 一致
      payload['status'] = status;
      final created = await _api.createAnime(payload);

      // 本地原地插入：新番剧放在最前面
      _animeList.insert(0, created);

      // 更新排序
      _customOrders[created.status] ??= [];
      _customOrders[created.status]!.insert(0, created.id);
      await _saveOrder(created.status);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 从搜索结果添加番剧（status 跟随当前 Tab）
  Future<bool> addAnimeFromSearch(SearchResult result,
      {String status = 'plan'}) async {
    final payload = result.toCreatePayload(status: status);
    return addAnime(payload, status: status);
  }

  /// +1 集 — 原地更新，保持列表顺序不变
  Future<bool> plusOne(Anime anime) async {
    final newEpisode = anime.currentEpisode + 1;
    final newStatus =
        (anime.totalEpisodes > 0 && newEpisode >= anime.totalEpisodes)
            ? 'completed'
            : anime.status;

    try {
      final updated = await _api.updateAnime(anime.id, {
        'current_episode': newEpisode,
        'status': newStatus,
      });

      // BUG 修复：原地替换，不改变列表顺序
      final index = _animeList.indexWhere((a) => a.id == anime.id);
      if (index != -1) {
        _animeList[index] = updated;
      }

      // 若状态变更，同步更新两个 status 的排序记录
      if (newStatus != anime.status) {
        _customOrders[anime.status]?.remove(anime.id);
        _customOrders[newStatus]?.insert(0, updated.id);
        await _saveOrder(anime.status);
        await _saveOrder(newStatus);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// -1 集 — 回退集数
  Future<bool> minusOne(Anime anime) async {
    if (anime.currentEpisode <= 0) return false;
    final newEpisode = anime.currentEpisode - 1;
    // 若从已完成退回，恢复为在看
    final newStatus = anime.status == 'completed' ? 'watching' : anime.status;

    try {
      final updated = await _api.updateAnime(anime.id, {
        'current_episode': newEpisode,
        'status': newStatus,
      });

      final index = _animeList.indexWhere((a) => a.id == anime.id);
      if (index != -1) {
        _animeList[index] = updated;
      }

      if (newStatus != anime.status) {
        _customOrders[anime.status]?.remove(anime.id);
        _customOrders[newStatus]?.insert(0, updated.id);
        await _saveOrder(anime.status);
        await _saveOrder(newStatus);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 跳转到指定集数 — 直接输入任意数值
  Future<bool> setEpisode(Anime anime, int episode) async {
    final newEpisode = episode.clamp(0, anime.totalEpisodes > 0 ? anime.totalEpisodes : episode);
    final newStatus =
        (anime.totalEpisodes > 0 && newEpisode >= anime.totalEpisodes)
            ? 'completed'
            : (newEpisode > 0 ? 'watching' : anime.status);

    try {
      final updated = await _api.updateAnime(anime.id, {
        'current_episode': newEpisode,
        if (newStatus != anime.status) 'status': newStatus,
      });

      final index = _animeList.indexWhere((a) => a.id == anime.id);
      if (index != -1) {
        _animeList[index] = updated;
      }

      if (newStatus != anime.status) {
        _customOrders[anime.status]?.remove(anime.id);
        _customOrders[newStatus]?.insert(0, updated.id);
        await _saveOrder(anime.status);
        await _saveOrder(newStatus);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 切换状态 — 原地更新
  Future<bool> changeStatus(Anime anime, String newStatus) async {
    final oldStatus = anime.status;
    try {
      final updated = await _api.updateAnime(anime.id, {'status': newStatus});

      // 原地替换
      final index = _animeList.indexWhere((a) => a.id == anime.id);
      if (index != -1) {
        _animeList[index] = updated;
      }

      // 同步排序记录
      if (newStatus != oldStatus) {
        _customOrders[oldStatus]?.remove(anime.id);
        _customOrders[newStatus]?.insert(0, updated.id);
        await _saveOrder(oldStatus);
        await _saveOrder(newStatus);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 删除番剧 — 原地移除
  Future<bool> deleteAnime(int id) async {
    try {
      await _api.deleteAnime(id);

      // 原地移除
      _animeList.removeWhere((a) => a.id == id);

      // 清理排序记录
      for (final status in ['watching', 'plan', 'completed']) {
        if (_customOrders[status]?.remove(id) ?? false) {
          await _saveOrder(status);
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 拖拽重排：在指定 status 内，将 oldIndex 的番剧移动到 newIndex
  ///
  /// [oldIndex] 和 [newIndex] 基于 orderedByStatus 返回的列表索引
  Future<void> reorderItems(String status, int oldIndex, int newIndex) async {
    final order = List<int>.from(_customOrders[status] ?? []);
    if (order.isEmpty || oldIndex < 0 || oldIndex >= order.length) return;

    final id = order.removeAt(oldIndex);
    // newIndex 已经考虑移除后的数组（ReorderableGridView 的标准行为）
    final insertIndex = newIndex.clamp(0, order.length);
    order.insert(insertIndex, id);

    _customOrders[status] = order;
    await _saveOrder(status);
    notifyListeners();
  }

  // ===== 搜索 =====

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
}
