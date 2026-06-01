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
# Bangumi 搜索 (Jikan API 代理)
# ═══════════════════════════════════════════════════════════════════════

class TestBangumiSearch:
    """GET /api/bangumi/search"""

    def test_search_returns_results(self, client, mock_jikan):
        """搜索接口应返回 Jikan API 的转换结果。"""
        resp = client.get("/api/bangumi/search", params={"keyword": "one piece"})
        assert resp.status_code == 200

        data = resp.json()
        assert "results" in data
        assert len(data["results"]) > 0

        first = data["results"][0]
        assert first["bangumi_id"] == 21
        assert first["title"] == "ONE PIECE"
        assert "cover_url" in first
        assert "description" in first

    def test_search_result_structure(self, client, mock_jikan):
        """验证搜索结果的字段结构符合前端所需。"""
        resp = client.get("/api/bangumi/search", params={"keyword": "test"})
        first = resp.json()["results"][0]

        expected_keys = {"bangumi_id", "title", "cover_url", "description", "total_episodes", "air_date"}
        assert expected_keys.issubset(first.keys()), f"缺少字段: {expected_keys - first.keys()}"

    def test_search_missing_keyword_returns_422(self, client, mock_jikan):
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
