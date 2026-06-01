<div align="center">

# 🎬 AniSync

**一个现代化的番剧追踪管理系统**

让你的追番体验像呼吸一样自然

[![FastAPI](https://img.shields.io/badge/FastAPI-0.115.0-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Vue.js](https://img.shields.io/badge/Vue.js-3.5-4FC08D?style=flat-square&logo=vue.js&logoColor=white)](https://vuejs.org)
[![Vite](https://img.shields.io/badge/Vite-8.0-646CFF?style=flat-square&logo=vite&logoColor=white)](https://vitejs.dev)
[![SQLite](https://img.shields.io/badge/SQLite-aiosqlite-003B57?style=flat-square&logo=sqlite&logoColor=white)](https://www.sqlite.org)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](#)

</div>

---

## ✨ 核心功能

| 功能 | 描述 |
|:---|:---|
| 🔍 **智能搜索** | 接入 Jikan API (MyAnimeList)，实时搜索海量番剧数据 |
| 📋 **状态管理** | 三态流转 —— `想看 (plan)` → `在看 (watching)` → `看完 (completed)` |
| 📊 **进度追踪** | 可视化进度条，一键 "+1 集"，追番进度一目了然 |
| 🎨 **现代 UI** | Apple 风格设计语言，响应式布局，流畅动效 |
| ⚡ **前后端分离** | Vue 3 SPA + FastAPI REST API，独立开发部署 |
| 🗄️ **轻量存储** | SQLite 文件数据库，零配置，开箱即用 |

## 🛠️ 技术栈

<table>
<tr>
<td align="center"><b>前端</b></td>
<td>
<img src="https://img.shields.io/badge/-Vue%203-4FC08D?logo=vue.js&logoColor=white&style=flat-square" />
<img src="https://img.shields.io/badge/-Vite-646CFF?logo=vite&logoColor=white&style=flat-square" />
<img src="https://img.shields.io/badge/-Axios-5A29E4?logo=axios&logoColor=white&style=flat-square" />
</td>
</tr>
<tr>
<td align="center"><b>后端</b></td>
<td>
<img src="https://img.shields.io/badge/-FastAPI-009688?logo=fastapi&logoColor=white&style=flat-square" />
<img src="https://img.shields.io/badge/-Pydantic-E92063?logo=pydantic&logoColor=white&style=flat-square" />
<img src="https://img.shields.io/badge/-aiosqlite-003B57?logo=sqlite&logoColor=white&style=flat-square" />
<img src="https://img.shields.io/badge/-httpx-009688?style=flat-square" />
</td>
</tr>
<tr>
<td align="center"><b>数据源</b></td>
<td>
<img src="https://img.shields.io/badge/-Jikan%20API%20v4-2E51A7?logo=myanimelist&logoColor=white&style=flat-square" />
</td>
</tr>
</table>

---

## 🚀 快速开始

### 环境要求

- **Python** 3.11+
- **Node.js** 18+
- **npm** 9+

### 1. 克隆项目

```bash
git clone https://github.com/Yanmu/AniSync.git
cd AniSync
```

### 2. 启动后端

```bash
# 进入后端目录
cd backend

# 创建并激活 Python 虚拟环境
python -m venv venv

# Windows (PowerShell)
.\venv\Scripts\Activate.ps1

# Windows (CMD)
venv\Scripts\activate.bat

# macOS / Linux
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

# 启动 FastAPI 服务 (默认端口 8080)
uvicorn app.main:app --reload --port 8080
```

> 🟢 后端启动后，访问 `http://localhost:8080/docs` 可查看 Swagger API 文档。

### 3. 启动前端

```bash
# 新开一个终端，进入前端目录
cd frontend

# 安装依赖
npm install

# 启动开发服务器
npm run dev
```

> 🟢 前端启动后，访问 `http://localhost:5173` 即可使用。

---

## 📁 项目结构

```
AniSync/
├── backend/                    # 后端服务
│   ├── app/
│   │   ├── main.py             # FastAPI 应用入口 & 中间件配置
│   │   ├── database.py         # SQLite 数据库连接 & 初始化
│   │   ├── schemas.py          # Pydantic 数据模型 (请求/响应)
│   │   └── routers/
│   │       ├── anime.py        # 番剧 CRUD 路由 (/api/anime)
│   │       └── bangumi.py      # Jikan API 代理路由 (/api/bangumi)
│   ├── tests/                  # 自动化测试
│   │   ├── conftest.py         # Pytest fixtures & 测试数据库
│   │   └── test_api.py         # API 接口测试用例
│   └── requirements.txt        # Python 依赖清单
├── frontend/                   # 前端应用
│   ├── src/
│   │   ├── api/index.js        # Axios HTTP 客户端封装
│   │   ├── App.vue             # 根组件 (状态管理 & 布局)
│   │   ├── components/
│   │   │   ├── AnimeCard.vue   # 番剧卡片组件
│   │   │   └── SearchBar.vue   # 搜索栏组件
│   │   ├── main.js             # Vue 应用入口
│   │   └── style.css           # 全局样式 (Apple 风格)
│   ├── package.json            # Node.js 依赖清单
│   └── vite.config.js          # Vite 构建配置
├── data/                       # 运行时数据 (SQLite 数据库)
│   └── anisync.db
├── docs/                       # 项目文档
│   ├── PRD.md                  # 产品需求文档
│   └── Technical_Design.md     # 技术设计文档
└── README.md                   # 项目说明 ← 你在这里
```

---

## 📡 API 接口

### 番剧管理

| 方法 | 路径 | 描述 |
|:---|:---|:---|
| `GET` | `/api/anime` | 获取番剧列表（支持 `status` 筛选、`search` 搜索、分页） |
| `GET` | `/api/anime/{id}` | 获取单个番剧详情 |
| `POST` | `/api/anime` | 添加新番剧（默认状态 `plan`） |
| `PUT` | `/api/anime/{id}` | 更新番剧信息（支持部分更新） |
| `DELETE` | `/api/anime/{id}` | 删除番剧 |

### 番剧搜索

| 方法 | 路径 | 描述 |
|:---|:---|:---|
| `GET` | `/api/bangumi/search?keyword={kw}` | 通过 Jikan API 搜索番剧 |

### 状态枚举

```
plan       → 想看 (Plan to Watch)
watching   → 在看 (Watching)
completed  → 看完 (Completed)
```

> 📖 完整 API 文档请访问 `http://localhost:8080/docs`（Swagger UI）

---

## 🧪 运行测试

```bash
# 确保已激活虚拟环境并安装测试依赖
cd backend
pip install pytest pytest-asyncio httpx

# 运行全部测试
pytest tests/ -v

# 运行测试并显示覆盖率
pytest tests/ -v --tb=short
```

测试使用内存 SQLite 数据库 (`sqlite:///:memory:`)，**不会污染本地数据**。

---

## 🔧 开发指南

### 后端开发

- **添加新路由**: 在 `backend/app/routers/` 下创建模块，在 `main.py` 中 `include_router`
- **数据库变更**: 修改 `database.py` 中的 `init_db()` 函数
- **数据校验**: 在 `schemas.py` 中定义 Pydantic 模型

### 前端开发

- **API 调用**: 统一在 `src/api/index.js` 中封装
- **组件开发**: 放置在 `src/components/` 目录
- **样式规范**: 使用 CSS Custom Properties，参考 `style.css` 中的设计变量

---

## 📄 开源协议

本项目基于 [MIT License](LICENSE) 开源。

---

<div align="center">

**AniSync** — Built with ❤️ by [Yanmu](https://github.com/Yanmu)

</div>
