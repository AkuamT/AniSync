"""
AniSync API 自动化测试
=====================

覆盖核心接口:
  - GET  /api/health
  - GET  /api/bangumi/search
  - POST /api/anime
  - GET  /api/anime
  - PUT  /api/anime/{id}

所有测试运行在内存 SQLite 数据库中，不会污染本地数据文件。
"""
import pytest


# ═══════════════════════════════════════════════════════════════════════
# 辅助函数
# ═══════════════════════════════════════════════════════════════════════

def _create_anime(client, **overrides) -> dict:
    """创建一部番剧并返回响应数据。"""
    payload = {
        "title": "进击的巨人",
        "cover_url": "https://example.com/aot.jpg",
        "description": "人类与巨人的战争",
        "total_episodes": 25,
        "current_episode": 0,
        "status": "plan",
    }
    payload.update(overrides)
    resp = client.post("/api/anime", json=payload)
    assert resp.status_code == 201, f"创建失败: {resp.text}"
    return resp.json()


# ═══════════════════════════════════════════════════════════════════════
# 健康检查
# ═══════════════════════════════════════════════════════════════════════

class TestHealthCheck:
    """GET /api/health"""

    def test_health_returns_ok(self, client):
        resp = client.get("/api/health")
        assert resp.status_code == 200
        assert resp.json() == {"status": "ok"}


# ═══════════════════════════════════════════════════════════════════════
# Bangumi 搜索 (Bangumi API 代理)
# ═══════════════════════════════════════════════════════════════════════

class TestBangumiSearch:
    """GET /api/bangumi/search"""

    def test_search_returns_results(self, client, mock_bangumi):
        """搜索接口应返回 Bangumi API 的转换结果。"""
        resp = client.get("/api/bangumi/search", params={"keyword": "one piece"})
        assert resp.status_code == 200

        data = resp.json()
        assert "results" in data
        assert len(data["results"]) > 0

        first = data["results"][0]
        assert first["bangumi_id"] == 21
        assert first["title"] == "海贼王"  # name_cn 优先
        assert "cover_url" in first
        assert "description" in first

    def test_search_result_structure(self, client, mock_bangumi):
        """验证搜索结果的字段结构符合前端所需。"""
        resp = client.get("/api/bangumi/search", params={"keyword": "test"})
        first = resp.json()["results"][0]

        expected_keys = {"bangumi_id", "title", "cover_url", "description", "total_episodes", "air_date"}
        assert expected_keys.issubset(first.keys()), f"缺少字段: {expected_keys - first.keys()}"

    def test_search_missing_keyword_returns_422(self, client, mock_bangumi):
        """缺少 keyword 参数时应返回 422 校验错误。"""
        resp = client.get("/api/bangumi/search")
        assert resp.status_code == 422


# ═══════════════════════════════════════════════════════════════════════
# 番剧创建
# ═══════════════════════════════════════════════════════════════════════

class TestCreateAnime:
    """POST /api/anime"""

    def test_create_with_default_status_plan(self, client):
        """不指定 status 时，默认应为 'plan'。"""
        resp = client.post("/api/anime", json={"title": "鬼灭之刃"})
        assert resp.status_code == 201

        data = resp.json()
        assert data["title"] == "鬼灭之刃"
        assert data["status"] == "plan"
        assert data["id"] is not None

    def test_create_with_explicit_status(self, client):
        """可以显式指定 status 为 watching。"""
        data = _create_anime(client, title="咒术回战", status="watching")
        assert data["status"] == "watching"

    def test_create_returns_full_record(self, client):
        """创建后应返回完整的番剧记录（含 id 和时间戳）。"""
        data = _create_anime(client, title="刀剑神域")
        assert "id" in data
        assert "created_at" in data
        assert "updated_at" in data

    def test_create_missing_title_returns_422(self, client):
        """缺少必填字段 title 时应返回 422。"""
        resp = client.post("/api/anime", json={"cover_url": "test.jpg"})
        assert resp.status_code == 422


