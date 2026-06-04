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
│  │ 番剧 CRUD │  │ Bangumi API │  │ 导入导出 │  │
│  │  Router   │  │   服务       │  │  服务    │  │
│  └────┬─────┘  └─────┬──────┘  └────┬────┘  │
│       │              │              │        │
│       └──────────────┼──────────────┘        │
│                      │                       │
│       ┌──────────────┼──────────────┐        │
│       │              ▼              │        │
│       │  ┌──────────────────┐      │        │
│       │  │  Bangumi API     │      │        │
│       │  │  (bgm.tv)        │      │        │
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
│   │   │   └── bangumi.py       # 番剧搜索（Bangumi API 代理）
│   │   ├── services/            # 业务逻辑
│   │   │   ├── anime_service.py
│   │   │   └── bangumi_service.py  # Bangumi API 调用
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
    status      TEXT DEFAULT 'plan',               -- 观看状态
    score       INTEGER,                          -- 评分 (1-10)
    air_date    TEXT,                             -- 放送日期
    bangumi_id  INTEGER,                          -- Bangumi subject ID
    created_at  TEXT DEFAULT (datetime('now')),   -- 创建时间
    updated_at  TEXT DEFAULT (datetime('now'))    -- 更新时间
);

-- 观看状态枚举：plan（想看）, watching（在看）, completed（看完）
-- 注：旧状态 want_to_watch / dropped 在迁移中自动转为 plan
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
    "status": "plan",
    "score": null,
    "bangumi_id": 12345
}
```

### 4.2 番剧搜索（Bangumi API 代理）

> **国内网络注意**：`api.bgm.tv` 可能被封锁，需配置 `BANGUMI_BASE_URL` 指向 Deno Deploy 反代。
> 详细步骤见 README.md 中的「国内网络配置详解」章节。

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/api/bangumi/search?keyword=关键词` | 搜索番剧（代理 Bangumi API v0） |

**响应：**

```json
{
    "results": [
        {
            "bangumi_id": 21,
            "title": "海贼王",
            "cover_url": "https://lain.bgm.tv/pic/cover/l/...",
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
    └── BangumiSearch.vue     # 番剧搜索弹窗（调用 Bangumi API）
```

### 5.3 关键交互流程

**添加番剧流程：**

```
点击"添加番剧" → 弹出表单 → 点击"搜索番剧"
→ 输入关键词 → 调用 Bangumi API → 显示搜索结果
→ 点击结果自动填充表单 → 调整信息 → 保存
```

---

## 6. 番剧数据源（Bangumi API）

### 6.1 技术方案

- 使用 `httpx` 异步调用 Bangumi API v0（`https://api.bgm.tv`）
- 免费开放，中文搜索体验优秀
- 基于 Bangumi 番剧数据库，中文番剧信息丰富
- 后端内置 LRU 缓存（128 条，60s TTL）避免重复请求
- 支持 `BANGUMI_BASE_URL` 环境变量配置反代地址
- 支持 `HTTPS_PROXY` 环境变量通过 HTTP 代理访问

### 6.2 使用的 API 端点

| 端点 | 用途 |
|------|------|
| `POST /v0/search/subjects` | 搜索番剧（filter.type=2 限定动画） |

### 6.3 数据映射

```python
# Bangumi API v0 响应 → 本地数据模型
bangumi_to_local = {
    "id": "bangumi_id",                    # 使用 Bangumi subject ID
    "name_cn": "title",                    # 优先使用中文名，回退到 name
    "images.large": "cover_url",           # 封面图（large > common > medium > small 优先级）
    "summary": "description",              # 简介
    "eps": "total_episodes",               # 总集数（eps 可能为 null，回退到 total_episodes）
    "air_date": "air_date",                # 放送日期（YYYY-MM-DD 格式）
}
```

### 6.4 调用示例

```python
import httpx

async def search_anime(keyword: str, limit: int = 10):
    async with httpx.AsyncClient(
        timeout=8.0,
        headers={"User-Agent": "Akuam/AniSync-App", "Content-Type": "application/json"},
    ) as client:
        resp = await client.post(
            "https://api.bgm.tv/v0/search/subjects",
            json={"keyword": keyword, "sort": "match", "filter": {"type": [2]}},
            params={"limit": limit, "offset": 0},
        )
        data = resp.json()
        return [transform(item) for item in data.get("data", [])]
```

---

## 7. 依赖清单

### 后端 requirements.txt

```txt
python-dotenv==1.0.1
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
uvicorn app.main:app --reload --port 8080
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
    allow_origins=["*"],        # 开发环境允许所有来源
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### 国内网络：Bangumi API 反代

`api.bgm.tv` / `lain.bgm.tv` 在国内可能无法直接访问。项目通过环境变量支持自定义代理：

```bash
# .env（项目根目录）
BANGUMI_BASE_URL=https://你的代理.deno.net
```

代理脚本位于 `backend/deno-proxy.js`，可一键部署到 [Deno Deploy](https://dash.deno.com)。详细搭建步骤见 README.md。

---

## 9. 开发计划

| 阶段 | 内容 | 预计时间 |
|------|------|----------|
| Phase 1 | 项目初始化 + 数据库 + CRUD API | 1天 |
| Phase 2 | 前端页面 + 番剧列表 + 增删改查 | 1天 |
| Phase 3 | Bangumi API 搜索 + 自动填充 | 1天 |
| Phase 4 | 进度追踪 + 状态管理 | 0.5天 |
| Phase 5 | 测试 + 联调 + 修复 | 0.5天 |

**MVP 总计：约 4 天**
