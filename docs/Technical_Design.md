# AniSync 技术设计文档

## 1. 技术架构

```
┌─────────────────────────────────────────────┐
│                   前端 (Vue 3)               │
│  ┌─────────┐  ┌──────────┐  ┌────────────┐  │
│  │  番剧列表 │  │ 添加/编辑 │  │ 搜索番剧   │  │
│  └────┬────┘  └────┬─────┘  └─────┬──────┘  │
│       │            │              │          │
│       └────────────┼──────────────┘          │
│                    │ HTTP (Axios)            │
└────────────────────┼────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────┐
│                 后端 (FastAPI)                │
│  ┌──────────┐  ┌────────────┐  ┌─────────┐  │
│  │ 番剧 CRUD │  │ Jikan API  │  │ 导入导出 │  │
│  │  Router   │  │   服务      │  │  服务    │  │
│  └────┬─────┘  └─────┬──────┘  └────┬────┘  │
│       │              │              │        │
│       └──────────────┼──────────────┘        │
│                      │                       │
│       ┌──────────────┼──────────────┐        │
│       │              ▼              │        │
│       │  ┌──────────────────┐      │        │
│       │  │  Jikan API v4    │      │        │
│       │  │  (外部免费服务)    │      │        │
│       │  └──────────────────┘      │        │
│       │              │              │        │
│       │       ┌──────┴──────┐       │        │
│       │       │   SQLite    │       │        │
│       │       └─────────────┘       │        │
│       └─────────────────────────────┘        │
└─────────────────────────────────────────────┘
```

---

## 2. 目录结构

```
AniSync/
├── frontend/                    # 前端项目
│   ├── public/
│   ├── src/
│   │   ├── api/                 # API 请求封装
│   │   │   └── index.js
│   │   ├── components/          # 通用组件
│   │   │   ├── AnimeCard.vue
│   │   │   ├── AnimeForm.vue
│   │   │   ├── SearchModal.vue
│   │   │   └── StatusFilter.vue
│   │   ├── views/               # 页面视图
│   │   │   └── Home.vue
│   │   ├── App.vue
│   │   └── main.js
│   ├── index.html
│   ├── vite.config.js
│   └── package.json
│
├── backend/                     # 后端项目
│   ├── app/
│   │   ├── routers/             # API 路由
│   │   │   ├── anime.py         # 番剧 CRUD
│   │   │   └── bangumi.py       # 番剧搜索（Jikan API 代理）
│   │   ├── services/            # 业务逻辑
│   │   │   ├── anime_service.py
│   │   │   └── bangumi_service.py  # Jikan API 调用
│   │   ├── models.py            # 数据模型
│   │   ├── schemas.py           # Pydantic Schema
│   │   ├── database.py          # 数据库连接
│   │   └── main.py              # 应用入口
│   ├── requirements.txt
│   └── venv/
│
├── data/                        # 数据目录
│   └── anisync.db               # SQLite 数据库
│
├── docs/                        # 文档
│   ├── PRD.md
│   └── Technical_Design.md
│
└── README.md
```

---

## 3. 数据库设计

### 3.1 表结构

```sql
-- 番剧表
CREATE TABLE anime (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    title       TEXT NOT NULL,                    -- 番剧名称
    cover_url   TEXT,                             -- 封面图 URL
    description TEXT,                             -- 简介
    total_episodes INTEGER DEFAULT 0,             -- 总集数
    current_episode INTEGER DEFAULT 0,            -- 当前观看集数
    status      TEXT DEFAULT 'want_to_watch',     -- 观看状态
    score       INTEGER,                          -- 评分 (1-10)
    air_date    TEXT,                             -- 放送日期
    bangumi_id  INTEGER,                          -- Bangumi 番剧 ID
    created_at  TEXT DEFAULT (datetime('now')),   -- 创建时间
    updated_at  TEXT DEFAULT (datetime('now'))    -- 更新时间
);

-- 观看状态枚举：want_to_watch, watching, completed, dropped
```

### 3.2 索引

```sql
CREATE INDEX idx_anime_status ON anime(status);
CREATE INDEX idx_anime_bangumi_id ON anime(bangumi_id);
```

---

## 4. API 设计