# ═══════════════════════════════════════════════════════════════════════
# 番剧查询
# ═══════════════════════════════════════════════════════════════════════

class TestListAnime:
    """GET /api/anime"""

    def test_list_empty_returns_empty_array(self, client):
        """数据库为空时应返回空列表。"""
        resp = client.get("/api/anime")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_list_returns_created_anime(self, client):
        """创建番剧后，列表接口应能查询到。"""
        created = _create_anime(client, title="命运石之门")

        resp = client.get("/api/anime")
        assert resp.status_code == 200

        anime_list = resp.json()
        assert len(anime_list) >= 1
        ids = [a["id"] for a in anime_list]
        assert created["id"] in ids

    def test_list_filter_by_status(self, client):
        """支持按状态筛选。"""
        _create_anime(client, title="番剧A", status="plan")
        _create_anime(client, title="番剧B", status="watching")

        resp = client.get("/api/anime", params={"status": "watching"})
        data = resp.json()
        assert all(a["status"] == "watching" for a in data)
        assert len(data) == 1

    def test_list_search_by_title(self, client):
        """支持按标题模糊搜索。"""
        _create_anime(client, title="Re:从零开始的异世界生活")
        _create_anime(client, title="命运石之门")

        resp = client.get("/api/anime", params={"search": "命运石"})
        data = resp.json()
        assert len(data) == 1
        assert "命运石" in data[0]["title"]


# ═══════════════════════════════════════════════════════════════════════
# 番剧更新 (状态流转)
# ═══════════════════════════════════════════════════════════════════════

