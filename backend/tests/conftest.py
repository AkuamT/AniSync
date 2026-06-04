"""
Pytest 配置 —— 内存数据库隔离 + FastAPI TestClient

核心思路: 创建一个全局 aiosqlite 连接，通过 dependency_overrides
让所有 API 请求复用同一个连接，确保内存数据库数据在请求间共享。
"""
import sys
import os
import pytest
import aiosqlite

# 确保 backend/app 在 Python 路径中
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.database import get_db
from app.main import app


# ─── 全局连接: 所有请求共用这一个对象 ─────────────────────────────
_conn: aiosqlite.Connection | None = None


async def _override_get_db():
    """覆盖 get_db: 始终 yield 同一个内存数据库连接。"""
    global _conn
    yield _conn


@pytest.fixture(autouse=True)
async def setup_test_db():
    """
    每个测试前: 创建内存数据库 + 建表。
    每个测试后: 关闭连接。
    """
    global _conn

    # 创建内存数据库连接 (plain :memory:)
    _conn = await aiosqlite.connect(":memory:")
    _conn.row_factory = aiosqlite.Row

    # 建表
    await _conn.execute("""
        CREATE TABLE anime (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            title           TEXT NOT NULL,
            cover_url       TEXT,
            description     TEXT,
            total_episodes  INTEGER DEFAULT 0,
            current_episode INTEGER DEFAULT 0,
            status          TEXT DEFAULT 'plan',
            score           INTEGER,
            air_date        TEXT,
            bangumi_id      INTEGER,
            created_at      TEXT DEFAULT (datetime('now')),
            updated_at      TEXT DEFAULT (datetime('now'))
        )
    """)
    await _conn.execute("CREATE INDEX idx_anime_status ON anime(status)")
    await _conn.execute("CREATE INDEX idx_anime_bangumi_id ON anime(bangumi_id)")
    await _conn.commit()

    # 覆盖数据库依赖
    app.dependency_overrides[get_db] = _override_get_db

    yield

    # 清理
    await _conn.close()
    _conn = None
    app.dependency_overrides.clear()


@pytest.fixture
def client():
    """同步 FastAPI TestClient。"""
    from fastapi.testclient import TestClient

    with TestClient(app) as c:
        yield c


@pytest.fixture
def mock_bangumi():
    """
    Mock Bangumi API 的 HTTP 调用，返回可控的测试数据。
    """
    from unittest.mock import patch, AsyncMock, MagicMock

    fake_response = MagicMock()
    fake_response.raise_for_status = MagicMock()
    fake_response.json.return_value = {
        "total": 1,
        "limit": 10,
        "offset": 0,
        "data": [
            {
                "id": 21,
                "name": "ONE PIECE",
                "name_cn": "海贼王",
                "images": {
                    "large": "https://lain.bgm.tv/pic/cover/l/abc123.jpg",
                    "common": "https://lain.bgm.tv/pic/cover/c/abc123.jpg",
                },
                "summary": "Barely surviving in a barrel after passing through a terrible whirlpool...",
                "eps": 0,
                "air_date": "1999-10-20",
            }
        ]
    }

    mock_instance = AsyncMock()
    mock_instance.post = AsyncMock(return_value=fake_response)
    mock_instance.__aenter__ = AsyncMock(return_value=mock_instance)
    mock_instance.__aexit__ = AsyncMock(return_value=False)

    with patch("httpx.AsyncClient", return_value=mock_instance):
        yield
