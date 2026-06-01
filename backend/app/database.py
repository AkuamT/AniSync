import aiosqlite
import os

DATABASE_URL = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data", "anisync.db")

async def get_db():
    db = await aiosqlite.connect(DATABASE_URL)
    db.row_factory = aiosqlite.Row
    try:
        yield db
    finally:
        await db.close()

async def init_db():
    os.makedirs(os.path.dirname(DATABASE_URL), exist_ok=True)
    async with aiosqlite.connect(DATABASE_URL) as db:
        await db.execute("""
            CREATE TABLE IF NOT EXISTS anime (
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
        await db.execute("CREATE INDEX IF NOT EXISTS idx_anime_status ON anime(status)")
        await db.execute("CREATE INDEX IF NOT EXISTS idx_anime_bangumi_id ON anime(bangumi_id)")

        # 数据迁移：将旧状态值转换为新状态值
        # want_to_watch → plan（想看）
        # dropped → plan（弃番归入想看）
        # watching / completed 保持不变
        await db.execute("UPDATE anime SET status = 'plan' WHERE status = 'want_to_watch'")
        await db.execute("UPDATE anime SET status = 'plan' WHERE status = 'dropped'")

        await db.commit()
