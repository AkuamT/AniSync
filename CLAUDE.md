# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AniSync is an anime tracking management system. Users search anime via the Bangumi API (bgm.tv), add them to a personal list, and track watching progress across three statuses: `watching`, `plan`, `completed`.

## Repository Structure

```
backend/          Python FastAPI async REST API + SQLite
frontend/         Vue 3 SPA (Vite, Composition API, <script setup>)
anisync_flutter/  Flutter client (Windows/Android/Web, Provider state management)
data/             Runtime SQLite database (anisync.db)
docs/             PRD and Technical Design (Chinese)
```

## Development Commands

### Backend (Python 3.11+, FastAPI)
```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8080   # Swagger docs at /docs
pytest tests/ -v                            # Uses in-memory SQLite, no side effects
```

### Frontend (Vue 3 + Vite)
```bash
cd frontend
npm install
npm run dev       # Dev server at localhost:5173, proxies /api to backend:8080
npm run build     # Production build to dist/
```

### Flutter
```bash
cd anisync_flutter
flutter pub get
flutter run             # Connected device
flutter build windows   # Desktop build
flutter test            # Widget tests
flutter analyze         # Lint check
```

### Docker
```bash
docker-compose -f docker-compose.dev.yml up   # Dev with hot-reload
docker-compose up                              # Production
```

## Architecture

### Backend (`backend/app/`)
- **main.py** — FastAPI app entry, CORS middleware, `init_db()` on startup, health check at `/api/health`
- **database.py** — aiosqlite, single `anime` table, `get_db()` async generator as FastAPI dependency, handles schema migrations in `init_db()`
- **schemas.py** — `AnimeStatus` enum (`watching`/`plan`/`completed`), Pydantic models (`AnimeCreate`, `AnimeUpdate`, `AnimeResponse`)
- **routers/anime.py** — CRUD at `/api/anime` with status filtering, title search, pagination
- **routers/bangumi.py** — Bangumi API v0 proxy at `/api/bangumi/search` (`POST /v0/search/subjects` on `api.bgm.tv`). Supports `BANGUMI_BASE_URL` env var for custom reverse proxy (e.g. Cloudflare Worker) and `HTTPS_PROXY` for HTTP proxy. In-memory LRU cache (128 entries, 60s TTL)
- **services/** — Empty placeholder, all logic currently inline in routers

### Frontend (`frontend/src/`)
- **App.vue** — Root component managing ALL application state locally (no Vuex/Pinia): `animeList`, `loading`, `activeTab`, `toast`
- **api/index.js** — Axios instance, conditional baseURL (production: `/` via nginx, dev: `http://127.0.0.1:8080`)
- **components/AnimeCard.vue** — Card with cover, status dropdown, progress bar, +1/delete actions
- **components/SearchBar.vue** — Search input + results panel via Bangumi proxy

### Flutter (`anisync_flutter/lib/`)
- **app_config.dart** — Multi-platform base URL (Web, Windows, Android emulator, LAN)
- **core/api_client.dart** — Singleton Dio client with all API methods
- **providers/anime_provider.dart** — `ChangeNotifier` state management
- **pages/home_page.dart** — TabBarView with 3 status tabs, responsive GridView

### API Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/bangumi/search?q=` | Search anime via Bangumi API |
| GET | `/api/anime` | List anime (optional `?status=` filter) |
| POST | `/api/anime` | Add anime to list |
| PUT | `/api/anime/{id}` | Update anime (progress, status) |
| DELETE | `/api/anime/{id}` | Remove anime |

### Key Design Decisions
- Three statuses simplified from PRD's four: `dropped` consolidated into `plan`; DB migration handles old values
- No external state management in Vue — all state lives in `App.vue`
- SQLite database path defaults to `data/anisync.db` relative to project root (override via `DATABASE_URL` env var)
- Apple-style design system across all clients (accent `#0071E3`, danger `#FF3B30`, success `#34C759`, background `#F5F5F7`)
- Vite dev proxy and nginx production proxy both route `/api` to the backend on port 8080
- Tests use FastAPI's sync `TestClient` with in-memory SQLite and mocked Bangumi HTTP calls
- Bug fixes in code are annotated with comments like `BUG-3`, `BUG-5`, etc. — these document historical issues and their fixes; preserve them when editing
- `api.bgm.tv` / `lain.bgm.tv` may be inaccessible from mainland China — set `BANGUMI_BASE_URL` env var to a Deno Deploy reverse proxy (see `backend/deno-proxy.js`), or set `HTTPS_PROXY` to route requests through a proxy. Detailed setup in README.md