class TestUpdateAnime:
    """PUT /api/anime/{id}"""

    def test_update_status_plan_to_watching(self, client):
        """核心场景: 将状态从 plan 更新为 watching。"""
        created = _create_anime(client, title="进击的巨人", status="plan")
        anime_id = created["id"]

        resp = client.put(f"/api/anime/{anime_id}", json={"status": "watching"})
        assert resp.status_code == 200

        data = resp.json()
        assert data["status"] == "watching"
        assert data["id"] == anime_id

    def test_update_status_watching_to_completed(self, client):
        """核心场景: 将状态从 watching 更新为 completed。"""
        created = _create_anime(client, title="钢之炼金术师", status="watching")

        resp = client.put(f"/api/anime/{created['id']}", json={"status": "completed"})
        assert resp.status_code == 200
        assert resp.json()["status"] == "completed"

    def test_update_episode_progress(self, client):
        """更新观看进度。"""
        created = _create_anime(client, title="JOJO", total_episodes=26, current_episode=0)

        resp = client.put(f"/api/anime/{created['id']}", json={"current_episode": 12})
        assert resp.status_code == 200
        assert resp.json()["current_episode"] == 12

    def test_update_nonexistent_returns_404(self, client):
        """更新不存在的番剧应返回 404。"""
        resp = client.put("/api/anime/99999", json={"status": "watching"})
        assert resp.status_code == 404

    def test_update_multiple_fields(self, client):
        """支持同时更新多个字段。"""
        created = _create_anime(client, title="间谍过家家")

        resp = client.put(
            f"/api/anime/{created['id']}",
            json={"status": "watching", "current_episode": 5, "score": 9},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "watching"
        assert data["current_episode"] == 5
        assert data["score"] == 9

    def test_full_status_lifecycle(self, client):
        """完整状态流转生命周期: plan → watching → completed。"""
        # 创建 (默认 plan)
        created = _create_anime(client, title="Fate/Zero")
        assert created["status"] == "plan"

        # plan → watching
        resp = client.put(f"/api/anime/{created['id']}", json={"status": "watching"})
        assert resp.json()["status"] == "watching"

        # watching → completed
        resp = client.put(f"/api/anime/{created['id']}", json={"status": "completed"})
        assert resp.json()["status"] == "completed"

        # 验证最终状态
        resp = client.get(f"/api/anime/{created['id']}")
        assert resp.json()["status"] == "completed"


# ═══════════════════════════════════════════════════════════════════════
# 番剧删除
# ═══════════════════════════════════════════════════════════════════════

class TestDeleteAnime:
    """DELETE /api/anime/{id}"""

    def test_delete_removes_anime(self, client):
        """删除后列表不应再包含该番剧。"""
        created = _create_anime(client, title="临时番剧")
        anime_id = created["id"]

        resp = client.delete(f"/api/anime/{anime_id}")
        assert resp.status_code == 204

        # 确认已删除
        get_resp = client.get(f"/api/anime/{anime_id}")
        assert get_resp.status_code == 404

    def test_delete_nonexistent_returns_404(self, client):
        """删除不存在的番剧应返回 404。"""
        resp = client.delete("/api/anime/99999")
        assert resp.status_code == 404


# ═══════════════════════════════════════════════════════════════════════
# 单个番剧查询
# ═══════════════════════════════════════════════════════════════════════

class TestGetAnime:
    """GET /api/anime/{id}"""

    def test_get_existing_anime(self, client):
        """查询存在的番剧应返回完整记录。"""
        created = _create_anime(client, title="测试查询")

        resp = client.get(f"/api/anime/{created['id']}")
        assert resp.status_code == 200
        assert resp.json()["title"] == "测试查询"

    def test_get_nonexistent_returns_404(self, client):
        """查询不存在的番剧应返回 404。"""
        resp = client.get("/api/anime/99999")
        assert resp.status_code == 404


# ═══════════════════════════════════════════════════════════════════════
# 数据导出
# ═══════════════════════════════════════════════════════════════════════

class TestExportAnime:
    """GET /api/anime/export/all"""

    def test_export_empty_returns_empty_list(self, client):
        """空数据库导出的 anime_list 应为空列表。"""
        resp = client.get("/api/anime/export/all")
        assert resp.status_code == 200

        data = resp.json()
        assert data["version"] == 1
        assert "exported_at" in data
        assert data["anime_list"] == []

    def test_export_returns_all_anime(self, client):
        """导出应包含数据库中所有番剧。"""
        _create_anime(client, title="番剧A", status="watching")
        _create_anime(client, title="番剧B", status="completed")
        _create_anime(client, title="番剧C", status="plan")

        resp = client.get("/api/anime/export/all")
        data = resp.json()
        assert len(data["anime_list"]) == 3
        titles = [a["title"] for a in data["anime_list"]]
        assert "番剧A" in titles
        assert "番剧B" in titles
        assert "番剧C" in titles

    def test_export_fields_match_create_payload(self, client):
        """导出字段应与 AnimeCreate schema 兼容（可被导入端点直接消费）。"""
        _create_anime(client, title="进击的巨人", bangumi_id=42, total_episodes=25)

        resp = client.get("/api/anime/export/all")
        exported = resp.json()["anime_list"][0]
        # AnimeCreate 所需字段
        expected_keys = {"title", "cover_url", "description", "total_episodes",
                         "current_episode", "status", "score", "air_date", "bangumi_id"}
        assert expected_keys.issubset(exported.keys())
        # 不应包含内部字段
        assert "id" not in exported
        assert "created_at" not in exported


# ═══════════════════════════════════════════════════════════════════════
# 数据导入
# ═══════════════════════════════════════════════════════════════════════

class TestImportAnime:
    """POST /api/anime/import"""

    def test_import_new_anime(self, client):
        """导入本地不存在的番剧（新 bangumi_id）应创建新记录。"""
        payload = {
            "anime_list": [
                {"title": "导入番剧", "bangumi_id": 999, "status": "plan"},
            ]
        }
        resp = client.post("/api/anime/import", json=payload)
        assert resp.status_code == 200

        result = resp.json()
        assert result["imported"] == 1
        assert result["updated"] == 0

        # 确认已被导入
        list_resp = client.get("/api/anime")
        assert len(list_resp.json()) == 1

    def test_import_updates_existing_by_bangumi_id(self, client):
        """bangumi_id 匹配时应更新已有记录，而非重复创建。"""
        _create_anime(client, title="旧标题", bangumi_id=42, status="plan")

        payload = {
            "anime_list": [
                {"title": "新标题", "bangumi_id": 42, "status": "watching",
                 "current_episode": 3, "total_episodes": 12},
            ]
        }
        resp = client.post("/api/anime/import", json=payload)
        assert resp.status_code == 200

        result = resp.json()
        assert result["imported"] == 0   # 不应新建
        assert result["updated"] == 1    # 应更新

        # 验证更新后的值
        list_resp = client.get("/api/anime")
        anime = list_resp.json()[0]
        assert anime["title"] == "新标题"
        assert anime["status"] == "watching"
        assert anime["current_episode"] == 3

    def test_import_mixed_new_and_existing(self, client):
        """混合导入：已存在的更新，不存在的创建。"""
        _create_anime(client, title="已存在", bangumi_id=10, status="plan")

        payload = {
            "anime_list": [
                {"title": "已存在-更新", "bangumi_id": 10, "status": "completed"},
                {"title": "新番剧", "bangumi_id": 20, "status": "watching"},
                {"title": "另一新番", "bangumi_id": 30, "status": "plan"},
            ]
        }
        resp = client.post("/api/anime/import", json=payload)
        assert resp.status_code == 200

        result = resp.json()
        assert result["imported"] == 2
        assert result["updated"] == 1
        assert result["skipped"] == 0

        # 再次确认总数 = 3（重复导入不应重复计数）
        resp2 = client.post("/api/anime/import", json=payload)
        result2 = resp2.json()
        assert result2["imported"] == 0
        assert result2["updated"] == 3
        assert len(client.get("/api/anime").json()) == 3

    def test_import_empty_list(self, client):
        """导入空列表应正常返回，不做修改。"""
        resp = client.post("/api/anime/import", json={"anime_list": []})
        assert resp.status_code == 200

        result = resp.json()
        assert result["imported"] == 0
        assert result["updated"] == 0


# ═══════════════════════════════════════════════════════════════════════
# 局域网同步
# ═══════════════════════════════════════════════════════════════════════

class TestLanSync:
    """POST /api/anime/lan-sync"""

    # ── preview 模式 ──

    def test_preview_returns_counts(self, client, mock_remote):
        """preview 模式应返回本地和远程的番剧数量统计。"""
        _create_anime(client, title="本地番剧", status="watching")

        resp = client.post("/api/anime/lan-sync", json={
            "host": "192.168.1.100",
            "port": 8080,
            "mode": "preview",
        })
        assert resp.status_code == 200

        data = resp.json()
        assert data["success"] is True
        assert data["mode"] == "preview"
        assert data["local_count"] == 1
        assert data["remote_count"] == 2  # mock_remote 提供 2 部
        assert data["local_status_counts"]["watching"] == 1
        assert data["remote_status_counts"]["watching"] == 1
        assert data["remote_status_counts"]["plan"] == 1

    def test_preview_with_empty_local(self, client, mock_remote):
        """本地无数据时，preview 应返回 local_count=0。"""
        resp = client.post("/api/anime/lan-sync", json={
            "host": "192.168.1.100",
            "port": 8080,
            "mode": "preview",
        })
        assert resp.status_code == 200

        data = resp.json()
        assert data["local_count"] == 0
        assert data["remote_count"] == 2

    # ── remote_overwrite 模式 ──

    def test_remote_overwrite_replaces_local_data(self, client, mock_remote):
        """远程覆盖本地：清空本地所有数据，全部替换为远程数据。"""
        _create_anime(client, title="本地番剧A", status="watching")
        _create_anime(client, title="本地番剧B", status="completed")

        resp = client.post("/api/anime/lan-sync", json={
            "host": "192.168.1.100",
            "port": 8080,
            "mode": "remote_overwrite",
        })
        assert resp.status_code == 200

        data = resp.json()
        assert data["success"] is True
        assert data["mode"] == "remote_overwrite"
        assert data["local_count"] == 2  # 现在只有远程的 2 部

        # 验证本地数据已被远程数据替换
        list_resp = client.get("/api/anime")
        anime_list = list_resp.json()
        assert len(anime_list) == 2
        titles = {a["title"] for a in anime_list}
        assert titles == {"远程番剧A", "远程番剧B"}

    # ── local_overwrite 模式 ──

    def test_local_overwrite_pushes_to_remote(self, client, mock_remote):
        """本地覆盖远程：将本地数据推送到远程设备。"""
        _create_anime(client, title="本地番剧", status="watching", bangumi_id=1)

        resp = client.post("/api/anime/lan-sync", json={
            "host": "192.168.1.100",
            "port": 8080,
            "mode": "local_overwrite",
        })
        assert resp.status_code == 200

        data = resp.json()
        assert data["success"] is True
        assert data["mode"] == "local_overwrite"
        assert data["result"]["imported"] == 5  # mock 返回值

        # 本地数据不应被修改
        list_resp = client.get("/api/anime")
        assert len(list_resp.json()) == 1

    # ── merge 模式 ──

    def test_merge_combines_both_datasets(self, client, mock_remote):
        """互相合并：远程数据导入本地，本地数据推送到远程。"""
        # 本地有一条与远程 bangumi_id=100 相同的记录 → 应被更新
        _create_anime(
            client, title="旧远程番剧A", bangumi_id=100, status="plan",
            current_episode=0, total_episodes=12,
        )
        # 本地有一条 bangumi_id 不重复的记录 → 保留
        _create_anime(client, title="独有本地番剧", bangumi_id=999, status="completed")

        resp = client.post("/api/anime/lan-sync", json={
            "host": "192.168.1.100",
            "port": 8080,
            "mode": "merge",
        })
        assert resp.status_code == 200

        data = resp.json()
        assert data["success"] is True
        assert data["mode"] == "merge"
        # result 显示导入结果：1 更新(bangumi_id=100匹配) + 1 新增(远程番剧B)
        assert data["result"]["imported"] == 1
        assert data["result"]["updated"] == 1

        # 本地应有 3 部：独有本地(999) + 更新的远程A(100) + 新增的远程B(200)
        list_resp = client.get("/api/anime")
        anime_list = list_resp.json()
        assert len(anime_list) == 3

        # 验证 bangumi_id=100 的记录已被远程数据更新
        updated = [a for a in anime_list if a["bangumi_id"] == 100][0]
        assert updated["title"] == "远程番剧A"
        assert updated["status"] == "watching"
        assert updated["current_episode"] == 5

    # ── 错误处理 ──

    def test_connection_timeout_returns_504(self, client):
        """访问无效地址应返回连接超时错误。"""
        # 使用不可路由的 IP (TEST-NET) 模拟超时
        resp = client.post("/api/anime/lan-sync", json={
            "host": "192.0.2.1",  # TEST-NET, 不应可达
            "port": 18080,        # 非常用端口
            "mode": "preview",
        })
        # 超时或连接错误
        assert resp.status_code in (502, 504)

    def test_invalid_mode_returns_422(self, client, mock_remote):
        """非法 mode 值应返回 422 验证错误。"""
        resp = client.post("/api/anime/lan-sync", json={
            "host": "192.168.1.100",
            "port": 8080,
            "mode": "invalid_mode",
        })
        assert resp.status_code == 422

    def test_missing_host_returns_422(self, client):
        """缺少必填字段 host 应返回 422。"""
        resp = client.post("/api/anime/lan-sync", json={
            "port": 8080,
            "mode": "preview",
        })
        assert resp.status_code == 422