### 4.1 番剧管理

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/api/anime` | 获取番剧列表（支持筛选） |
| GET | `/api/anime/{id}` | 获取单个番剧详情 |
| POST | `/api/anime` | 添加番剧 |
| PUT | `/api/anime/{id}` | 更新番剧 |
| DELETE | `/api/anime/{id}` | 删除番剧 |

**GET /api/anime 请求参数：**

```
?status=watching        # 按状态筛选
?search=关键词          # 按名称搜索
&page=1&page_size=20   # 分页
```

**POST /api/anime 请求体：**

```json
{
    "title": "番剧名称",
    "cover_url": "https://...",
    "total_episodes": 12,
    "current_episode": 0,
    "status": "want_to_watch",
    "score": null,
    "bangumi_id": 12345
}
```

### 4.2 番剧搜索（Jikan API 代理）

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/api/bangumi/search?keyword=关键词` | 搜索番剧（代理 Jikan API） |

**响应：**

```json
{
    "results": [
        {
            "bangumi_id": 21,
            "title": "ONE PIECE",
            "cover_url": "https://cdn.myanimelist.net/images/anime/...",
            "description": "空想的时代...",
            "total_episodes": 0,
            "air_date": "1999-10-20"
        }
    ]
}
```

---

## 5. 前端设计

### 5.1 状态管理

不使用 Vuex/Pinia，使用 Vue 3 Composition API 的 `reactive` / `ref` 管理局部状态。

### 5.2 组件结构

```
App.vue
└── Home.vue
    ├── StatusFilter.vue      # 状态筛选标签
    ├── SearchBar.vue         # 本地搜索框
    ├── AnimeList.vue         # 番剧列表容器
    │   └── AnimeCard.vue     # 单个番剧卡片
    ├── AnimeForm.vue         # 添加/编辑表单
    └── BangumiSearch.vue     # 番剧搜索弹窗（调用 Jikan API）
```

### 5.3 关键交互流程

**添加番剧流程：**

```
点击"添加番剧" → 弹出表单 → 点击"搜索番剧"
→ 输入关键词 → 调用 Jikan API → 显示搜索结果
→ 点击结果自动填充表单 → 调整信息 → 保存
```

---

## 6. 番剧数据源（Jikan API）

### 6.1 技术方案

- 使用 `httpx` 异步调用 Jikan API v4（`https://api.jikan.moe/v4`）
- 免费开源，无需 API Key
- 基于 MyAnimeList 数据，番剧信息丰富

### 6.2 使用的 API 端点

| 端点 | 用途 |
|------|------|
| `GET /anime?q={keyword}&type=tv&sfw=true` | 搜索番剧 |
| `GET /anime/{id}` | 获取番剧详情 |
| `GET /seasons/now` | 获取当季新番 |
| `GET /seasons/{year}/{season}` | 获取指定季度番剧 |

### 6.3 数据映射

```python
# Jikan API 响应 → 本地数据模型
jikan_to_local = {
    "mal_id": "bangumi_id",        # 使用 MAL ID 作为外部标识
    "title": "title",
    "images.jpg.large_image_url": "cover_url",
    "synopsis": "description",
    "episodes": "total_episodes",
    "aired.from": "air_date",
}
```

### 6.4 调用示例

```python
import httpx

async def search_anime(keyword: str):
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://api.jikan.moe/v4/anime",
            params={"q": keyword, "type": "tv", "sfw": True, "limit": 10}
        )
        data = resp.json()
        return [transform(item) for item in data["data"]]
```

---

## 7. 依赖清单

### 后端 requirements.txt

```txt
fastapi==0.115.0
uvicorn[standard]==0.30.0
pydantic==2.9.0
aiosqlite==0.20.0
httpx==0.27.0
```

### 前端 package.json 核心依赖

```json
{
    "dependencies": {
        "vue": "^3.4.0",
        "axios": "^1.7.0"
    },
    "devDependencies": {
        "@vitejs/plugin-vue": "^5.0.0",
        "vite": "^5.4.0"
    }
}
```

---

## 8. 开发环境配置

### 后端启动

```bash
cd backend
source venv/Scripts/activate   # Windows Git Bash
uvicorn app.main:app --reload --port 8000
```

### 前端启动

```bash
cd frontend
npm run dev    # 默认端口 5173
```

### CORS 配置

```python
# backend/app/main.py
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

---

## 9. 开发计划

| 阶段 | 内容 | 预计时间 |
|------|------|----------|
| Phase 1 | 项目初始化 + 数据库 + CRUD API | 1天 |
| Phase 2 | 前端页面 + 番剧列表 + 增删改查 | 1天 |
| Phase 3 | Jikan API 搜索 + 自动填充 | 1天 |
| Phase 4 | 进度追踪 + 状态管理 | 0.5天 |
| Phase 5 | 测试 + 联调 + 修复 | 0.5天 |

**MVP 总计：约 4 天**
