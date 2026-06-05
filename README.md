<div align="center">

# 🎬 AniSync

**一个现代化的番剧追踪管理系统**

让你的追番体验像呼吸一样自然

[![FastAPI](https://img.shields.io/badge/FastAPI-0.115.0-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/SQLite-aiosqlite-003B57?style=flat-square&logo=sqlite&logoColor=white)](https://www.sqlite.org)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](#)

</div>

---

## ✨ 核心功能

| 功能 | 描述 |
|:---|:---|
| 🔍 **智能搜索** | 接入 Bangumi API (bgm.tv)，实时搜索海量番剧数据 |
| 📋 **状态管理** | 三态流转 —— `想看 (plan)` → `在看 (watching)` → `看完 (completed)` |
| 📊 **进度追踪** | 可视化进度条，一键 "+1 集"，追番进度一目了然 |
| 📱 **跨平台** | Flutter 客户端，支持 Windows / Android / Web |
| 🎨 **现代 UI** | Apple 风格设计语言，响应式布局，流畅动效 |
| 💾 **导入导出** | 支持导出/导入追番数据，多端同步无忧 |
| 🗄️ **轻量存储** | SQLite 文件数据库，零配置，开箱即用 |

## 🛠️ 技术栈

<table>
<tr>
<td align="center"><b>客户端</b></td>
<td>
<img src="https://img.shields.io/badge/-Flutter-02569B?logo=flutter&logoColor=white&style=flat-square" />
<img src="https://img.shields.io/badge/-Dart-0175C2?logo=dart&logoColor=white&style=flat-square" />
<img src="https://img.shields.io/badge/-Dio-0175C2?style=flat-square" />
<img src="https://img.shields.io/badge/-Provider-0175C2?style=flat-square" />
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
<img src="https://img.shields.io/badge/-Bangumi%20API-ED6B8A?style=flat-square" />
</td>
</tr>
</table>

---

## 🚀 快速开始

### 环境要求

- **Python** 3.11+
- **Flutter** 3.x+
- **Dart** 3.x+

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

### 3. 启动 Flutter 客户端

```bash
# 进入 Flutter 目录
cd anisync_flutter

# 安装依赖
flutter pub get

# 运行 (连接设备或模拟器)
flutter run

# 构建 Windows 桌面版
flutter build windows
```

> 🟢 Flutter 客户端支持 Windows / Android / Web。详情见 `anisync_flutter/README.md`。

### 4. 国内网络配置（重要）

Bangumi API (`api.bgm.tv`) 及其图片 CDN (`lain.bgm.tv`) 在国内可能无法直接访问。项目已通过环境变量支持自定义代理地址。

**方式一：Deno Deploy 反代（推荐，免费）**

> 详细图文步骤见下方 [🔧 国内网络配置详解](#-国内网络配置详解) 章节。

1. 注册 [Deno](https://deno.com)，在 Dashboard 创建一个 **Playground**
2. 将 `backend/deno-proxy.js` 中的代码粘贴进去，点击 **Save & Deploy**
3. 复制得到的域名（如 `xxx.deno.net`）
4. 编辑项目根目录的 `.env` 文件：
```bash
BANGUMI_BASE_URL=https://xxx.deno.net
```
5. 重启后端即可

**方式二：HTTP 代理**

如果你的电脑已配置代理（VPN/Clash 等）：
```bash
# 启动后端时设置
HTTPS_PROXY=http://127.0.0.1:7890 uvicorn app.main:app --reload --port 8080
```

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
│   │       └── bangumi.py      # Bangumi API 代理路由 (/api/bangumi)
│   ├── tests/                  # 自动化测试
│   │   ├── conftest.py         # Pytest fixtures & 测试数据库
│   │   └── test_api.py         # API 接口测试用例
│   └── requirements.txt        # Python 依赖清单
├── anisync_flutter/            # Flutter 客户端
│   ├── lib/
│   │   ├── app_config.dart     # 多平台配置
│   │   ├── core/
│   │   │   ├── api_client.dart # Dio HTTP 客户端封装
│   │   │   └── api_endpoints.dart
│   │   ├── providers/          # 状态管理
│   │   ├── pages/              # 页面
│   │   ├── widgets/            # 组件
│   │   └── models/             # 数据模型
│   └── pubspec.yaml            # Dart 依赖清单
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

### 番剧搜索 & 数据同步

| 方法 | 路径 | 描述 |
|:---|:---|:---|
| `GET` | `/api/bangumi/search?keyword={kw}` | 通过 Bangumi API 搜索番剧 |
| `GET` | `/api/anime/export/all` | 导出全部番剧数据 (JSON) |
| `POST` | `/api/anime/import` | 导入番剧数据 |

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

### Flutter 客户端开发

- **API 调用**: 统一在 `lib/core/api_client.dart` 中封装
- **状态管理**: 使用 Provider + ChangeNotifier
- **样式规范**: 参考 `app_theme.dart` 中的设计变量

---

---

## 🔧 国内网络配置详解

### 为什么需要配置

Bangumi 的 API 服务器 (`api.bgm.tv`) 和图片 CDN (`lain.bgm.tv`) 位于境外，在国内网络环境下 TCP 连接会被阻断，导致搜索无结果、封面图片不显示。

### Deno Deploy 反代搭建（5 分钟）

> Deno Deploy 提供免费额度，国内可正常访问 `*.deno.net` 域名。

**1. 注册 & 登录**

打开 https://dash.deno.com → **Sign in with GitHub**（如无 GitHub 账号需先注册）

**2. 创建 Playground**

登录后点击右上角 **New Playground**，会打开在线代码编辑器。

**3. 粘贴代理代码**

清空编辑器中的示例代码，将 `backend/deno-proxy.js` 的**全部内容**粘贴进去：

```typescript
const BANGUMI_API = "https://api.bgm.tv";
const IMG_CDN = "https://lain.bgm.tv";

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const path = url.pathname;

  // 图片代理：/img/... → lain.bgm.tv/...
  if (path.startsWith("/img/")) {
    const imgUrl = IMG_CDN + path.replace("/img", "");
    try {
      const imgResp = await fetch(imgUrl);
      const headers = new Headers();
      const ct = imgResp.headers.get("Content-Type");
      if (ct) headers.set("Content-Type", ct);
      headers.set("Access-Control-Allow-Origin", "*");
      headers.set("Cache-Control", "public, max-age=86400");
      return new Response(imgResp.body, { status: imgResp.status, headers });
    } catch (e) {
      return new Response(null, { status: 502 });
    }
  }

  // API 代理：/v0/... → api.bgm.tv/v0/...
  const targetUrl = BANGUMI_API + path + url.search;

  try {
    const resp = await fetch(targetUrl, {
      method: req.method,
      headers: {
        "User-Agent": "Akuam/AniSync-App (https://github.com/akuam/AniSync)",
        "Content-Type": "application/json",
      },
      body: req.method === "POST" ? await req.text() : undefined,
    });

    let body = await resp.text();

    // 将响应中的 lain.bgm.tv 图片链接替换为代理链接
    body = body.replaceAll("https://lain.bgm.tv", url.origin + "/img");

    return new Response(body, {
      status: resp.status,
      headers: {
        "Content-Type": resp.headers.get("Content-Type") || "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "代理请求失败", detail: String(e) }),
      { status: 502, headers: { "Content-Type": "application/json" } }
    );
  }
});
```

**4. 部署 & 获取域名**

点击右上角 **Save & Deploy**，部署成功后页面会显示你的代理域名，格式如：
```
https://near-lorikeet-74.akuamt.deno.net
```

**5. 配置项目**

编辑项目根目录的 `.env` 文件，填入你的代理域名：
```bash
BANGUMI_BASE_URL=https://你的域名.deno.net
```

**6. 重启后端**，搜索功能和封面图片即可正常使用。

### 环境变量参考

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `BANGUMI_BASE_URL` | Bangumi API 反代地址 | `https://api.bgm.tv` |
| `HTTPS_PROXY` | HTTP 代理地址 | 无 |
| `DATABASE_URL` | SQLite 数据库路径 | `data/anisync.db` |

---

## 📄 开源协议

本项目基于 [MIT License](LICENSE) 开源。

---

<div align="center">

**AniSync** — Built with ❤️ by [Yanmu](https://github.com/Yanmu)

</div>
