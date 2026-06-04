import os
from pathlib import Path

# 加载项目根目录的 .env 文件
from dotenv import load_dotenv
load_dotenv(Path(__file__).resolve().parent.parent.parent / ".env")

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import init_db
from .routers import anime, bangumi

app = FastAPI(title="AniSync", version="0.1.0")

# BUG-13 修复：开发环境允许所有来源（无认证场景，生产环境请收紧）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(anime.router)
app.include_router(bangumi.router)


@app.on_event("startup")
async def startup():
    await init_db()


@app.get("/api/health")
async def health():
    return {"status": "ok"}
